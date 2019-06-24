cd Desktop;
npm version $1;
sudo npm run release;
cd ..;
cd Android;
npm version $1;
sudo npm run package;
echo 'Uploading apk...';
sudo github-release upload \
  --token $GH_TOKEN \
  --owner 'dan-online' \
  --repo 'GitApp' \
  --tag 'v'$1 \
  --file 'dist/app-aligned-debugSigned.apk' \
  --name 'GitApp-android-'$1'.apk'