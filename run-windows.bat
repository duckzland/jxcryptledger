Write-Host "Launching Flutter App on Windows with Development Configuration..." -ForegroundColor Cyan

# Invoke flutter run and tunnel the argument cleanly to the native binary
flutter run -d windows --dart-entrypoint-args "--development"
