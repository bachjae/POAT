/// Profile / settings (DESIGN 2.9): Coach Brain pane, skill tier,
/// handedness, privacy, delete-all.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
            'phone.',
            style: RcType.caption,
          ),
          const SizedBox(height: 12),
          _ProModelImporter(),
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
          const SizedBox(height: 12),
          RcOutlineButton(
            label: 'Export session data (CSV)',
            onPressed: () async {
              final csv =
                  await ref.read(repositoryProvider).exportSessionsCsv();
              if (csv.isEmpty) return;
              final dir = await getTemporaryDirectory();
              final file = File('${dir.path}/rallycoach_sessions.csv');
              await file.writeAsString(csv);
              await SharePlus.instance.share(ShareParams(
                files: [XFile(file.path, mimeType: 'text/csv')],
                subject: 'RallyCoach session data',
              ));
            },
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

class _ProModelImporter extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ProModelImporter> createState() => _ProModelImporterState();
}

class _ProModelImporterState extends ConsumerState<_ProModelImporter> {
  double? _progress;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final managerAsync = ref.watch(modelManagerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Pro model (Gemma 4 E4B)', style: RcType.body),
            ),
            managerAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (manager) => FutureBuilder<BrainStatus>(
                future: manager.proStatus,
                builder: (context, snap) => RcStatusChip(
                  text: snap.data == BrainStatus.ready ? 'Ready' : 'Not installed',
                  dotColor: snap.data == BrainStatus.ready
                      ? RcColors.ball
                      : RcColors.net,
                ),
              ),
            ),
          ],
        ),
        if (_progress != null) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _progress,
            color: RcColors.ball,
            backgroundColor: RcColors.net,
          ),
          const SizedBox(height: 4),
          Text('Importing… ${(_progress! * 100).round()}%',
              style: RcType.caption),
        ],
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(_error!, style: RcType.caption.copyWith(color: RcColors.clay)),
        ],
        const SizedBox(height: 8),
        RcOutlineButton(
          label: 'Import Pro model (.litertlm)',
          onPressed: _progress != null
              ? null
              : () async {
                  setState(() {
                    _error = null;
                    _progress = 0;
                  });
                  try {
                    final result = await FilePicker.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['litertlm'],
                    );
                    if (result == null || result.files.single.path == null) {
                      setState(() => _progress = null);
                      return;
                    }
                    final source = File(result.files.single.path!);
                    final manager =
                        await ref.read(modelManagerProvider.future);
                    await for (final p in manager.importProModel(source)) {
                      if (mounted) setState(() => _progress = p);
                    }
                    ref.invalidate(modelManagerProvider);
                    ref.invalidate(brainStatusProvider);
                    ref.invalidate(llmRunnerProvider);
                  } catch (e) {
                    if (mounted) {
                      setState(() {
                        _error = e.toString();
                        _progress = null;
                      });
                    }
                    return;
                  }
                  if (mounted) setState(() => _progress = null);
                },
        ),
      ],
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
