/// Profile / settings (DESIGN 2.9): Coach Brain pane, skill tier,
/// handedness, privacy, delete-all.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/brain/model_manager.dart';
import '../../core/engine/reference_library.dart';
import '../../shared/widgets/rc_widgets.dart';

final _settingProvider = FutureProvider.family<String?, String>(
    (ref, key) => ref.watch(repositoryProvider).getSetting(key));

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brain = ref.watch(brainStatusProvider);
    final tier = ref.watch(_settingProvider('skill_tier'));
    final leftHanded = ref.watch(_settingProvider('left_handed'));

    return Scaffold(
      appBar: AppBar(title: const Text('PROFILE')),
      body: ListView(
        padding: const EdgeInsets.all(RcDims.screenPadding),
        children: [
          const Text('COACH BRAIN', style: RcType.caption),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                  child: Text('Gemma 4 E2B (bundled)', style: RcType.body)),
              brain.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (status) => RcStatusChip(
                  text: switch (status) {
                    BrainStatus.ready => 'Ready',
                    BrainStatus.preparing => 'Preparing',
                    BrainStatus.failed => 'Setup failed',
                    BrainStatus.absent => 'Lite mode',
                  },
                  dotColor: status == BrainStatus.ready
                      ? RcColors.ball
                      : RcColors.net,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'The brain ships inside the app and runs entirely on this '
            'phone. A Pro model (Gemma 4 E4B) can be imported from a file '
            'in a future update.',
            style: RcType.caption,
          ),
          const SizedBox(height: 20),
          const Hairline(),
          const SizedBox(height: 20),
          const Text('COACHING', style: RcType.caption),
          const SizedBox(height: 8),
          tier.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (value) => _TierSelector(current: value),
          ),
          const SizedBox(height: 12),
          leftHanded.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (value) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Left-handed player', style: RcType.body),
              activeTrackColor: RcColors.ball,
              value: value == 'true',
              onChanged: (v) async {
                await ref
                    .read(repositoryProvider)
                    .setSetting('left_handed', '$v');
                ref.invalidate(_settingProvider('left_handed'));
              },
            ),
          ),
          const SizedBox(height: 20),
          const Hairline(),
          const SizedBox(height: 20),
          const Text('PRIVACY', style: RcType.caption),
          const SizedBox(height: 8),
          const Text(
            'RallyCoach has no accounts, no analytics and no network '
            'access — the Android build ships without the INTERNET '
            'permission. Video frames are analyzed in memory and never '
            'written to disk. Only your session summaries are stored, on '
            'this device.',
            style: RcType.body,
          ),
          const SizedBox(height: 20),
          RcOutlineButton(
            label: 'Delete all data',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: RcColors.court,
                  title: const Text('Delete everything?',
                      style: RcType.heading),
                  content: const Text(
                      'All sessions, stats and settings will be wiped from '
                      'this device. There is no cloud copy.',
                      style: RcType.body),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Keep my data')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('Delete',
                            style: RcType.body
                                .copyWith(color: RcColors.clay))),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(repositoryProvider).deleteAllData();
                ref.invalidate(_settingProvider);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _TierSelector extends ConsumerWidget {
  const _TierSelector({this.current});

  final String? current;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
        children: [
          const Expanded(child: Text('Skill level', style: RcType.body)),
          DropdownButton<String>(
            value: current,
            hint: const Text('Auto', style: RcType.bodyDim),
            underline: const SizedBox.shrink(),
            style: RcType.body,
            items: [
              for (final t in ReferenceLibrary.tiers)
                DropdownMenuItem(
                    value: t,
                    child: Text(t[0].toUpperCase() + t.substring(1))),
            ],
            onChanged: (v) async {
              if (v == null) return;
              await ref.read(repositoryProvider).setSetting('skill_tier', v);
              ref.invalidate(_settingProvider('skill_tier'));
            },
          ),
        ],
      );
}
