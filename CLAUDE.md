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

### Icon Generation
```bash
flutter pub run flutter_launcher_icons:main  # Generate app icons
```

## Architecture

### Core Components

#### Authentication System
- **AuthProvider** (`lib/providers/auth_provider.dart`): Manages user authentication state, password creation/verification, and app locking
- **CryptoService** (`lib/services/crypto_service.dart`): Handles PBKDF2 key derivation and AES-256 encryption/decryption
- **App Auto-Lock**: Implemented in `main.dart` - locks immediately on Android/iOS when backgrounded, 1-minute timer on Windows/macOS

#### Data Layer
- **DatabaseService** (`lib/services/database_service.dart`): SQLite database operations with automatic encryption/decryption
- **Note Model** (`lib/models/note.dart`): Data model for notes with created_at/updated_at timestamps
- **NoteProvider** (`lib/providers/note_provider.dart`): State management for notes using Provider pattern

#### UI Structure
- **Screen Navigation**: `AuthScreen` → `NotesScreen` → `NoteEditorScreen`
- **Settings Flow**: Accessed from `NotesScreen`, includes password change and data management
- **Material Design 3**: Uses teal color scheme with `ColorScheme.fromSeed`

### Data Flow
1. User authenticates via `AuthScreen` 
2. Password is verified through `CryptoService.verifyPassword()`
3. `DatabaseService.setPassword()` enables encrypted operations
4. Notes are automatically encrypted before storage and decrypted on retrieval
5. All state managed through Provider pattern

### Security Features
- Password verification using PBKDF2
- Notes encrypted with AES-256 + IV before database storage
- Automatic app locking on platform-specific triggers
- Password change re-encrypts all existing notes
- Complete data wipe capability

## Dependencies

Key packages:
- `flutter_secure_storage`: Secure password hash storage
- `encrypt`: AES encryption implementation
- `crypto`: PBKDF2 key derivation
- `sqflite`: Local SQLite database
- `provider`: State management pattern

## Testing

The project uses Flutter's standard testing framework. The main test file is `test/widget_test.dart` (currently contains default counter test - needs updating for actual app functionality).

## Platform Support

- **Mobile**: Android, iOS (immediate lock on background)
- **Desktop**: Windows, macOS (1-minute timer lock)
- **Web**: Supported but not optimized for the use case