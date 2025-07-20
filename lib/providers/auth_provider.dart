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

      // Create encrypted version for memory storage
      _encryptedPassword = await CryptoService.createMemoryEncryptedPassword(
        password,
      );

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
      // Create encrypted version for memory storage
      _encryptedPassword = await CryptoService.createMemoryEncryptedPassword(
        password,
      );

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
    _encryptedPassword = null;
    notifyListeners();
  }

  // Get current password (decrypted from memory-encrypted version)
  // Use with caution - only when absolutely necessary
  String? get currentPassword {
    if (_encryptedPassword == null) return null;
    try {
      return CryptoService.decryptMemoryEncryptedPassword(_encryptedPassword!);
    } catch (e) {
      print('Error decrypting password: $e');
      return null;
    }
  }
}
