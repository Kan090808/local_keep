import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:local_keep/screens/auth_screen.dart';
import 'package:local_keep/services/backup_service.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _restoreFromBackup(BuildContext context) async {
    try {
      // Select backup file
      FilePickerResult? pickResult;
      try {
        pickResult = await FilePicker.platform.pickFiles(
          dialogTitle: 'Select Local Keep Backup',
          type: FileType.custom,
          allowedExtensions: BackupService.backupExtensions,
          withData: true,
        );
      } catch (e) {
        // Fallback to any file type if custom type fails on iOS
        pickResult = await FilePicker.platform.pickFiles(
          dialogTitle: 'Select Local Keep Backup (.lkeep)',
          type: FileType.any,
          withData: true,
        );
      }

      if (pickResult == null || pickResult.files.isEmpty) {
        return;
      }

      final file = pickResult.files.first;

      if (!BackupService.isSupportedBackupFile(file.name)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Selected file "${file.name}" is not a valid .${BackupService.backupExtensions.first} backup.',
              ),
            ),
          );
        }
        return;
      }

      Uint8List? fileBytes = file.bytes;
      if (fileBytes == null) {
        final path = file.path;
        if (path == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to read the selected backup file.'),
              ),
            );
          }
          return;
        }
        fileBytes = await File(path).readAsBytes();
      }

      if (!context.mounted) return;

      // Show password dialog
      final passwordController = TextEditingController();
      final password = await showDialog<String>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Restore from Backup'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Enter the backup password'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed:
                      () => Navigator.of(ctx).pop(passwordController.text),
                  child: const Text('Restore'),
                ),
              ],
            ),
      );

      if (password == null || password.isEmpty) {
        return;
      }

      if (!context.mounted) return;

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (ctx) => const AlertDialog(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Restoring backup...'),
                ],
              ),
            ),
      );

      try {
        final restoredCount =
            await BackupService.importEncryptedBackupFirstTime(
              fileBytes: fileBytes,
              restorePassword: password,
            );

        if (!context.mounted) return;
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop(); // Close loading dialog

        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Restore Successful'),
                content: Text('Restored $restoredCount notes from backup.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const AuthScreen()),
                      );
                    },
                    child: const Text('Continue'),
                  ),
                ],
              ),
        );
      } catch (e) {
        if (!context.mounted) return;
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore backup: ${e.toString()}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Title
              Text(
                'Local Keep',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Description
              Text(
                'Store data only in local',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // Start Now Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const AuthScreen(isFirstTime: true),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Start Now',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Restore from Backup Button
              SizedBox(
                height: 56,
                child: OutlinedButton(
                  onPressed: () => _restoreFromBackup(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal,
                    side: const BorderSide(color: Colors.teal, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Restore from Backup',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
