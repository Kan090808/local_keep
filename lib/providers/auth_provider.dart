import 'package:flutter/foundation.dart';
import 'package:local_keep/services/crypto_service.dart';
import 'package:local_keep/services/hive_database_service.dart';
import 'package:local_keep/services/migration_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  String? _encryptedPassword; // Store encrypted password instead of plain text

  bool get isAuthenticated => _isAuthenticated;

  // Check if the app has been initialized with a password
  Future<bool> isAppInitialized() async {
    return await CryptoService.isPasswordSetup();
  }

  // Create a new password (first time setup)
  Future<bool> createPassword(String password) async {
    try {
      await CryptoService.setupPassword(password);

      // Store password hash instead of encrypted password
      final salt = await CryptoService._getOrCreateSalt();
      final hash = CryptoService._deriveKeyFromPassword(password, salt);
      _passwordHash = base64.encode(hash);

      _isAuthenticated = true;
      await HiveDatabaseService.setPassword(password);

      // Clear the plain text password from local scope
      password = ''; // This helps with garbage collection

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Verify existing password
  Future<bool> verifyPassword(String password) async {
    final isValid = await CryptoService.verifyPassword(password);
    if (isValid) {
      // Store password hash for verification
      final salt = await CryptoService._getOrCreateSalt();
      final hash = CryptoService._deriveKeyFromPassword(password, salt);
      _passwordHash = base64.encode(hash);

      _isAuthenticated = true;
      await HiveDatabaseService.setPassword(password);

      // Check if migration is needed and perform it
      try {
        if (await MigrationService.needsMigration()) {
          print('Migration needed, starting migration...');
          await MigrationService.migrateSqliteToHive(password);
          print('Migration completed successfully');
        }
      } catch (e) {
        print('Migration failed: $e');
        // Continue anyway, as the user can still use the app
      }

      // Clear the plain text password from local scope
      password = ''; // This helps with garbage collection

      notifyListeners();
    }
    return isValid;
  }

  // Delete all notes from the database
  Future<void> deleteAllNotes() async {
    try {
      print('Deleting all notes...');
      await HiveDatabaseService.clearNotes();
      print('All notes deleted successfully');
      notifyListeners();
    } catch (e) {
      print('Error deleting all notes: $e');
    }
  }

  // Change password
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    try {
      // Verify old password first
      final isValid = await CryptoService.verifyPassword(oldPassword);
      if (!isValid) {
        return false;
      }

      // Re-encrypt all notes with new password
      await HiveDatabaseService.reEncryptNotes(oldPassword, newPassword);

      // Setup new password in CryptoService
      await CryptoService.setupPassword(newPassword);

      // Create encrypted version for memory storage
      _encryptedPassword = await CryptoService.createMemoryEncryptedPassword(
        newPassword,
      );

      _isAuthenticated = true;
      await HiveDatabaseService.setPassword(newPassword);

      // Clear the plain text passwords from local scope
      oldPassword = '';
      newPassword = '';

      notifyListeners();
      return true;
    } catch (e) {
      print('Error changing password: $e');
      return false;
    }
  }

  // Reset the password and clear all data
  Future<void> resetPassword() async {
    try {
      print('Resetting password...');
      // Clear the encrypted password
      _encryptedPassword = null;
      _isAuthenticated = false;

      // Reset the password in the CryptoService
      await CryptoService.setupPassword('');
      print('Password reset successfully');
      notifyListeners();
    } catch (e) {
      print('Error resetting password: $e');
    }
  }

  // Lock the app
  void lockApp() {
    _isAuthenticated = false;
    clearSensitiveData();
    notifyListeners();
  }

  // Clear sensitive data from memory
  void clearSensitiveData() {
    if (_passwordHash != null) {
      // Clear password hash
      _passwordHash = null;
    }
    // Force garbage collection
    Future.delayed(Duration.zero, () {
      // Create some noise to help overwrite memory
      final noise = List.generate(1000, (_) => DateTime.now().toString());
      noise.clear();
    });
  }

  // Store the password hash for verification instead of encrypted password
  String? _passwordHash;

  // Verify and get current password when needed
  Future<String?> getCurrentPassword(String inputPassword) async {
    if (_passwordHash == null) return null;
    
    try {
      // Verify the input password against stored hash
      final isValid = await CryptoService.verifyPassword(inputPassword);
      if (isValid) {
        return inputPassword;
      }
      return null;
    } catch (e) {
      print('Error verifying password: $e');
      return null;
    }
  }

  @override
  void dispose() {
    clearSensitiveData();
    super.dispose();
  }
}
