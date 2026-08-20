import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:local_keep/services/app_logger.dart';
import 'package:local_keep/services/crypto_service.dart';
import 'package:local_keep/services/hive_database_service.dart';
import 'package:local_keep/services/media_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;

  Future<bool> isAppInitialized() async {
    return CryptoService.isPasswordSetup();
  }

  Future<bool> createPassword(String password) async {
    try {
      await CryptoService.setupPassword(password);
      await HiveDatabaseService.ensureOpen(password);
      _isAuthenticated = true;
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.e('createPassword failed', e);
      return false;
    }
  }

  Future<bool> verifyPassword(String password) async {
    try {
      if (!await CryptoService.verifyPassword(password)) return false;
      await HiveDatabaseService.ensureOpen(password);
      _isAuthenticated = true;
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.e('verifyPassword failed', e);
      _isAuthenticated = false;
      await HiveDatabaseService.close();
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteAllNotes() async {
    try {
      await HiveDatabaseService.clearNotes();
      await MediaService.clearAllMedia();
      notifyListeners();
    } catch (e) {
      AppLogger.e('Error deleting all notes', e);
      rethrow;
    }
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    try {
      final isValid = await CryptoService.verifyPassword(oldPassword);
      if (!isValid) return false;

      // Re-encrypt media first (while still able to decrypt with old password).
      final media = await MediaService.snapshotEncryptedMedia();
      final reEncryptedMedia = <String, Uint8List>{};
      for (final entry in media.entries) {
        final plain = await CryptoService.decryptBytes(
          base64Encode(entry.value),
          oldPassword,
        );
        reEncryptedMedia[entry.key] = base64Decode(
          await CryptoService.encryptBytes(plain, newPassword),
        );
      }

      // Notes + hive re-key.
      await HiveDatabaseService.reEncryptAll(oldPassword, newPassword);

      // Persist media under new key.
      await MediaService.replaceAllEncryptedMedia(reEncryptedMedia);

      await CryptoService.setupPassword(newPassword);

      await HiveDatabaseService.ensureOpen(newPassword);
      _isAuthenticated = true;
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.e('Error changing password', e);
      return false;
    }
  }

  /// Lock app: clear auth flag, close DB, wipe in-memory password.
  Future<void> lockApp() async {
    _isAuthenticated = false;
    await clearSensitiveData();
    notifyListeners();
  }

  Future<void> clearSensitiveData() async {
    try {
      await MediaService.cleanupPreviewTempFiles();
    } catch (e) {
      AppLogger.e('Preview cleanup on lock failed', e);
    }
    await HiveDatabaseService.close();
  }
}
