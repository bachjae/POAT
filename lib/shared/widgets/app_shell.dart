/// Bottom-tab shell: Home · Progress · Profile.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: shell,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(),
            NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: (i) => shell.goBranch(i,
                  initialLocation: i == shell.currentIndex),
              backgroundColor: RcColors.court,
              indicatorColor: RcColors.courtRaised,
              height: 64,
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home, color: RcColors.ballText),
                    label: 'Home'),
                NavigationDestination(
                    icon: Icon(Icons.show_chart),
                    selectedIcon:
                        Icon(Icons.show_chart, color: RcColors.ballText),
                    label: 'Progress'),
                NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person, color: RcColors.ballText),
                    label: 'Profile'),
              ],
            ),
          ],
        ),
      );
}
