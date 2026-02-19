#!/bin/bash

###
# lib/
# ├── app
# │   ├── exceptions.dart
# │   ├── layout.dart
# │   ├── root.dart
# │   ├── router.dart
# │   ├── storage.dart
# │   └── theme.dart
# ├── core
# │   ├── encryption_service.dart
# │   ├── filter_isolate.dart
# │   └── utils.dart
# ├── features
# │   ├── settings
# │   │   ├── adapter.dart
# │   │   ├── controller.dart
# │   │   ├── model.dart
# │   │   ├── page.dart
# │   │   ├── repository.dart
# │   │   └── screen.dart
# │   ├── transactions
# │   │   ├── adapter.dart
# │   │   ├── controller.dart
# │   │   ├── filter_service.dart
# │   │   ├── model.dart
# │   │   ├── page.dart
# │   │   ├── page_single.dart
# │   │   ├── repository.dart
# │   │   └── screen.dart
# │   └── unlock
# │       ├── controller.dart
# │       └── page.dart
# ├── main.dart
# └── widgets
#     └── button.dart
# ###

# Create base directories
mkdir -p lib/{app,core,data,features,services,widgets}

# App-level structure
mkdir -p lib/app/{router/screens,theme}
touch lib/app/app.dart
touch lib/app/router/router.dart
touch lib/app/router/screens/home_screen.dart
touch lib/app/router/screens/settings_screen.dart
touch lib/app/theme/theme.dart

# Core utilities
mkdir -p lib/core/{encryption,errors,isolates,utils}
touch lib/core/encryption/encryption_service.dart
touch lib/core/errors/app_exceptions.dart
touch lib/core/isolates/filter_isolate.dart
touch lib/core/utils/utils.dart

# Data layer
mkdir -p lib/data/{hive_adapters,models,repositories,storage}
touch lib/data/hive_adapters/settings_adapter.dart
touch lib/data/hive_adapters/transactions_adapter.dart
touch lib/data/models/settings_model.dart
touch lib/data/models/transaction_model.dart
touch lib/data/repositories/settings_repository.dart
touch lib/data/repositories/transaction_repository.dart
touch lib/data/storage/hive_storage.dart

# Features
mkdir -p lib/features/{settings,transactions}

# Settings feature
mkdir -p lib/features/settings/{logic,ui,widgets}
touch lib/features/settings/logic/settings_controller.dart
touch lib/features/settings/ui/settings_page.dart
touch lib/features/settings/widgets/settings_screen.dart

# Transactions feature
mkdir -p lib/features/transactions/{logic,services,ui,widgets}
touch lib/features/transactions/logic/transactions_controller.dart
touch lib/features/transactions/services/transaction_filter_service.dart
touch lib/features/transactions/ui/transactions_page.dart
touch lib/features/transactions/widgets/transactions_screen.dart

# Services (global)
touch lib/services/encryption_service.dart

# Common widgets
mkdir -p lib/widgets/common
touch lib/widgets/common/custom_button.dart

# Main entry
touch lib/main.dart

echo "Flutter project structure created successfully!"