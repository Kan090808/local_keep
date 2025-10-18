import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_keep/providers/auth_provider.dart';
import 'package:local_keep/screens/welcome_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:local_keep/screens/change_password_screen.dart';
import 'package:local_keep/services/backup_service.dart';
import 'package:local_keep/services/crypto_service.dart';

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
                  // Close confirmation first
                  Navigator.of(ctx).pop();
                  // Ask user to enter current password
                  final controller = TextEditingController();
                  final ok = await showDialog<bool>(
                    context: context,
                    builder:
                        (pwdCtx) => AlertDialog(
                          title: const Text('Enter Current Password'),
                          content: TextField(
                            controller: controller,
                            obscureText: true,
                            decoration: const InputDecoration(
                              hintText: 'Current Password',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(pwdCtx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(pwdCtx).pop(true),
                              child: const Text('Confirm'),
                            ),
                          ],
                        ),
                  );
                  if (ok != true) return;
                  final pwd = controller.text;
                  final valid = await CryptoService.verifyPassword(pwd);
                  if (!valid) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invalid password')),
                      );
                    }
                    return;
                  }

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
      // Also wipe stored password hash and salt
      await CryptoService.clearAll();
      // Resetting password state might involve more steps depending on CryptoService
      // Navigate back to WelcomeScreen to show the onboarding flow again
      if (context.mounted) {
        // Navigate to WelcomeScreen for fresh start
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
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

  Future<String?> _promptForPassword(
    BuildContext context, {
    required String title,
    String? message,
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (message != null) ...[
                  Text(message),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: controller,
                  obscureText: true,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Password'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text),
                child: const Text('Confirm'),
              ),
            ],
          ),
    );
  }

  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 16),
                  Expanded(child: Text(message)),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _exportBackup(BuildContext context) async {
    final password = await _promptForPassword(
      context,
      title: 'Export Backup',
      message: 'Enter your app password to create an encrypted backup.',
    );

    if (password == null || password.isEmpty) {
      return;
    }

    final isValid = await CryptoService.verifyPassword(password);
    if (!isValid) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid password. Backup cancelled.')),
        );
      }
      return;
    }

    _showLoadingDialog(context, 'Creating encrypted backup...');

    try {
      final savedPath = await BackupService.exportEncryptedBackup(password);
      if (!context.mounted) return;

      Navigator.of(context, rootNavigator: true).pop();

      if (savedPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup export cancelled.')),
        );
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backup saved: $savedPath')));
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create backup: ${e.toString()}')),
      );
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
            leading: const Icon(Icons.password),
            title: const Text('Change Password'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Export Backup'),
            subtitle: const Text('Create encrypted backup with media'),
            onTap: () => _exportBackup(context),
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
