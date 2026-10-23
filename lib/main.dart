import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'features/dashboard/dashboard_shell.dart';

const _navy = Color(0xFF071A2B);
const _surface = Color(0xFF102A43);
const _surfaceBorder = Color(0xFF36516B);
const _lightText = Color(0xFFF0F6FF);
const _mutedText = Color(0xFFB7C9DC);
const _turquoise = Color(0xFF62DCEB);
const _gold = Color(0xFFF3C969);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  runApp(const ManiGestApp());
}

class ManiGestApp extends StatelessWidget {
  const ManiGestApp({super.key, this.enableOverdueTimer = true});
  final bool enableOverdueTimer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _turquoise,
      brightness: Brightness.dark,
    ).copyWith(
      primary: _turquoise,
      onPrimary: _navy,
      secondary: _gold,
      onSecondary: _navy,
      surface: _surface,
      onSurface: _lightText,
      error: const Color(0xFFFF9292),
      onError: const Color(0xFF2B1010),
      outline: const Color(0xFF6A839E),
    );

    const outline = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: _surfaceBorder),
    );

    return MaterialApp(
      title: 'ManiGest',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: _navy,
        canvasColor: _navy,
        dividerColor: _surfaceBorder,
        iconTheme: const IconThemeData(color: _mutedText),
        listTileTheme: const ListTileThemeData(
          textColor: _lightText,
          iconColor: _mutedText,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: _navy,
          foregroundColor: _lightText,
        ),
        cardTheme: CardThemeData(
          color: _surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: _surfaceBorder),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: outline,
          enabledBorder: outline,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: _turquoise, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFFFF9292)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFFFF9292), width: 1.6),
          ),
          filled: true,
          fillColor: Color(0xFF0A2238),
          labelStyle: TextStyle(color: _mutedText),
          hintStyle: TextStyle(color: Color(0xFF91A9C1)),
          helperStyle: TextStyle(color: _mutedText),
          prefixIconColor: _mutedText,
          suffixIconColor: _mutedText,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: _surface,
          titleTextStyle: const TextStyle(
            color: _lightText,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          contentTextStyle: const TextStyle(color: _lightText),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: _surfaceBorder),
          ),
        ),
        popupMenuTheme: const PopupMenuThemeData(color: _surface),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: _surface,
          contentTextStyle: TextStyle(color: _lightText),
          behavior: SnackBarBehavior.floating,
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: _turquoise,
          unselectedLabelColor: _mutedText,
          indicatorColor: _turquoise,
        ),
        tooltipTheme: const TooltipThemeData(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          textStyle: TextStyle(color: _lightText),
        ),
      ),
      home: DashboardShell(enableOverdueTimer: enableOverdueTimer),
    );
  }
}
