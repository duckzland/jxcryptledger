@echo off
setlocal enabledelayedexpansion

if not exist version.txt (
    echo Error: version.txt not found!
    pause
    exit /b
)
set /p FULL_VERSION=<version.txt

for /f "tokens=1,2,3,4 delims=." %%a in ("%FULL_VERSION%") do (
    set BUILD_NAME=%%a.%%b.%%c
    set BUILD_NUMBER=%%d
)

echo [0/3] Checking pubspec.yaml version...
for /f "tokens=2 delims=: " %%v in ('findstr /b "version:" pubspec.yaml') do (
    set CURRENT_VERSION=%%v
)

if "%CURRENT_VERSION%"=="%BUILD_NAME%" (
    echo pubspec.yaml already up to date: %BUILD_NAME%
) else (
    echo Updating pubspec.yaml from %CURRENT_VERSION% to %BUILD_NAME%...
    powershell -Command ^
      "(Get-Content pubspec.yaml) -replace '^version:.*', 'version: %BUILD_NAME%' | Set-Content pubspec.yaml"

    echo Committing version bump to Git...
    git commit pubspec.yaml -m "Bump version to %BUILD_NAME%"
)

echo Building Version: %FULL_VERSION% (Name: %BUILD_NAME%, Number: %BUILD_NUMBER%)

echo [1/3] Cleaning and Fetching...
call flutter clean

echo [2/3] Building Windows & MSIX...
call flutter build windows --release --build-name=%BUILD_NAME% --build-number=%BUILD_NUMBER%

call dart run msix:create --version %FULL_VERSION% --install-certificate false

echo [3/3] Pooling Installer...

set OUTPUT_DIR=build
set SOURCE_MSIX=build\windows\x64\runner\Release
set TARGET_MSIX=%OUTPUT_DIR%\JXLedger_%FULL_VERSION%.msix

if not exist %OUTPUT_DIR% mkdir %OUTPUT_DIR%

for %%f in ("%SOURCE_MSIX%\*.msix") do (
    echo Renaming %%~nxf to %TARGET_MSIX%
    copy /Y "%%f" "%TARGET_MSIX%"
)

echo ---------------------------------------
echo Done! Version %FULL_VERSION% is in: build\
echo ---------------------------------------