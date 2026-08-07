@echo off
set "RUN_MODE="

if "%~1"=="--profile" (
    set "RUN_MODE=--profile"
)

echo Launching Flutter App on Windows with Development Configuration...
flutter run -d windows %RUN_MODE% --dart-entrypoint-args "--development"
