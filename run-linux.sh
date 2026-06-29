#!/bin/bash

echo -e "\033[36mLaunching Flutter App on Windows with Development Configuration...\033[0m"

# Execute flutter run and safely pass the argument down to the native binary
flutter run -d linux --dart-entrypoint-args "--development"
