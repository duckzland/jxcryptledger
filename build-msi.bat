@echo off
setlocal enabledelayedexpansion

:: Parse input arguments
set SKIP_FLUTTER=0
set SKIP_ICON=1

:parseArgs
if "%~1"=="" goto done

if "%~1"=="--skip-build" (
    set SKIP_FLUTTER=1
    echo [INFO] Skip-build flag detected. Using existing Release files.
)

if "%~1"=="--with-icon" (
    set SKIP_ICON=0
    echo [INFO] With-icon flag detected. Icons will be included.
)

shift
goto parseArgs

:done
:: Guard: handle Ctrl-C
if not defined BREAK_HANDLER (
    set BREAK_HANDLER=1
    break >nul
    if errorlevel 1 (
        echo Ctrl-C pressed, resetting Git state...
        git reset --hard HEAD
        exit /b 1
    )
)

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

if %SKIP_FLUTTER%==1 goto SKIP_VERSION_BUMP

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
for /f "tokens=*" %%A in ('powershell -NoProfile -Command "(Select-String -Path 'lib/app/constants.dart' -Pattern 'appVersion').Line.Split([char]34)"') do set "CURRENT_VERSION=%%A"

if "%CURRENT_VERSION%"=="%FULL_VERSION%" (
    echo lib/app/constants.dart already up to date: %FULL_VERSION%
) else (
    echo Updating lib/app/constants.dart from %CURRENT_VERSION% to %FULL_VERSION%...
    powershell -Command "(Get-Content 'lib/app/constants.dart') -replace 'const String appVersion = \".*\";', 'const String appVersion = \"%FULL_VERSION%\";' | Set-Content 'lib/app/constants.dart'"

    echo Committing version bump to Git...
    git add lib/app/constants.dart
    git commit lib/app/constants.dart -m "Bump version to %FULL_VERSION%"
)

echo [3/6] Updating app salt at lib/app/constants.dart...
for /f "tokens=*" %%A in ('powershell -NoProfile -Command "(Select-String -Path '.env' -Pattern 'APP_SALT').Line.Split([char]34)"') do set "ENV_SALT=%%A"

if "%ENV_SALT%"=="" (
    echo ERROR: APP_SALT not found in .env
    exit /b 1
)

for /f "tokens=*" %%A in ('powershell -NoProfile -Command "(Select-String -Path 'lib/app/constants.dart' -Pattern 'appSalt').Line.Split([char]34)"') do set "CURRENT_SALT=%%A"

if "%CURRENT_SALT%"=="%ENV_SALT%" (
    echo Salt already up to date: %ENV_SALT%
) else (
    echo Updating appSalt...
    powershell -Command "(Get-Content 'lib/app/constants.dart') -replace 'const String appSalt = \".*\";', 'const String appSalt = \"%ENV_SALT%\";' | Set-Content 'lib/app/constants.dart'"
)
if %SKIP_ICON%==1 goto SKIP_ICON
echo [4/6] Generating Icons
call dart run .\tools\create_icons.dart

:SKIP_ICON
if %SKIP_ICON%==1 (
    echo [4/6] Skipping Icon generation steps.
)

echo [5/6] Cleaning and Compiling Flutter Windows Binaries...
call flutter build windows --release --build-name=%BUILD_NAME% --build-number=%BUILD_NUMBER%

:SKIP_VERSION_BUMP
if %SKIP_FLUTTER%==1 (
    echo [5/6] Skipping Flutter compilation steps as requested.
)

echo [6/6] Resolving WiX Toolset via local .NET SDK pathways...
set "PATH=%PATH%;C:\Program Files\dotnet;%USERPROFILE%\.dotnet\tools"

where wix >nul 2>&1
if %errorlevel% neq 0 (
    echo WiX toolchain missing from path. Triggering native .NET tool registration...
    call dotnet tool install --global wix
)

set OUTPUT_DIR=build
set TEMP_WXS=%OUTPUT_DIR%\Generated_Product.wxs
set TARGET_MSI=%OUTPUT_DIR%\JXLedger_%BUILD_NAME%.msi
set SOURCE_DIR=%CD%\build\windows\x64\runner\Release
set UPGRADE_GUID=6f3b7c84-1142-4b2a-bf39-8134762da299
set SHORTCUT_GUID=3e0298de-9989-49c6-9285-8134762da299
set MANUFACTURER=com.duckzland.jxledger

