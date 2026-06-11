/// New session (DESIGN 2.2): drill grid + coach picker + camera CTA.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../shared/widgets/rc_widgets.dart';

const _drills = [
  ('full', 'Full analysis'),
  ('forehand', 'Forehand'),
  ('backhand', 'Backhand'),
  ('serve', 'Serve'),
  ('volley', 'Volley'),
  ('footwork', 'Footwork'),
];

class SetupScreen extends ConsumerWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(sessionDraftProvider);
    final notifier = ref.read(sessionDraftProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('NEW SESSION')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(RcDims.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('WHAT ARE WE WORKING ON?', style: RcType.heading),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.4,
                  children: [
                    for (final (id, label) in _drills)
                      RcSelectTile(
                        label: label,
                        selected: draft.type == id,
                        onTap: () => notifier.setType(id),
                      ),
                  ],
                ),
              ),
              const Hairline(),
              const SizedBox(height: 16),
              const Text('YOUR COACH', style: RcType.caption),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final (id, name, tagline) in [
                    ('maya', 'Maya', 'encouraging'),
                    ('coach_k', 'Coach K', 'direct'),
                    ('doc', 'Doc', 'analytic'),
                  ])
                    RcChip(
                      label: name,
                      sublabel: tagline,
                      selected: draft.coachId == id,
                      onTap: () => notifier.setCoach(id),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              RcPrimaryButton(
                label: 'Set up camera →',
                onPressed: () => context.push('/camera'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
