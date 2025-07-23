import 'package:flutter/foundation.dart';
import 'package:local_keep/services/crypto_service.dart';
import 'package:local_keep/services/hive_database_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;

  // Check if the app has been initialized with a password
  Future<bool> isAppInitialized() async {
    return await CryptoService.isPasswordSetup();
  }

  // Create a new password (first time setup)
  Future<bool> createPassword(String password) async {
    try {
      await CryptoService.setupPassword(password);
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
      _isAuthenticated = true;
      HiveDatabaseService.setPassword(password);
      notifyListeners();
    }
    return isValid;
  }

  // Delete all notes from the database
  Future<void> deleteAllNotes() async {
    try {
      await HiveDatabaseService.clearNotes();
      notifyListeners();
    } catch (e) {
      print('Error deleting all notes: $e');
    }
  }

  // Change password
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    try {
      final isValid = await CryptoService.verifyPassword(oldPassword);
      if (!isValid) return false;

      await HiveDatabaseService.reEncryptNotes(oldPassword, newPassword);
      await CryptoService.setupPassword(newPassword);
      
      _isAuthenticated = true;
      HiveDatabaseService.setPassword(newPassword);
      notifyListeners();
      return true;
    } catch (e) {
      print('Error changing password: $e');
      return false;
    }
  }

  // Lock the app
  void lockApp() {
    _isAuthenticated = false;
    notifyListeners();
  }

  // Clear sensitive data from memory
  void clearSensitiveData() {
    // Simple cleanup
  }
}