:: Verify target directory exists before running WiX compiler
if not exist "%SOURCE_DIR%\jxledger.exe" (
    echo [ERROR] Target binary missing at: %SOURCE_DIR%\jxledger.exe
    exit /b 1
)

:: --- COPY ICON AND VERIFY SUCCESS ---
copy /b /y "windows\runner\resources\app_icon.ico" "%SOURCE_DIR%\data\flutter_assets\assets\app_icon.ico" >nul
if errorlevel 1 (
    echo [ERROR] Failed to copy app_icon.ico. Check if the source path or %%SOURCE_DIR%% exists.
    pause
    exit /b 1
)

:: --- WRITE WXS MANIFEST ON THE FLY ---
(
echo ^<?xml version="1.0" encoding="UTF-8"?^>
echo ^<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs"^>
echo   ^<Package Name="JXLedger" Manufacturer="%MANUFACTURER%" Version="%BUILD_NAME%" UpgradeCode="%UPGRADE_GUID%" Scope="perMachine"^>
echo     ^<Property Id="MSIRESTARTMANAGERCONTROL" Value="Disable" /^>
echo     ^<Property Id="DISABLEADVTSHORTCUTS" Value="1" /^>
echo     ^<Icon Id="AppIcon.ico" SourceFile="%SOURCE_DIR%\data\flutter_assets\assets\app_icon.ico" /^>
echo     ^<Property Id="ARPPRODUCTICON" Value="AppIcon.ico" /^>
echo     ^<MajorUpgrade DowngradeErrorMessage="A newer version of JXLedger is already installed." Schedule="afterInstallInitialize" AllowSameVersionUpgrades="yes" /^>
echo     ^<MediaTemplate EmbedCab="yes" /^>
echo     ^<StandardDirectory Id="ProgramFiles64Folder"^>
echo       ^<Directory Id="INSTALLFOLDER" Name="JXLedger" /^>
echo     ^</StandardDirectory^>
echo     ^<StandardDirectory Id="ProgramMenuFolder"^>
echo       ^<Directory Id="ApplicationProgramsFolder" Name="JXLedger" /^>
echo     ^</StandardDirectory^>
echo     ^<ComponentGroup Id="AppFiles" Directory="INSTALLFOLDER"^>
echo       ^<Files Include="%SOURCE_DIR%\*" /^>
echo     ^</ComponentGroup^>
echo     ^<ComponentGroup Id="DataFiles" Directory="INSTALLFOLDER"^>
echo       ^<Files Subdirectory="data" Include="%SOURCE_DIR%\data\**" /^>
echo     ^</ComponentGroup^>
echo     ^<ComponentGroup Id="ShortcutCleanup" Directory="ApplicationProgramsFolder"^>
echo       ^<Component Id="ApplicationShortcutFolderCleanup" Guid="%SHORTCUT_GUID%"^>
echo         ^<RemoveFolder Id="CleanShortcutFolder" On="uninstall" /^>
echo         ^<RegistryValue Root="HKCU" Key="Software\JXLedger" Name="installed" Type="integer" Value="1" KeyPath="yes" /^>
echo         ^<Shortcut Id="ApplicationStartMenuShortcut" Directory="ApplicationProgramsFolder" Name="JXLedger" Description="A lightweight crypto transaction ledger." Target="[INSTALLFOLDER]jxledger.exe" WorkingDirectory="INSTALLFOLDER" /^>
echo       ^</Component^>
echo     ^</ComponentGroup^>
echo     ^<Feature Id="MainApplication" Title="JXLedger Application" Level="1" ^>
echo       ^<ComponentGroupRef Id="AppFiles" /^>
echo       ^<ComponentGroupRef Id="DataFiles" /^>
echo       ^<ComponentGroupRef Id="ShortcutCleanup" /^>
echo     ^</Feature^>
echo   ^</Package^>
echo ^</Wix^>
) > "%TEMP_WXS%"


echo Building MSI installer via Built-in WiX v7 Files Engine...
call wix build -acceptEula wix7 "%TEMP_WXS%" -o "%TARGET_MSI%"

if exist "%TEMP_WXS%" del /Q "%TEMP_WXS%"

git checkout -- lib/app/constants.dart

echo ---------------------------------------
echo Done! MSI file available at: %TARGET_MSI%
echo ---------------------------------------
exit
