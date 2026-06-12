/// Deterministic "Ask your coach" for Lite mode (SPEC §9 fallback tier).
///
/// When the Gemma Coach Brain is absent (no bundled chunks or the RAM gate
/// failed), chat used to dead-end with an apology. This rule-based coach
/// answers the same grounded questions straight from the stored session
/// row and the drill catalog: overall recap, strengths, what to work on,
/// why a metric matters, and which drill fixes it. Every sentence is
/// derived from measured data — nothing is invented, same contract as the
/// validated LLM path.
library;

import 'dart:async';

import '../session/summary_generator.dart';
import 'coach_chat.dart';

/// Why each metric matters and how to feel the fix — coaching-literature
/// phrasing, mirrored from the cue lexicon's vocabulary.
const Map<String, ({String why, String fix})> _metricKnowledge = {
  'shoulder_turn': (
    why: 'Your shoulder turn is the engine of the swing — it stores the '
        'energy your arm releases at contact. Without a full turn you end '
        'up arming the ball and losing both pace and consistency.',
    fix: 'Start the turn as the ball leaves the opponent\'s strings, not '
        'when it bounces. Chest to the side fence before the bounce.',
  ),
  'knee_flexion': (
    why: 'Knee bend sets your base. Power travels from the ground up — '
        'stiff legs mean the arm has to do everything, and your contact '
        'height becomes hostage to the bounce.',
    fix: 'Sit into an athletic squat between shots and drive up through '
        'contact. Think "load the legs, not the arm".',
  ),
  'trunk_tilt': (
    why: 'A tilted trunk pulls your head — and your eyes — off the ball, '
        'and balance leaks turn into mishits. Staying tall through contact '
        'keeps the swing path repeatable.',
    fix: 'Keep your chin level and finish with your chest facing the '
        'target, not the sky or the ground.',
  ),
  'elbow_angle': (
    why: 'Arm shape controls your contact distance. A cramped elbow drags '
        'contact into your body; an overextended one costs control and '
        'stresses the joint.',
    fix: 'Let the arm relax into its natural hitting shape and meet the '
        'ball a comfortable arm\'s length away.',
  ),
  'hip_shoulder_sep': (
    why: 'The hip–shoulder coil (the "X-factor") is where effortless pace '
        'comes from: hips fire first, shoulders follow, and the racquet '
        'whips through. Without separation you push instead of snap.',
    fix: 'Turn the shoulders past the hips on the takeback, then let the '
        'hips lead the way back to the ball.',
  ),
  'contact_in_front': (
    why: 'Contact out in front lets you see the ball, transfer weight into '
        'the shot, and control direction. Late contact means the ball '
        'plays you.',
    fix: 'Meet the ball earlier — imagine catching it at the peak of your '
        'front foot, not beside your hip.',
  ),
  'contact_height': (
    why: 'Striking in your power zone — roughly waist height — is where '
        'your swing is grooved. Reaching high or digging low changes the '
        'geometry of every shot.',
    fix: 'Move your feet to the ball so the ball arrives in your zone, '
        'instead of adjusting your swing to a bad position.',
  ),
  'wrist_finish_height': (
    why: 'The follow-through is the receipt for everything before it: a '
        'high finish proves you accelerated through the ball instead of '
        'decelerating into it.',
    fix: 'Finish with the racquet over your opposite shoulder and hold it '
        'for a beat — if you can\'t hold the finish, you weren\'t balanced.',
  ),
  'prep_before_contact_ms': (
    why: 'Early preparation buys you time, and time is what separates '
        'clean contact from scrambling. Late racquet prep cascades into '
        'late contact and rushed footwork.',
    fix: 'Racquet back before the bounce on your side, every time. Say '
        '"turn" to yourself as the ball crosses the net.',
  ),
  'split_step_rate': (
    why: 'The split step is your trigger for explosive first movement — '
        'landing just as your opponent strikes lets you push off in any '
        'direction instantly.',
    fix: 'Hop softly as the opponent (or the machine) hits, landing on the '
        'balls of your feet, every single ball.',
  ),
  'stance_width': (
    why: 'A wide base keeps you balanced through contact and lets you load '
        'the outside leg. A narrow stance tips over the moment you swing '
        'hard.',
    fix: 'Set your feet wider than your shoulders before the swing starts '
        '— wide enough that a push couldn\'t topple you.',
  ),
  'recovery_steps': (
    why: 'Recovery footwork decides whether you hit ONE good shot or builds '
        'a whole point. Watching your shot instead of recovering concedes '
        'the court.',
    fix: 'The shot isn\'t over at contact: two quick shuffles back toward '
        'the middle before the ball crosses the net.',
  ),
};

