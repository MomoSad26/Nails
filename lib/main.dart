import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'features/dashboard/dashboard_shell.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  runApp(const ManiGestApp());
}

class ManiGestApp extends StatelessWidget {
  const ManiGestApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ManiGest',
        debugShowCheckedModeBanner: false,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB76E79)),
          scaffoldBackgroundColor: const Color(0xFFFFFAFA),
          appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFF0E3E5))),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        home: const DashboardShell(),
      );
}

