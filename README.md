# Local Keep

A fully local encrypted note-taking app that prioritizes your privacy and security.

**🌐 [Try Local Keep now in your browser](https://chat-849ed.web.app)**

## Features

### 🔒 Security & Privacy
- 💻 **100% local storage** - your data never leaves your device
- 🔐 **End-to-end encryption** using PBKDF2 key derivation and AES-256 with IV
- 🔒 **Automatic app locking** when backgrounded (immediate on mobile, 1 minute on desktop)
- 🛡️ **Password protection** with secure password management

### 📱 Platform Support
- **Currently available on Web**: [Try Local Keep](https://chat-849ed.web.app)
- **Built with Flutter** for future cross-platform support (iOS, Android, Windows, macOS)
- **Native performance** with Flutter framework
- **Responsive design** that works on all screen sizes

### 📝 Note Management
- ✍️ **Simple note creation and editing** with autosave
- 📋 **Copy notes to clipboard** for easy sharing
- 🕒 **Notes ordered by creation time** (newest first)
- 🗑️ **Delete notes** with confirmation dialog
- ⚡ **Optimized performance** with smart debouncing and object pooling

### 🛠️ Additional Features
- 🔄 **Password change functionality** 
- 🗄️ **Data reset option** (clears all notes and password)
- ⚙️ **Settings screen** with GitHub project link and donation options
- 🎨 **Material 3 design** with teal color scheme

## Technical Details

- **Encryption**: AES-256 encryption with PBKDF2 key derivation
- **Storage**: Local Hive database with encrypted content
- **Performance**: Isolate-based encryption for non-blocking UI
- **Architecture**: Provider pattern for state management

## Getting Started

### Quick Start (Web)
Simply visit [https://chat-849ed.web.app](https://chat-849ed.web.app) in your web browser to start using Local Keep immediately. No installation required!

### Development Setup

#### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK
- Web browser for testing

#### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/Kan090808/local_keep.git
   cd local_keep
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Generate Hive adapters:
   ```bash
   dart run build_runner build
   ```

4. Run the app:
   ```bash
   flutter run -d web
   ```

#### Building for Web
```bash
flutter build web --release
```

## Usage

1. **First Run**: Set a master password to protect your notes
2. **Create Notes**: Tap the + button to add new notes
3. **Edit Notes**: Tap any note to edit its content
4. **Copy Notes**: Use the copy button to copy note content to clipboard
5. **Delete Notes**: Use the delete button in edit mode to remove notes
6. **Settings**: Access password change and data reset options via the settings button

## License

Copyright (c) 2025 Jayden Kan

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to use,
copy, modify, and distribute the Software **for non-commercial purposes only**, 
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all 
copies or substantial portions of the Software.

COMMERCIAL USE IS STRICTLY PROHIBITED WITHOUT PRIOR WRITTEN PERMISSION.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE 
SOFTWARE.

For commercial licensing inquiries, please contact: kanjingterng@gmail.com
