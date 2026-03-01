#!/bin/bash

# 1. Build the Flutter binary
flutter build linux --release

# 2. Setup Variables
APP_NAME="jxcryptledger"

# Read version from version.txt and remove any trailing whitespace/newlines
if [ -f version.txt ]; then
    VERSION=$(cat version.txt | xargs)
else
    echo "Error: version.txt not found!"
    exit 1
fi

DEB_DIR="build/debian_tmp"
BUNDLE_DIR="build/linux/x64/release/bundle"

# 3. Create the Debian structure
rm -rf $DEB_DIR
mkdir -p $DEB_DIR/usr/bin/$APP_NAME-data
mkdir -p $DEB_DIR/usr/share/applications
mkdir -p $DEB_DIR/usr/share/icons/hicolor/512x512/apps
mkdir -p $DEB_DIR/DEBIAN

# 4. Copy Flutter bundle to /usr/bin/
cp -r $BUNDLE_DIR/* $DEB_DIR/usr/bin/

# 5. Copy Icon to System Icons
cp assets/icon.png $DEB_DIR/usr/share/icons/hicolor/512x512/apps/$APP_NAME.png

# 6. Create Desktop Entry (Start Menu)
cat <<EOF > $DEB_DIR/usr/share/applications/$APP_NAME.desktop
[Desktop Entry]
Version: $VERSION
Name=JxCryptLedger
GenericName=JxCryptLedger
Comment=JxCryptLedger Transaction Manager
Exec=/usr/bin/jxcryptledger
Icon=$APP_NAME
Type=Application
Categories=Utility;
Terminal=false
EOF

# 7. Create the Control File (Hardcoded to fix the 'diversion' bug)
cat <<EOF > $DEB_DIR/DEBIAN/control
Package: $APP_NAME
Version: $VERSION
Architecture: amd64
Maintainer: Jason Xie <jason.xie@victheme.com>
Depends: libgtk-3-0, libglib2.0-0, libjpeg-turbo8
Description: JxCryptLedger Transaction Manager
EOF

# 8. Set Permissions
chmod -R 755 $DEB_DIR/DEBIAN
chmod +x $DEB_DIR/usr/bin/$APP_NAME

# 9. Build the .deb
dpkg-deb --build $DEB_DIR build/${APP_NAME}_${VERSION}_amd64.deb

echo "Success! Created: build/${APP_NAME}_${VERSION}_amd64.deb"
