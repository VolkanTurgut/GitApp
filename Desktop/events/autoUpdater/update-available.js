module.exports.on = 'autoUpdater';

module.exports.func = function() {
    require("../../main").sendStatusToWindow('Updating...');
}