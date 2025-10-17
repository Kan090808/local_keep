import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_keep/screens/auth_screen.dart';
import 'package:local_keep/screens/welcome_screen.dart';
import 'package:local_keep/providers/auth_provider.dart';
import 'package:local_keep/providers/note_provider.dart';
import 'package:local_keep/services/hive_database_service.dart';
import 'package:local_keep/services/app_lifecycle_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveDatabaseService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final _lifecycleService = AppLifecycleService();
  Timer? _lockTimer;

  // Lock app after 30 seconds of being in background
  static const Duration _lockDelay = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _triggerLock() async {
    final currentContext = navigatorKey.currentContext;
    if (currentContext != null) {
      final authProvider = Provider.of<AuthProvider>(
        currentContext,
        listen: false,
      );

      // Don't lock if currently picking or previewing a file
      if (_lifecycleService.shouldSkipLock) {
        if (_lifecycleService.isPickingFile) {
          print('Skipping lock: File picking in progress');
        }
        if (_lifecycleService.isPreviewingFile) {
          print('Skipping lock: File preview in progress');
        }
        return;
      }

      // Only lock if a password has been set
      final hasPassword = await authProvider.isAppInitialized();
      if (!hasPassword) {
        print('Skipping lock: No password set');
        return; // Don't lock if no password is set
      }

      print('Locking app');
      authProvider.lockApp();
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    print('App lifecycle state changed to: $state');

    if (state == AppLifecycleState.paused) {
      // App went to background - start 30 second timer
      _startLockTimer();
    } else if (state == AppLifecycleState.resumed) {
      // App came to foreground - cancel timer
      _cancelLockTimer();
    }
  }

  void _startLockTimer() {
    // Cancel any existing timer
    _lockTimer?.cancel();

    print('Starting lock timer (${_lockDelay.inSeconds} seconds)');

    // Start new timer
    _lockTimer = Timer(_lockDelay, () {
      print('Lock timer expired - checking if should lock');
      _triggerLock();
    });
  }

  void _cancelLockTimer() {
    if (_lockTimer != null && _lockTimer!.isActive) {
      print('Cancelling lock timer - app resumed');
      _lockTimer?.cancel();
      _lockTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NoteProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Local Keep',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const AppEntryPoint(),
      ),
    );
  }
}

class AppEntryPoint extends StatelessWidget {
  const AppEntryPoint({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return FutureBuilder<bool>(
      future: authProvider.isAppInitialized(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        if (snapshot.data == true) {
          // Password is already set up - go to unlock screen
          return const AuthScreen();
        } else {
          // No password set up yet - show welcome screen
          return const WelcomeScreen();
        }
      },
    );
  }
}