/// The session facts the lite coach is allowed to talk about — exactly the
/// stored summary row, mirroring what the LLM path receives as JSON.
class LiteSessionFacts {
  const LiteSessionFacts({
    required this.type,
    required this.score,
    required this.shots,
    required this.durationMin,
    required this.skillTier,
    required this.strengths,
    required this.improvements,
  });

  /// Stroke id or 'full'.
  final String type;
  final int score;
  final int shots;
  final int durationMin;
  final String skillTier;

  /// 'What worked' strings, e.g. 'Contact out in front 81%'.
  final List<String> strengths;

  /// Work-on items: title/detail are display strings, deviationId keys the
  /// knowledge and drill tables.
  final List<({String title, String detail, String deviationId})> improvements;
}

/// Streams deterministic, session-grounded coach answers. Same `ask`
/// shape as [CoachChat] so the chat screen swaps between them freely.
class LiteCoachChat {
  LiteCoachChat({
    required this.coachName,
    required this.facts,
    required this.catalog,
    this.tokenDelay = const Duration(milliseconds: 18),
  });

  final String coachName;
  final LiteSessionFacts facts;
  final DrillCatalog catalog;

  /// Per-word delay for the typing effect (zero in tests).
  final Duration tokenDelay;

  Stream<String> ask(String question, List<ChatMessage> priorMessages) async* {
    final words = answer(question).split(' ');
    for (var i = 0; i < words.length; i++) {
      if (tokenDelay > Duration.zero) {
        await Future<void>.delayed(tokenDelay);
      }
      yield i == 0 ? words[i] : ' ${words[i]}';
    }
  }

  /// The full deterministic reply (exposed for tests).
  String answer(String question) {
    final q = question.toLowerCase();
    final metric = _metricIn(q);

    if (_mentionsAny(q, ['drill', 'practice', 'practise', 'exercise', 'train'])) {
      return _drillAnswer(metric);
    }
    if (metric != null && _mentionsAny(q, ['why', 'matter', 'important'])) {
      return _whyAnswer(metric);
    }
    if (metric != null) return _metricStatusAnswer(metric);
    if (_mentionsAny(q, ['work on', 'next', 'improve', 'focus', 'fix', 'better'])) {
      return _workOnAnswer();
    }
    if (_mentionsAny(q, ['strength', 'worked', 'well', 'good at', 'best'])) {
      return _strengthsAnswer();
    }
    if (_mentionsAny(q, ['overall', 'how did i do', 'score', 'summary', 'recap'])) {
      return _overallAnswer();
    }
    if (_mentionsAny(q, ['thank', 'thanks'])) {
      return 'Anytime. Rest up — the next session is where this work pays off.';
    }
    return '${_overallAnswer()} Ask me about your score, what worked, what '
        'to work on, why a habit matters, or which drill fixes it.';
  }

  bool _mentionsAny(String q, List<String> needles) =>
      needles.any(q.contains);

  /// Finds a known metric referenced by label, title or spaced id.
  String? _metricIn(String q) {
    for (final id in _metricKnowledge.keys) {
      final candidates = {
        id.replaceAll('_', ' '),
        metricLabels[id]?.toLowerCase(),
        _shortName(id),
      };
      for (final c in candidates) {
        if (c != null && c.isNotEmpty && q.contains(c)) return id;
      }
    }
    return null;
  }

  static String? _shortName(String id) => switch (id) {
        'knee_flexion' => 'knee',
        'shoulder_turn' => 'shoulder',
        'elbow_angle' => 'elbow',
        'trunk_tilt' => 'balance',
        'hip_shoulder_sep' => 'coil',
        'wrist_finish_height' => 'finish',
        'contact_in_front' => 'contact point',
        'split_step_rate' => 'split step',
        'prep_before_contact_ms' => 'preparation',
        'stance_width' => 'stance',
        'recovery_steps' => 'recovery',
        _ => null,
      };

  String _sessionLabel() =>
      facts.type == 'full' ? 'session' : '${facts.type} session';

