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

echo [1/6] Checking pubspec.yaml version...
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
    git add pubspec.yaml
    git commit pubspec.yaml -m "Bump version to %BUILD_NAME%"
)

echo [2/6] Checking app version...
for /f "tokens=5 delims= " %%v in ('findstr /b "const String appVersion" ".\lib\app\version.dart"') do (
    set RAW_VERSION=%%v
    set CURRENT_VERSION=!RAW_VERSION:"=!
    set CURRENT_VERSION=!CURRENT_VERSION:;=!
)

if "%CURRENT_VERSION%"=="%FULL_VERSION%" (
    echo lib/app/version.dart already up to date: %FULL_VERSION%
) else (
    echo Updating lib/app/version.dart from %CURRENT_VERSION% to %FULL_VERSION%...
    
    powershell -Command ^
      "(Get-Content lib/app/version.dart) -replace 'const String appVersion = \".*\";', 'const String appVersion = \"%FULL_VERSION%\";' | Set-Content lib/app/version.dart"

    echo Committing version bump to Git...
    git add lib/app/version.dart
    git commit lib/app/version.dart -m "Bump version to %FULL_VERSION%"
)

echo [3/6] Cleaning and Fetching...
call flutter clean

echo [4/6] Building Version: %FULL_VERSION% (Name: %BUILD_NAME%, Number: %BUILD_NUMBER%)
call flutter build windows --release --build-name=%BUILD_NAME% --build-number=%BUILD_NUMBER%

echo [5/6] Bundling to msix...
call dart run msix:create --version %FULL_VERSION% --install-certificate false

echo [6/6] Post processing...

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