import 'package:flutter/foundation.dart';
import 'package:local_keep/services/crypto_service.dart';
import 'package:local_keep/services/hive_database_service.dart';
import 'package:local_keep/services/migration_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  String? _currentPassword;

  bool get isAuthenticated => _isAuthenticated;

  // Check if the app has been initialized with a password
  Future<bool> isAppInitialized() async {
    return await CryptoService.isPasswordSetup();
  }

  // Create a new password (first time setup)
  Future<bool> createPassword(String password) async {
    try {
      await CryptoService.setupPassword(password);
      _currentPassword = password;
      _isAuthenticated = true;
      HiveDatabaseService.setPassword(password);
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
      _currentPassword = password;
      _isAuthenticated = true;
      HiveDatabaseService.setPassword(password);

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

      // Update current state
      _currentPassword = newPassword;
      _isAuthenticated = true;
      HiveDatabaseService.setPassword(newPassword);

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
      // Clear the current password
      _currentPassword = null;
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
    _currentPassword = null;
    notifyListeners();
  }

  String? get currentPassword => _currentPassword;
}
