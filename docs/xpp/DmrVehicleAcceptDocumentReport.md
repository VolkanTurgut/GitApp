# X++ SSRS report classes for `DmrVehicleAcceptDocument` (Tmp table)

Because `DmrVehicleAcceptDocument` is a **Tmp table**, you should not query it back from SQL by `RecId` in the DP.
Instead, pass the selected tmp rows from the form to the report contract, then rebuild the report dataset in the DP.

Below is a working pattern for that scenario.

---

## 1) Data contract (pass selected tmp rows)

```x++
[DataContractAttribute]
class DmrVehicleAcceptDocumentContract
{
    container packedRows;
}

[DataMemberAttribute('PackedRows')]
public container parmPackedRows(container _packedRows = packedRows)
{
    packedRows = _packedRows;
    return packedRows;
}
```

---

## 2) Data provider class

> Assumption: `DmrVehicleAcceptDocumentReportTmp` is the dataset tmp table used by the SSRS report.

```x++
[SRSReportParameterAttribute(classStr(DmrVehicleAcceptDocumentContract))]
class DmrVehicleAcceptDocumentDP extends SRSReportDataProviderBase
{
    DmrVehicleAcceptDocumentReportTmp reportTmp;
}

[SRSReportDataSetAttribute(tableStr(DmrVehicleAcceptDocumentReportTmp))]
public DmrVehicleAcceptDocumentReportTmp getReportTmp()
{
    select reportTmp;
    return reportTmp;
}

public void processReport()
{
    DmrVehicleAcceptDocumentContract contract = this.parmDataContract() as DmrVehicleAcceptDocumentContract;
    container                        rows;
    int                              i;
    container                        row;

    // Local variables for unpacked row data
    str                documentId;
    str                vehicleId;
    Name               driverName;
    utcdatetime        acceptDateTime;

    if (!contract)
    {
        return;
    }

    rows = contract.parmPackedRows();

    for (i = 1; i <= conLen(rows); i++)
    {
        row = conPeek(rows, i);

        // Unpack in same order as packed in form button
        [documentId, vehicleId, driverName, acceptDateTime] = row;

        reportTmp.clear();
        reportTmp.initValue();

        reportTmp.DocumentId     = documentId;
        reportTmp.VehicleId      = vehicleId;
        reportTmp.DriverName     = driverName;
        reportTmp.AcceptDateTime = acceptDateTime;

        reportTmp.insert();
    }
}
```

---

## 3) Controller class

```x++
class DmrVehicleAcceptDocumentController extends SrsReportRunController
{
    public static DmrVehicleAcceptDocumentController construct()
    {
        return new DmrVehicleAcceptDocumentController();
    }

    public static void main(Args _args)
    {
        DmrVehicleAcceptDocumentController controller = DmrVehicleAcceptDocumentController::construct();
        controller.parmReportName(ssrsReportStr(DmrVehicleAcceptDocumentReport, Report));
        controller.parmArgs(_args);
        controller.startOperation();
    }
}
```

---

## 4) Print button code: print each selected tmp row as one page

Put this in your form button `clicked()`.

```x++
public void clicked()
{
    FormDataSource                    ds;
    MultiSelectionHelper              helper;
    DmrVehicleAcceptDocument          docTmp;
    DmrVehicleAcceptDocumentController controller;
    DmrVehicleAcceptDocumentContract  contract;
    container                         packedRows;
    container                         oneRow;

    super();

    ds     = DmrVehicleAcceptDocument_ds;
    helper = MultiSelectionHelper::construct();
    helper.parmDatasource(ds);

    docTmp = helper.getFirst();

    while (docTmp.RecId)
    {
        // Pack only fields needed by report dataset
        oneRow = [
            docTmp.DocumentId,
            docTmp.VehicleId,
            docTmp.DriverName,
            docTmp.AcceptDateTime
        ];

        packedRows += [oneRow];
        docTmp = helper.getNext();
    }

    if (!conLen(packedRows))
    {
        warning("Select at least one record.");
        return;
    }

    controller = DmrVehicleAcceptDocumentController::construct();
    controller.parmReportName(ssrsReportStr(DmrVehicleAcceptDocumentReport, Report));
    controller.parmShowDialog(false);

    contract = controller.parmReportContract().parmRdpContract() as DmrVehicleAcceptDocumentContract;
    contract.parmPackedRows(packedRows);

    controller.startOperation();
}
```

---

## 5) SSRS design setting for one page per row

In the report design, create a parent group (for example by `DocumentId`) and set:
- **Page Break** = `Between each instance of a group`

Because the DP inserts one dataset row per selected tmp row, this prints one report page per selected record.

---

## Notes

- If your tmp table uses different field names/types, update pack/unpack order in both places.
- Keep pack/unpack order exactly identical.
- If you prefer physical printer output, configure `parmPrintSettings()` before `startOperation()`.

---

## 6) How to send tmp-table rows to contract as `container`

In X++, a `container` can only hold scalar values (and nested containers), not table-buffer objects.  
So you send a **packed representation** of each tmp row.

Use explicit helper methods so pack/unpack order never drifts.

```x++
private static container packTmpRow(DmrVehicleAcceptDocument _tmp)
{
    return [
        _tmp.DocumentId,
        _tmp.VehicleId,
        _tmp.DriverName,
        _tmp.AcceptDateTime
    ];
}

private static void unpackTmpRow(
    container   _row,
    str         _documentId,
    str         _vehicleId,
    Name        _driverName,
    utcdatetime _acceptDateTime)
{
    [_documentId, _vehicleId, _driverName, _acceptDateTime] = _row;
}
```

Then in button code, build one "rows container" and send it to contract:

```x++
container rows;
container row;

docTmp = helper.getFirst();
while (docTmp.RecId)
{
    row  = this.packTmpRow(docTmp);
    rows += [row];
    docTmp = helper.getNext();
}

contract.parmPackedRows(rows);
```

And in DP:

```x++
container rows = contract.parmPackedRows();
container row;
int i;

for (i = 1; i <= conLen(rows); i++)
{
    row = conPeek(rows, i);
    [documentId, vehicleId, driverName, acceptDateTime] = row;

    reportTmp.clear();
    reportTmp.initValue();
    reportTmp.DocumentId     = documentId;
    reportTmp.VehicleId      = vehicleId;
    reportTmp.DriverName     = driverName;
    reportTmp.AcceptDateTime = acceptDateTime;
    reportTmp.insert();
}
```

If rows can be very large, prefer a temp staging table keyed by execution ID instead of a giant container.
