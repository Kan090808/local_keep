import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_keep/providers/auth_provider.dart';
import 'package:local_keep/screens/auth_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:local_keep/screens/change_password_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // TODO: Replace with your actual URLs
  final String _githubUrl = 'https://github.com/Kan090808/local_keep';
  final String _donateUrl = 'https://www.buymeacoffee.com/your_username';

  // Function to launch URLs
  Future<void> _launchUrl(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // Handle error, e.g., show a snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $urlString')),
        );
      }
      print('Could not launch $urlString');
    }
  }

  void _showResetConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Reset'),
        content: const Text(
            'Are you sure you want to delete all notes and reset your password? This action cannot be undone.'),
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
           MaterialPageRoute(builder: (_) => const AuthScreen(isFirstTime: true)),
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
            title: Text('Reset Password & Data', style: TextStyle(color: Colors.red[700])),
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
            leading: const Icon(Icons.favorite, color: Colors.pink), // Or a donation icon
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