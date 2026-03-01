@echo off
setlocal enabledelayedexpansion

:: [0/3] Read version from file
if not exist version.txt (
    echo Error: version.txt not found!
    pause
    exit /b
)
set /p FULL_VERSION=<version.txt

:: Optional: Split 1.2.3.4 into Name (1.2.3) and Number (4)
:: This assumes your version.txt is always in the format X.X.X.X
for /f "tokens=1,2,3,4 delims=." %%a in ("%FULL_VERSION%") do (
    set BUILD_NAME=%%a.%%b.%%c
    set BUILD_NUMBER=%%d
)

echo Building Version: %FULL_VERSION% (Name: %BUILD_NAME%, Number: %BUILD_NUMBER%)

echo [1/3] Cleaning and Fetching...
call flutter clean
:: call flutter pub get

echo [2/3] Building Windows & MSIX...
:: Use the split variables for the executable
call flutter build windows --release --build-name=%BUILD_NAME% --build-number=%BUILD_NUMBER%

:: Use the full 4-digit version for the MSIX installer
call dart run msix:create --version %FULL_VERSION% --build-windows false --install-certificate false

echo [3/3] Pooling Installer...
if not exist build mkdir build
copy /Y "build\windows\x64\runner\Release\*.msix" "build\"

echo ---------------------------------------
echo Done! Version %FULL_VERSION% is in: build\
echo ---------------------------------------
:: pause