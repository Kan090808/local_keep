import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_keep/providers/auth_provider.dart';
import 'package:local_keep/screens/auth_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:local_keep/screens/change_password_screen.dart';
import 'package:local_keep/services/backup_service.dart';
import 'package:local_keep/services/crypto_service.dart';
import 'package:local_keep/providers/note_provider.dart';
import 'package:file_picker/file_picker.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // TODO: Replace with your actual URLs
  final String _githubUrl = 'https://github.com/Kan090808/local_keep';
  final String _donateUrl = 'https://buymeacoffee.com/jaydenkan';

  // Function to launch URLs
  Future<void> _launchUrl(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // Handle error, e.g., show a snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $urlString')));
      }
      print('Could not launch $urlString');
    }
  }

  void _showResetConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Confirm Reset'),
            content: const Text(
              'Are you sure you want to delete all notes and reset your password? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop(); // Close the dialog first
                  await _resetAllData(context);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Confirm Reset'),
              ),
            ],
          ),
    );
  }

  Future<void> _resetAllData(BuildContext context) async {
    // Consider showing a loading indicator here
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      // TODO: Ensure AuthProvider has deleteAllNotes and it handles password reset state
      await authProvider.deleteAllNotes();
      // Resetting password state might involve more steps depending on CryptoService
      // For now, we just navigate back to AuthScreen for first-time setup
      if (context.mounted) {
        // Navigate to AuthScreen for password reset/setup
        // TODO: Ensure AuthScreen handles the reset flow correctly (isFirstTime might need adjustment)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const AuthScreen(isFirstTime: true),
          ),
          (Route<dynamic> route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      // Handle error, e.g., show a snackbar
      print('Error resetting data: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resetting data: ${e.toString()}')),
        );
      }
    } finally {
      // Hide loading indicator if shown
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('Export Encrypted Backup'),
            subtitle: const Text('Save your notes to an encrypted .lkeep file'),
            onTap: () async {
              final controller = TextEditingController();
              final ok = await showDialog<bool>(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      title: const Text('Enter Password'),
                      content: TextField(
                        controller: controller,
                        obscureText: true,
                        decoration: const InputDecoration(hintText: 'Password'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Continue'),
                        ),
                      ],
                    ),
              );
              if (ok != true) return;
              final password = controller.text;
              final valid = await CryptoService.verifyPassword(password);
              if (!valid && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid password')),
                );
                return;
              }

              final success = await BackupService.exportEncrypted(password);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Backup saved' : 'Backup failed'),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('Import Encrypted Backup'),
            subtitle: const Text('Restore notes from an encrypted file'),
            onTap: () async {
              // 1) Let user choose backup file first
              final pick = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['lkeep', 'json', 'txt'],
                withData: true,
              );
              if (pick == null || pick.files.isEmpty) return;
              final file = pick.files.first;
              if (file.bytes == null) return;

              // 2) Ask for the backup file's password
              final controller = TextEditingController();
              final ok = await showDialog<bool>(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      title: const Text('Enter Password of Backup File'),
                      content: TextField(
                        controller: controller,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Password used when exporting this backup',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Continue'),
                        ),
                      ],
                    ),
              );
              if (ok != true) return;
              final password = controller.text.trim();

              // 3) Decrypt with provided password, then save (re-encrypted) into DB
              final success = await BackupService.importEncryptedFromBytes(
                file.bytes!,
                password,
              );
              if (success && context.mounted) {
                // Refresh notes in UI
                await Provider.of<NoteProvider>(
                  context,
                  listen: false,
                ).fetchNotes();
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Import completed' : 'Import failed',
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.password),
            title: const Text('Change Password'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red[700]),
            title: Text(
              'Reset Password & Data',
              style: TextStyle(color: Colors.red[700]),
            ),
            onTap: () => _showResetConfirmationDialog(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.code), // Or a GitHub icon
            title: const Text('GitHub Project'),
            onTap: () {
              _launchUrl(context, _githubUrl); // Use the launch function
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.favorite,
              color: Colors.pink,
            ), // Or a donation icon
            title: const Text('Donate'),
            onTap: () {
              _launchUrl(context, _donateUrl); // Use the launch function
            },
          ),
        ],
      ),
    );
  }
}
