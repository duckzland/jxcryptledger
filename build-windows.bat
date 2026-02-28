@echo off

echo [1/3] Cleaning and Fetching...
call flutter clean
call flutter pub get

echo [2/3] Building Windows & MSIX...
:: We build the executable first
call flutter build windows --release
:: Then we wrap it into the single .msix installer
call dart run msix:create --build-windows false --install-certificate false

echo [3/3] Pooling Installer...
:: Create the build folder if it doesn't exist (shared with Linux)
if not exist build mkdir build

:: Copy the single installer file to the root build/ folder
copy /Y "build\windows\x64\runner\Release\*.msix" "build\"

echo ---------------------------------------
echo Done! Windows Installer is in: build\
echo ---------------------------------------
pause
