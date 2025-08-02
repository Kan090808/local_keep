# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Local Keep is a Flutter app for secure, encrypted note-taking with 100% local storage. It uses end-to-end encryption with PBKDF2 key derivation and AES-256 with IV to protect user data.

## Development Commands

### Build and Run
```bash
flutter run                    # Run app in development mode
flutter build apk             # Build Android APK
flutter build ios             # Build iOS app
flutter build macos           # Build macOS app
flutter build windows         # Build Windows app
```

### Testing and Quality
```bash
flutter test                   # Run all tests
flutter analyze               # Static analysis (lint check)
flutter pub get               # Install dependencies
flutter clean                 # Clean build artifacts
```

### Code Generation and Build Setup
```bash
dart run build_runner build          # Generate Hive adapters and JSON serialization
flutter pub run flutter_launcher_icons:main  # Generate app icons
flutter config --enable-web          # Enable web support (one-time setup)
```

### Web Deployment
```bash
flutter build web --release --base-href "/local_keep/"  # Build for GitHub Pages
flutter build web --release          # Build for general web deployment
```

## Architecture

### Core Components

#### Authentication System
- **AuthProvider** (`lib/providers/auth_provider.dart`): Manages user authentication state, password creation/verification, and app locking
- **CryptoService** (`lib/services/crypto_service.dart`): Handles PBKDF2 key derivation and AES-256 encryption/decryption
- **App Auto-Lock**: Implemented in `main.dart` - locks immediately on Android/iOS when backgrounded, 1-minute timer on Windows/macOS

#### Data Layer
- **HiveDatabaseService** (`lib/services/hive_database_service.dart`): Hive NoSQL database operations with automatic encryption/decryption
- **Note Model** (`lib/models/note.dart`): Data model for notes with created_at/updated_at timestamps and JSON serialization
- **NoteProvider** (`lib/providers/note_provider.dart`): State management for notes using Provider pattern with performance optimizations
- **MigrationService** (`lib/services/migration_service.dart`): Handles data migration and version management
- **NoteObjectPool** (`lib/services/note_object_pool.dart`): Object pooling for memory optimization
- **SmartDebounceService** (`lib/services/smart_debounce_service.dart`): Intelligent debouncing for auto-save functionality
- **EncryptionIsolateService** (`lib/services/encryption_isolate_service.dart`): Background encryption processing in isolates

#### UI Structure
- **Screen Navigation**: `AuthScreen` → `NotesScreen` → `NoteEditorScreen`
- **Settings Flow**: Accessed from `NotesScreen`, includes password change and data management
- **Material Design 3**: Uses teal color scheme with `ColorScheme.fromSeed`

### Data Flow
1. User authenticates via `AuthScreen` 
2. Password is verified through `CryptoService.verifyPassword()`
3. `HiveDatabaseService.setPassword()` enables encrypted operations
4. Notes are automatically encrypted before Hive storage and decrypted on retrieval
5. Background encryption processing handled by isolates for performance
6. All state managed through Provider pattern with intelligent debouncing

### Security Features
- Password verification using PBKDF2
- Notes encrypted with AES-256 + IV before Hive storage
- Background encryption processing in isolates for security isolation
- Automatic app locking on platform-specific triggers
- Password change re-encrypts all existing notes
- Complete data wipe capability

## Dependencies

Key packages:
- `flutter_secure_storage`: Secure password hash storage
- `encrypt`: AES encryption implementation
- `crypto`: PBKDF2 key derivation
- `hive`: NoSQL local database for note storage
- `hive_flutter`: Flutter integration for Hive
- `provider`: State management pattern
- `json_annotation`: JSON serialization support

## Testing

The project uses Flutter's standard testing framework. Tests should be added to validate the core encryption/decryption functionality and note management features.

## Development Setup

### Prerequisites
- Flutter SDK (3.32.8+ recommended for web deployment compatibility)
- Dart SDK
- Web browser for testing

### Initial Setup
1. Install dependencies: `flutter pub get`
2. Generate required code: `dart run build_runner build`
3. Enable web support: `flutter config --enable-web`
4. Run on web: `flutter run -d web`

### Deployment
- **Live Demo**: https://kan090808.github.io/local_keep/
- **Automatic Deployment**: GitHub Actions deploys to GitHub Pages on every push to master
- **Manual Web Build**: Use `--base-href "/local_keep/"` for GitHub Pages deployment

## Platform Support

- **Mobile**: Android, iOS (immediate lock on background)
- **Desktop**: Windows, macOS (1-minute timer lock)
- **Web**: Supported but not optimized for the use case