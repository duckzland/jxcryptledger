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
Only fire this when the app icon change. This will rebuild the ico for windows
```
flutter run flutter_launcher_icons 
```

### Running aps

```
# On windoww box
flutter run -d windows 

# On debian box
flutter run -d linux
```

### Compiling
Remember to update version.txt first.

```
# on windows
./build-windows.bat

# on ubuntu
./build-debian.sh
```



