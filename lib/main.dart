import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'core/brain/model_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: RallyCoachApp()));
}

class RallyCoachApp extends ConsumerWidget {
  const RallyCoachApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brainStatus = ref.watch(brainStatusProvider);
    return brainStatus.when(
      loading: () => MaterialApp(
        theme: buildRallyCoachTheme(),
        debugShowCheckedModeBanner: false,
        home: const _Splash(),
      ),
      error: (_, _) => _app(showOnboarding: false),
      data: (status) =>
          // The one-time "meet your coach" screen runs until the bundled
          // model is reassembled (or confirms Lite mode when not bundled).
          _app(showOnboarding: status != BrainStatus.ready),
    );
  }

  Widget _app({required bool showOnboarding}) => MaterialApp.router(
        title: 'RallyCoach',
        theme: buildRallyCoachTheme(),
        debugShowCheckedModeBanner: false,
        routerConfig: buildRouter(showOnboarding: showOnboarding),
      );
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Text('RALLYCOACH', style: RcType.title),
        ),
      );
}
