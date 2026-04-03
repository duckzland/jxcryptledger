#!/bin/bash

set -e

if [ -f version.txt ]; then
    FULL_VERSION=$(cat version.txt | xargs)
    IFS='.' read -r a b c d <<< "$FULL_VERSION"
    BUILD_NAME="$a.$b.$c"
    BUILD_NUMBER="$d"
else
    echo "Error: version.txt not found!"
    exit 1
fi

DO_COMMIT=true

for arg in "$@"; do
    case "$arg" in
        --no-commit)
            DO_COMMIT=false
            ;;
    esac
done

echo "[1/7] Checking pubspec.yaml version..."

CURRENT_VERSION=$(grep "^version:" pubspec.yaml | awk '{print $2}')

if [ "$CURRENT_VERSION" = "$BUILD_NAME" ]; then
    echo "pubspec.yaml already up to date: $BUILD_NAME"
else
    echo "Updating pubspec.yaml from $CURRENT_VERSION to $BUILD_NAME..."
    sed -i "s/^version:.*/version: $BUILD_NAME/" pubspec.yaml

    echo "Committing version bump to Git..."
    if $DO_COMMIT; then
        git add pubspec.yaml
        git commit pubspec.yaml -m "Bump version to $BUILD_NAME"
    fi
fi

echo "[2/7] Checking lib/app/constants.dart version..."

CURRENT_VERSION=$(sed -n 's/.*appVersion = "\(.*\)";/\1/p' lib/app/constants.dart)

if [ "$CURRENT_VERSION" == "$FULL_VERSION" ]; then
    echo "lib/app/constants.dart version already up to date: $FULL_VERSION"
else
    echo "Updating lib/app/constants.dart from $CURRENT_VERSION to $FULL_VERSION..."
    
    sed -i "s/const String appVersion = \".*\";/const String appVersion = \"$FULL_VERSION\";/" lib/app/constants.dart

    echo "Committing version bump to Git..."
    if $DO_COMMIT; then
        git add lib/app/constants.dart
        git commit lib/app/constants.dart -m "Bump version to $FULL_VERSION"
    fi
fi


echo "[3/7] Updating app salt at lib/app/constants.dart..."
ENV_SALT=$(sed -n 's/^APP_SALT="\([^"]*\)"/\1/p' .env)

if [ -z "$ENV_SALT" ]; then
    echo "ERROR: APP_SALT not found in .env"
    exit 1
fi

if [ "$CURRENT_SALT" == "$ENV_SALT" ]; then
    echo "Salt already up to date: $ENV_SALT"
else
    echo "Updating appSalt..."
    sed -i "s/const String appSalt = \".*\";/const String appSalt = \"$ENV_SALT\";/" lib/app/constants.dart
fi

echo "[4/7] Cleaning and Fetching..."
flutter clean

echo "[5/7] Building Version: $FULL_VERSION (Name: $BUILD_NAME, Number: $BUILD_NUMBER)"
flutter build linux --release --build-name=$BUILD_NAME --build-number=$BUILD_NUMBER

echo "[6/7] Bundling to deb package..."

APP_NAME="jxledger"
DEB_DIR="build/debian_tmp"
BUNDLE_DIR="build/linux/x64/release/bundle"

rm -rf $DEB_DIR
mkdir -p $DEB_DIR/usr/bin
mkdir -p $DEB_DIR/usr/lib/$APP_NAME
mkdir -p $DEB_DIR/usr/share/applications
mkdir -p $DEB_DIR/usr/share/icons/hicolor/512x512/apps
mkdir -p $DEB_DIR/DEBIAN

cp -r $BUNDLE_DIR/* $DEB_DIR/usr/lib/$APP_NAME/

cp assets/icon.png $DEB_DIR/usr/share/icons/hicolor/512x512/apps/$APP_NAME.png

cat <<EOF > $DEB_DIR/DEBIAN/postinst
#!/bin/sh
set -e

ln -sf /usr/lib/$APP_NAME/$APP_NAME /usr/bin/$APP_NAME

exit 0
EOF

cat <<EOF > $DEB_DIR/DEBIAN/prerm
#!/bin/sh
set -e

rm -f /usr/bin/$APP_NAME

exit 0
EOF

cat <<EOF > $DEB_DIR/usr/share/applications/$APP_NAME.desktop
[Desktop Entry]
Version: $FULL_VERSION
Name=JXLedger
GenericName=JXLedger
Comment=JXLedger Transaction Manager
Exec=/usr/bin/$APP_NAME
Icon=$APP_NAME
Type=Application
Categories=Utility;
Terminal=false
EOF

cat <<EOF > $DEB_DIR/DEBIAN/control
Package: $APP_NAME
Version: $FULL_VERSION
Architecture: amd64
Maintainer: Jason Xie <jason.xie@victheme.com>
Depends: libgtk-3-0, libglib2.0-0, libjpeg-turbo8
Description: JXLedger Transaction Manager
EOF

chmod -R 755 $DEB_DIR/DEBIAN
chmod +x $DEB_DIR/usr/lib/$APP_NAME/$APP_NAME

dpkg-deb --build $DEB_DIR build/${APP_NAME}_${FULL_VERSION}_amd64.deb

echo "[7/7] Post building cleaning..."
git checkout -- lib/app/constants.dart

echo "---------------------------------------"
echo "Done! Version $FULL_VERSION is in: build/"
echo "---------------------------------------"
