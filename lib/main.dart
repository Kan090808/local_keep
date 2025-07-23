import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_keep/screens/auth_screen.dart';
import 'package:local_keep/providers/auth_provider.dart';
import 'package:local_keep/providers/note_provider.dart';
import 'package:local_keep/services/hive_database_service.dart';
import 'package:local_keep/services/encryption_isolate_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print('Initializing Local Keep...');
    
    // Initialize Hive
    print('Initializing Hive database...');
    await HiveDatabaseService.initialize();
    print('Hive database initialized successfully');

    // Initialize encryption isolate service for better performance
    print('Initializing encryption service...');
    await EncryptionIsolateService.initialize();
    print('Encryption service initialized successfully');
    
    print('Starting app...');
    runApp(const MyApp());
  } catch (e) {
    print('Error during initialization: $e');
    runApp(const MyApp()); // Run anyway to show error state
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  Timer? _lockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _triggerLock() {
    final currentContext = navigatorKey.currentContext;
    if (currentContext != null) {
      final authProvider = Provider.of<AuthProvider>(currentContext, listen: false);
      authProvider.lockApp();
      // Clear sensitive data from memory
      authProvider.clearSensitiveData();
    }
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      if (Platform.isAndroid || Platform.isIOS) {
        _triggerLock();
      } else if (Platform.isWindows || Platform.isMacOS) {
        _lockTimer?.cancel();
        _lockTimer = Timer(const Duration(minutes: 1), _triggerLock);
      }
    } else if (state == AppLifecycleState.resumed) {
      _lockTimer?.cancel();
    }
    print('App lifecycle state: $state');
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

    // Check if the app is initialized and user authentication status
    return FutureBuilder<bool>(
      future: authProvider.isAppInitialized(),
      builder: (context, snapshot) {
        print('AppEntryPoint - Connection state: ${snapshot.connectionState}');
        print('AppEntryPoint - Has data: ${snapshot.hasData}');
        print('AppEntryPoint - Data: ${snapshot.data}');
        print('AppEntryPoint - Error: ${snapshot.error}');
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('AppEntryPoint - Showing loading screen');
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing Local Keep...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          print('AppEntryPoint - Error: ${snapshot.error}');
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Initialization Error'),
                  SizedBox(height: 8),
                  Text('${snapshot.error}', textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        if (snapshot.data == true) {
          print('AppEntryPoint - App initialized, showing auth screen');
          return const AuthScreen();
        } else {
          print('AppEntryPoint - First time setup, showing auth screen');
          return const AuthScreen(isFirstTime: true);
        }
      },
    );
  }
}
