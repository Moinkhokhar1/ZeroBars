import 'package:flutter/material.dart';
import 'package:nextpay/services/app_lock_service.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'offline/wallet_engine.dart';
import 'offline/sync_engine.dart';
import 'offline/network_monitor.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_gate.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..restoreSession(),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          title: 'Offline Payment',
          debugShowCheckedModeBanner: false,
          theme: theme.themeData,
          home: const AppRoot(),
        ),
      ),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});
  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  NetworkMonitor? _networkMonitor;
  bool _monitorStarted = false;
  bool _locked = true;
  bool _lockInitialized = false;   // ← new: avoids flashing wrong screen before lock state loads
  DateTime? _pausedAt;
  bool? _wasLoggedIn;

  // Whether the first-launch intro (splash + onboarding carousel) has
  // already been shown. Null while still reading from storage.
  bool? _seenOnboarding;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLockState();
    _initOnboardingState();
  }

  Future<void> _initLockState() async {
    final pinSet = await AppLockService.instance.isPinSet();
    setState(() {
      _locked = pinSet;
      _lockInitialized = true;     // ← new
    });
  }

  Future<void> _initOnboardingState() async {
    final seen = await StorageService.getItem('has_seen_onboarding');
    if (!mounted) return;
    setState(() => _seenOnboarding = seen == '1');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final pinSet = await AppLockService.instance.isPinSet();
    if (!pinSet) return;

    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedAt != null &&
          DateTime.now().difference(_pausedAt!) > const Duration(seconds: 30)) {
        setState(() => _locked = true);
      }
    }
  }

  @override
  void dispose() {
    _networkMonitor?.stop();
    super.dispose();
  }

  void _startMonitorIfNeeded() {
    if (_monitorStarted) return;
    final auth = context.read<AuthProvider>();
    if (!auth.hydrated || auth.user == null) return;

    _monitorStarted = true;
    final walletEngine = WalletEngine(auth);
    final syncEngine = SyncEngine(auth, walletEngine);
    _networkMonitor = NetworkMonitor(syncEngine);
    _networkMonitor!.start(auth.fetchWallet);
    debugPrint("NETWORK MONITOR INITIALIZED");
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.hydrated) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (auth.user != null && auth.token != null) {
      _startMonitorIfNeeded();
      // PIN setup (new accounts) / lock screen (returning accounts) only
      // ever appears once someone is actually signed in — never before
      // registration or login.
      return OnboardingGate(child: const HomeScreen());
    }

    // First-time visitors see the branded splash + onboarding carousel
    // before landing on login/register. Returning (signed-out) users go
    // straight to LoginScreen.
    if (_seenOnboarding == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_seenOnboarding == false) {
      return const SplashScreen();
    }

    return const LoginScreen();
  }
}