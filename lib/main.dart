import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/licence.dart';
import 'core/store.dart';
import 'ui/home_shell.dart';
import 'ui/licence_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  await AppStore.I.init();
  runApp(const EtikProApp());
}

const brandBlue = Color(0xFF14427A);
const brandOrange = Color(0xFFE8731C);

class EtikProApp extends StatelessWidget {
  const EtikProApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandBlue,
      primary: brandBlue,
      secondary: brandOrange,
    );
    return MaterialApp(
      title: 'ETIKPRO',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: false),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: scheme.outlineVariant),
          ),
        ),
      ),
      home: const LicenceGate(),
    );
  }
}

/// Vérifie la licence avant d'ouvrir l'application.
class LicenceGate extends StatefulWidget {
  const LicenceGate({super.key});
  @override
  State<LicenceGate> createState() => _LicenceGateState();
}

class _LicenceGateState extends State<LicenceGate> {
  bool _loading = true;
  bool _valid = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _loading = true);
    final r = await LicenceService.I.verify();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _valid = r.valid;
      _error = r.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image(image: AssetImage('assets/logo/logo_full.png'), width: 280),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ]),
        ),
      );
    }
    if (_valid) {
      return HomeShell(onLogout: () async {
        await LicenceService.I.logout();
        setState(() => _valid = false);
      });
    }
    return LicenceScreen(
      initialError: _error,
      onActivated: () => setState(() {
        _valid = true;
        _error = null;
      }),
      onRetry: _check,
    );
  }
}