  String _overallAnswer() {
    if (facts.shots == 0) {
      return 'I didn\'t register any shots this ${_sessionLabel()}, so '
          'there\'s nothing to score yet. Check the camera can see your '
          'whole body side-on and go again.';
    }
    final b = StringBuffer(
        'You hit ${facts.shots} ${facts.type == 'footwork' ? 'windows' : 'shots'} '
        'over ${facts.durationMin} minutes and scored ${facts.score} overall '
        'at the ${facts.skillTier} level.');
    if (facts.strengths.isNotEmpty) {
      b.write(' Best habit: ${facts.strengths.first}.');
    }
    if (facts.improvements.isNotEmpty) {
      b.write(' Biggest opportunity: '
          '${facts.improvements.first.title.toLowerCase()} — '
          '${facts.improvements.first.detail}.');
    }
    return b.toString();
  }

  String _strengthsAnswer() {
    if (facts.strengths.isEmpty) {
      return 'No single habit stayed consistent enough to call a strength '
          'this ${_sessionLabel()} — that usually just means low shot '
          'volume. More balls, and the pattern will show.';
    }
    final items = facts.strengths.map((s) => '$s of shots in range').join('; ');
    return 'What held up best: $items. Those numbers are the in-range rate '
        '— keep feeding them volume so they stay automatic under pressure.';
  }

  String _workOnAnswer() {
    if (facts.improvements.isEmpty) {
      return 'Nothing recurring stood out to fix this ${_sessionLabel()} — '
          'a clean session. Next time, add intensity and see what holds.';
    }
    final b = StringBuffer('Priorities from this ${_sessionLabel()}: ');
    for (var i = 0; i < facts.improvements.length; i++) {
      final imp = facts.improvements[i];
      b.write('${i + 1}. ${imp.title} (${imp.detail}). ');
    }
    final top = facts.improvements.first;
    final tip = _metricKnowledge[top.deviationId]?.fix;
    if (tip != null) b.write('Start with ${top.title.toLowerCase()}: $tip');
    return b.toString().trimRight();
  }

  String _whyAnswer(String metricId) {
    final know = _metricKnowledge[metricId];
    if (know == null) return _workOnAnswer();
    final b = StringBuffer(know.why);
    final imp = _improvementFor(metricId);
    if (imp != null) {
      b.write(' This session it showed up as ${imp.detail}.');
    }
    b.write(' ${know.fix}');
    return b.toString();
  }

  String _metricStatusAnswer(String metricId) {
    final know = _metricKnowledge[metricId];
    final label = metricLabels[metricId] ?? metricId.replaceAll('_', ' ');
    final imp = _improvementFor(metricId);
    final strength = facts.strengths
        .where((s) => s.toLowerCase().startsWith(label.toLowerCase()))
        .firstOrNull;
    final b = StringBuffer();
    if (imp != null) {
      b.write('$label was your flag this ${_sessionLabel()}: ${imp.detail}.');
    } else if (strength != null) {
      b.write('$label held up well this ${_sessionLabel()} — $strength of '
          'shots in range.');
    } else {
      b.write('$label didn\'t stand out either way this ${_sessionLabel()}.');
    }
    if (know != null) b.write(' ${know.fix}');
    final drill = catalog.forDeviations([metricId]).firstOrNull;
    if (drill != null && imp != null) {
      b.write(' Try the ${drill.title} (${drill.minutes} min): '
          '${drill.description}');
    }
    return b.toString();
  }

  String _drillAnswer(String? metricId) {
    final targets = metricId != null
        ? [metricId]
        : [for (final i in facts.improvements) i.deviationId];
    final drills = catalog.forDeviations(targets).take(2).toList();
    if (drills.isEmpty) {
      return 'No specific drill stands out from this ${_sessionLabel()} — '
          'nothing recurring needs fixing. Play points and keep the habits '
          'honest.';
    }
    final b = StringBuffer('From this ${_sessionLabel()} I\'d run: ');
    for (final d in drills) {
      b.write('${d.title}, ${d.minutes} min — ${d.description} ');
    }
    return b.toString().trimRight();
  }

  ({String title, String detail, String deviationId})? _improvementFor(
          String metricId) =>
      facts.improvements
          .where((i) => i.deviationId == metricId)
          .firstOrNull;
}
