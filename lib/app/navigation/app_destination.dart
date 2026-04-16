import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppRoutes {
  const AppRoutes._();

  static const home = '/';
  static const tickets = '/tickets';
  static const reimbursements = '/reimbursements';
  static const settings = '/settings';
}

enum AppDestination {
  home(
    label: '首页',
    route: AppRoutes.home,
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  tickets(
    label: '票据',
    route: AppRoutes.tickets,
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
  ),
  reimbursements(
    label: '报销单',
    route: AppRoutes.reimbursements,
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet_rounded,
  ),
  settings(
    label: '设置',
    route: AppRoutes.settings,
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
  );

  const AppDestination({
    required this.label,
    required this.route,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String route;
  final IconData icon;
  final IconData selectedIcon;

  static AppDestination fromRoute(String? route) {
    return AppDestination.values.firstWhere(
      (destination) => destination.route == route,
      orElse: () => AppDestination.home,
    );
  }
}

final appDestinationsProvider = Provider<List<AppDestination>>(
  (ref) => AppDestination.values,
);
