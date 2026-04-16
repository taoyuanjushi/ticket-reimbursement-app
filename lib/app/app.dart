import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ticket_box/app/navigation/app_destination.dart';
import 'package:ticket_box/app/navigation/app_router.dart';
import 'package:ticket_box/app/theme/app_theme.dart';

class TicketBoxApp extends StatelessWidget {
  const TicketBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '票据盒',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
