import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:local_keep/providers/auth_provider.dart';
import 'package:local_keep/providers/note_provider.dart';
import 'package:local_keep/screens/auth_screen.dart';
import 'package:local_keep/screens/welcome_screen.dart';
import 'package:local_keep/services/app_lifecycle_service.dart';
import 'package:local_keep/services/app_logger.dart';
import 'package:local_keep/services/hive_database_service.dart';

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

  /// Mobile: lock immediately when backgrounded.
  /// Desktop/web: short grace period for window switching.
  Duration get _lockDelay {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return Duration.zero;
      default:
        return const Duration(seconds: 60);
    }
  }

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
    if (currentContext == null) return;

    final authProvider = Provider.of<AuthProvider>(
      currentContext,
      listen: false,
    );
    final noteProvider = Provider.of<NoteProvider>(
      currentContext,
      listen: false,
    );

    if (_lifecycleService.shouldSkipLock) {
      AppLogger.d('Skipping lock: active file operation');
      // Re-arm a short timer so a stuck flag cannot suppress lock forever.
      _startLockTimer(overrideDelay: const Duration(seconds: 15));
      return;
    }

    if (!authProvider.isAuthenticated) {
      return;
    }

    final hasPassword = await authProvider.isAppInitialized();
    if (!hasPassword) {
      return;
    }

    AppLogger.d('Locking app');
    noteProvider.clearNotes();
    await authProvider.lockApp();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    AppLogger.d('App lifecycle: $state');

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        // inactive also covers iOS app switcher snapshots — start lock path.
        if (state == AppLifecycleState.inactive) {
          // On mobile, inactive is noisy (keyboard, permission sheets).
          // Only start lock timer for paused/hidden; inactive alone does not lock.
          return;
        }
        _startLockTimer();
        break;
      case AppLifecycleState.resumed:
        _cancelLockTimer();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  void _startLockTimer({Duration? overrideDelay}) {
    _lockTimer?.cancel();
    final delay = overrideDelay ?? _lockDelay;
    AppLogger.d('Starting lock timer (${delay.inSeconds}s)');
    _lockTimer = Timer(delay, () {
      _triggerLock();
    });
  }

  void _cancelLockTimer() {
    if (_lockTimer != null && _lockTimer!.isActive) {
      AppLogger.d('Cancelling lock timer');
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
          return const AuthScreen();
        } else {
          return const WelcomeScreen();
        }
      },
    );
  }
}
