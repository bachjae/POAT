/// Navigation map. Session-flow screens (camera/live) lock to landscape;
/// everything else is portrait.
library;

import 'package:go_router/go_router.dart';

import '../features/chat/chat_screen.dart';
import '../features/home/home_screen.dart';
import '../features/live_session/camera_setup_screen.dart';
import '../features/live_session/live_screen.dart';
import '../features/onboarding/first_launch_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/session_setup/setup_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/summary/summary_screen.dart';
import '../shared/widgets/app_shell.dart';

GoRouter buildRouter({required bool showOnboarding}) => GoRouter(
      initialLocation: showOnboarding ? '/onboarding' : '/home',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const FirstLaunchScreen(),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/home',
                  builder: (context, state) => const HomeScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/progress',
                  builder: (context, state) => const ProgressScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/profile',
                  builder: (context, state) => const SettingsScreen()),
            ]),
          ],
        ),
        GoRoute(
            path: '/setup', builder: (context, state) => const SetupScreen()),
        GoRoute(
            path: '/camera',
            builder: (context, state) => const CameraSetupScreen()),
        GoRoute(
            path: '/live', builder: (context, state) => const LiveScreen()),
        GoRoute(
          path: '/summary/:id',
          builder: (context, state) => SummaryScreen(
              sessionId: int.parse(state.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/chat/:id',
          builder: (context, state) =>
              ChatScreen(sessionId: int.parse(state.pathParameters['id']!)),
        ),
      ],
    );
