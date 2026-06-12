/// New session (DESIGN 2.2): drill grid + coach picker + camera CTA.
/// Phase 3: multi-stroke ordering (numbered badges) + session goal picker.
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

const _singleOnly = {'full', 'footwork'};

/// Common metric IDs available as session goals.
const _goalMetrics = [
  ('shoulder_turn', 'Shoulder Turn'),
  ('knee_flexion', 'Knee Flexion'),
  ('trunk_tilt', 'Trunk Tilt'),
  ('elbow_angle', 'Elbow Angle'),
  ('hip_shoulder_sep', 'Hip-Shoulder Sep'),
  ('contact_in_front', 'Contact In Front'),
  ('contact_height', 'Contact Height'),
  ('wrist_finish_height', 'Wrist Finish'),
  ('prep_before_contact_ms', 'Early Prep'),
  ('split_step_rate', 'Split Step'),
  ('recovery_steps', 'Recovery Steps'),
];

class SetupScreen extends ConsumerWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(sessionDraftProvider);
    final notifier = ref.read(sessionDraftProvider.notifier);
    final seq = draft.strokeSequence;
    final isMulti = seq.length > 1;

    return Scaffold(
      appBar: AppBar(title: const Text('NEW SESSION')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(RcDims.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('WHAT ARE WE WORKING ON?', style: RcType.heading),
              if (isMulti)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  child: Text(
                    'Tap strokes to reorder (${seq.length}/3)',
                    style: RcType.caption,
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.4,
                  children: [
                    for (final (id, label) in _drills)
                      _StrokeTile(
                        id: id,
                        label: label,
                        draft: draft,
                        onTap: () => notifier.toggleStroke(id),
                      ),
                  ],
                ),
              ),
              const Hairline(),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              const Hairline(),
              const SizedBox(height: 12),
              const Text('SESSION GOAL', style: RcType.caption),
              const SizedBox(height: 8),
              _GoalChip(draft: draft, notifier: notifier),
              const SizedBox(height: 20),
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

class _StrokeTile extends StatelessWidget {
  const _StrokeTile({
    required this.id,
    required this.label,
    required this.draft,
    required this.onTap,
  });

  final String id;
  final String label;
  final SessionDraft draft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final seq = draft.strokeSequence;
    final seqIdx = seq.indexOf(id);
    final inSeq = seqIdx >= 0;
    final isSingle = _singleOnly.contains(id);
    final selected = isSingle
        ? (seq.isEmpty && draft.type == id)
        : inSeq;

    return Stack(
      children: [
        RcSelectTile(label: label, selected: selected, onTap: onTap),
        if (inSeq && seq.length > 1)
          Positioned(
            top: 6,
            right: 8,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: RcColors.ball,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${seqIdx + 1}',
                style: RcType.stat
                    .copyWith(fontSize: 11, color: RcColors.ballText),
              ),
            ),
          ),
      ],
    );
  }
}

class _GoalChip extends ConsumerWidget {
  const _GoalChip({required this.draft, required this.notifier});

  final SessionDraft draft;
  final SessionDraftNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalId = draft.goalMetricId;
    final label = goalId == null
        ? 'No goal — tap to set'
        : _goalMetrics
            .firstWhere((m) => m.$1 == goalId,
                orElse: () => (goalId, goalId))
            .$2;

    return InkWell(
      onTap: () => _showPicker(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
              color: goalId != null ? RcColors.ball : RcColors.net),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: RcType.body.copyWith(
                    color: goalId != null ? RcColors.ballText : RcColors.net),
              ),
            ),
            if (goalId != null)
              GestureDetector(
                onTap: () => notifier.setGoalMetricId(null),
                child: const Icon(Icons.close, size: 16, color: RcColors.net),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RcColors.court,
        title: const Text('Set session goal', style: RcType.heading),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final (id, name) in _goalMetrics)
                ListTile(
                  dense: true,
                  title: Text(name, style: RcType.body),
                  trailing: draft.goalMetricId == id
                      ? const Icon(Icons.check, color: RcColors.ball, size: 16)
                      : null,
                  onTap: () => Navigator.pop(ctx, id),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selected != null) notifier.setGoalMetricId(selected);
  }
}
