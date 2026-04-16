import 'package:flutter/material.dart';
import 'package:ticket_box/app/navigation/app_destination.dart';
import 'package:ticket_box/app/navigation/app_shell.dart';

class AppRouter {
  const AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final destination = AppDestination.fromRoute(settings.name);

    return MaterialPageRoute<void>(
      builder: (_) => AppShell(initialDestination: destination),
      settings: RouteSettings(name: destination.route),
    );
  }
}
