import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticket_box/app/navigation/app_destination.dart';
import 'package:ticket_box/features/home/home_page.dart';
import 'package:ticket_box/features/reimbursements/reimbursements_page.dart';
import 'package:ticket_box/features/settings/settings_page.dart';
import 'package:ticket_box/features/tickets/tickets_page.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.initialDestination, super.key});

  final AppDestination initialDestination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = ref.watch(appDestinationsProvider);
    final destination = initialDestination;
    final pages = <Widget>[
      const KeyedSubtree(key: ValueKey('home-page'), child: HomePage()),
      const KeyedSubtree(
        key: ValueKey('tickets-page-shell'),
        child: TicketsPage(),
      ),
      const KeyedSubtree(
        key: ValueKey('reimbursements-page'),
        child: ReimbursementsPage(),
      ),
      const KeyedSubtree(key: ValueKey('settings-page'), child: SettingsPage()),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: destination.index, children: pages),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: destination.index,
          onDestinationSelected: (index) {
            final nextDestination = destinations[index];

            if (nextDestination == destination) {
              return;
            }

            Navigator.of(context).pushReplacementNamed(nextDestination.route);
          },
          destinations: [
            for (final item in destinations)
              NavigationDestination(
                key: ValueKey('nav-${item.name}'),
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
          ],
        ),
      ),
    );
  }
}
