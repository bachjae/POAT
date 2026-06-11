/// Prompt assembly for the Coach Brain (SPEC §9).
///
/// Templates live in `assets/prompts/*.txt` with `{placeholder}` slots; this
/// class is the only place they are filled, and it throws if any slot is
/// left unfilled so a template/code drift fails loudly at render time.
library;

import '../engine/engine_types.dart';

/// Template keys expected in the constructor map (= asset base names).
const String kShotCueTemplate = 'shot_cue';
const String kSessionSummaryTemplate = 'session_summary';
const String kChatSystemTemplate = 'chat_system';

/// Unfilled `{placeholder}` token — lowercase ids, so JSON payloads (whose
/// keys are always quoted) never false-positive.
final RegExp _kUnfilledSlot = RegExp(r'\{[a-z_]+\}');

/// Fills the three coach templates with engine data.
class PromptBuilder {
  PromptBuilder({required Map<String, String> templates})
      : _templates = Map.unmodifiable(templates);

  /// Loads the three templates through an injected asset reader
  /// (production: `rootBundle.loadString`; tests: `dart:io`).
  static Future<PromptBuilder> load(
      Future<String> Function(String) loadAsset) async {
    return PromptBuilder(templates: {
      kShotCueTemplate: await loadAsset('assets/prompts/shot_cue.txt'),
      kSessionSummaryTemplate:
          await loadAsset('assets/prompts/session_summary.txt'),
      kChatSystemTemplate: await loadAsset('assets/prompts/chat_system.txt'),
    });
  }

  final Map<String, String> _templates;

  /// Live shot-cue prompt. [recurrence]: metric id → occurrences in the
  /// last 10 shots; [trend]: average score delta over the last 10 shots.
  String shotCue({
    required String personalityName,
    required String personalityStyle,
    required String skillTier,
    required String handedness,
    required String sessionType,
    required String stroke,
    required int score,
    required List<MetricDeviation> deviations,
    required Map<String, int> recurrence,
    required int shotNumber,
    required double trend,
    required List<String> recentCues,
  }) {
    return _render(kShotCueTemplate, {
      'personality_name': personalityName,
      'personality_style': personalityStyle,
      'skill_tier': skillTier,
      'handedness': handedness,
      'session_type': sessionType,
      'stroke': stroke,
      'score': '$score',
      'deviations': _renderDeviations(deviations, recurrence),
      'shot_number': '$shotNumber',
      'trend': _signed(trend),
      'recent_cues': recentCues.isEmpty ? 'none' : recentCues.join('; '),
    });
  }

  /// Post-session debrief prompt. [recurringDeviations] order is preserved —
  /// the template demands one "work_on" bullet per entry, in order.
  String sessionSummary({
    required String personalityName,
    required String personalityStyle,
    required String sessionType,
    required int durationMin,
    required int shotsTotal,
    required int score,
    required double scoreDelta,
    required Map<String, double> strokeAverages,
    required List<String> strengths,
    required List<({String id, int occurrences, String phase})>
        recurringDeviations,
    required String trendDescription,
  }) {
    return _render(kSessionSummaryTemplate, {
      'personality_name': personalityName,
      'personality_style': personalityStyle,
      'session_type': sessionType,
      'duration_min': '$durationMin',
      'shots_total': '$shotsTotal',
      'score': '$score',
      'score_delta': _signed(scoreDelta),
      'stroke_averages': strokeAverages.isEmpty
          ? 'none'
          : strokeAverages.entries
              .map((e) => '${e.key} ${e.value.toStringAsFixed(1)}')
              .join(', '),
      'strengths': strengths.isEmpty ? 'none' : strengths.join(', '),
      'recurring_deviations': recurringDeviations.isEmpty
          ? 'none'
          : recurringDeviations
              .map((d) => '(${d.id}, ${d.occurrences}, ${d.phase})')
              .join('; '),
      'trend_description': trendDescription,
      'improve_count': '${recurringDeviations.length}',
    });
  }

  /// System prompt for the post-session Q&A chat. [sessionJson] and
  /// [historyJson] are pre-encoded JSON strings.
  String chatSystem({
    required String personalityName,
    required String personalityStyle,
    required String sessionJson,
    required String historyJson,
  }) {
    return _render(kChatSystemTemplate, {
      'personality_name': personalityName,
      'personality_style': personalityStyle,
      'session_json': sessionJson,
      'history_json': historyJson,
    });
  }

  /// One indented line per deviation:
  /// `  id: X.X off ideal lo–hi (direction) (recurring: N of last 10)`.
  static String _renderDeviations(
      List<MetricDeviation> deviations, Map<String, int> recurrence) {
    if (deviations.isEmpty) return '  none';
    return deviations.map((d) {
      final off = d.direction == 'low'
          ? d.ideal.first - d.value
          : d.value - d.ideal.last;
      final lo = d.ideal.first.toStringAsFixed(1);
      final hi = d.ideal.last.toStringAsFixed(1);
      var line =
          '  ${d.id}: ${off.toStringAsFixed(1)} off ideal $lo–$hi (${d.direction})';
      final n = recurrence[d.id] ?? 0;
      if (n > 0) line += ' (recurring: $n of last 10)';
      return line;
    }).join('\n');
  }

  static String _signed(double v) {
    final s = v.toStringAsFixed(1);
    return v >= 0 ? '+$s' : s;
  }

  String _render(String key, Map<String, String> slots) {
    final template = _templates[key];
    if (template == null) throw StateError('Missing template: $key');
    var text = template;
    slots.forEach((slot, value) {
      text = text.replaceAll('{$slot}', value);
    });
    final leftover = _kUnfilledSlot.firstMatch(text);
    if (leftover != null) {
      throw StateError('Unfilled slot ${leftover.group(0)} in $key template');
    }
    return text;
  }
}
