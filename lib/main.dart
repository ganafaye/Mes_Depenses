import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'data/secure_store.dart';
import 'screens/lock_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/onboarding_screen.dart';
import 'services/detection_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  runApp(const MesDepensesApp());
}

class MesDepensesApp extends StatelessWidget {
  const MesDepensesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mes Dépenses',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        canvasColor: Colors.white,
        dialogBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const _StartupRouter(),
    );
  }
}

class _StartupRouter extends StatefulWidget {
  const _StartupRouter();

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

enum _StartupState { onboarding, lock, home }

class _StartupRouterState extends State<_StartupRouter> {
  _StartupState? _state;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  Future<void> _initialiser() async {
    DetectionService.instance.demarrer();

    final onboardingTermine = await SecureStore.isOnboardingTermine();
    final pinActif = await SecureStore.hasPin();

    if (!mounted) return;

    setState(() {
      if (!onboardingTermine) {
        _state = _StartupState.onboarding;
      } else if (pinActif) {
        _state = _StartupState.lock;
      } else {
        _state = _StartupState.home;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == null) {
      return const SizedBox.shrink();
    }

    switch (state) {
      case _StartupState.onboarding:
        return const OnboardingScreen();
      case _StartupState.lock:
        return const LockScreen();
      case _StartupState.home:
        return const MainNavigation();
    }
  }
}
