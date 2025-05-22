import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_keep/screens/auth_screen.dart';
// import 'package:local_keep/screens/notes_screen.dart';
import 'package:local_keep/providers/auth_provider.dart';
import 'package:local_keep/providers/note_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.inactive) {
      final currentContext = navigatorKey.currentContext;
      if (currentContext != null) {
        Provider.of<AuthProvider>(currentContext, listen: false).lockApp();
      }
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false, // Removes all previous routes
      );
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // if (snapshot.data == true && authProvider.currentPassword != null) {
        if(snapshot.data == true) {
          // App is initialized, go to authentication screen
          return const AuthScreen();
        } else {
          // App is not initialized, go to setup screen (create password)
          return const AuthScreen(isFirstTime: true);
        }
      },
    );
  }
}