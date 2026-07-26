## Helper commands

### Seeding database

Wipe and seed database with new cryptos.json and/or generated transactions

```
## Wipe and seed all
dart run tools/seed_database.dart

## Wipe and only seeds transactions box
dart run tools/seed_database.dart --seed-transactions 

## Wipe and only seeds cryptos box
dart run tools/seed_database.dart --seed-cryptos
```

### Wipe database

This will wipe all boxes!

```
dart run tools/wipe_boxes.dart
```

### Seeding rates

This will fill the rates with generated rate. Not very useful and experimental

```
dart run tools/seed_rates.dart
```

### Wipe rates

This will wipe only rates box

```
dart run tools/wipe_rates.dart
```

### Refreshing icon

Only fire this when the app icon change. This will rebuild the ico for windows.

```
flutter run flutter_launcher_icons 
```

It is recommended to fire the icon generator instead to avoid compiler complain about broken ico file.

```
dart run tools/create_icons.dart
```

You can also use the test compiler to check if the ico file is in the correct format.

```
dart run tools/test_local_compiler.dart
```

### Running aps

```
# On windows box, it is recommended to fire the run-windows.bat script as the IPC need the --development flags
flutter run -d windows --dart-entrypoint-args "--development"

# On debian box, it is recommended to fire the run-linux.sh script as the IPC need the --development flags
flutter run -d linux --dart-entrypoint-args "--development"
```

### Compiling

Remember to update version.txt first.

```
# on windows for msix [not supported anymore, future build test will be on msi]
./build-msix.bat

# on windows for msi
./build-msi.bat

# on ubuntu
./build-debian.sh
```
