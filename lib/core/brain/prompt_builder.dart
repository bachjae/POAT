/// Prompt assembly for the Coach Brain (SPEC §9).
///
/// Templates live in `assets/prompts/*.txt` with `{placeholder}` slots; this
/// class is the only place they are filled, and it throws if any slot is
/// left unfilled so a template/code drift fails loudly at render time.
library;

import '../engine/engine_types.dart';

/// Template keys expected in the constructor map (= asset base names).
const String kShotCueTemplate = 'shot_cue';
const String kShotCueServeTemplate = 'shot_cue_serve';
const String kShotCueBackhandTemplate = 'shot_cue_backhand';
const String kShotCueVolleyTemplate = 'shot_cue_volley';
const String kSessionSummaryTemplate = 'session_summary';
const String kChatSystemTemplate = 'chat_system';

/// Unfilled `{placeholder}` token — lowercase ids, so JSON payloads (whose
/// keys are always quoted) never false-positive.
final RegExp _kUnfilledSlot = RegExp(r'\{[a-z_]+\}');

/// Fills the three coach templates with engine data.
class PromptBuilder {
  PromptBuilder({required Map<String, String> templates})
      : _templates = Map.unmodifiable(templates);

  /// Loads the three required templates and any optional stroke-specific
  /// overrides through an injected asset reader
  /// (production: `rootBundle.loadString`; tests: `dart:io`).
  static Future<PromptBuilder> load(
      Future<String> Function(String) loadAsset) async {
    Future<String?> tryLoad(String path) async {
      try {
        return await loadAsset(path);
      } catch (_) {
        return null;
      }
    }

    final templates = <String, String>{
      kShotCueTemplate: await loadAsset('assets/prompts/shot_cue.txt'),
      kSessionSummaryTemplate:
          await loadAsset('assets/prompts/session_summary.txt'),
      kChatSystemTemplate: await loadAsset('assets/prompts/chat_system.txt'),
    };
    final serve = await tryLoad('assets/prompts/shot_cue_serve.txt');
    final backhand = await tryLoad('assets/prompts/shot_cue_backhand.txt');
    final volley = await tryLoad('assets/prompts/shot_cue_volley.txt');
    if (serve != null) templates[kShotCueServeTemplate] = serve;
    if (backhand != null) templates[kShotCueBackhandTemplate] = backhand;
    if (volley != null) templates[kShotCueVolleyTemplate] = volley;
    return PromptBuilder(templates: templates);
  }

  final Map<String, String> _templates;

  /// Live shot-cue prompt. [recurrence]: metric id → occurrences in the
  /// last 10 shots; [trend]: average score delta over the last 10 shots.
  /// Selects a stroke-specific template when available, falling back to the
  /// generic template. [classificationConf] and [viewConfidence] are injected
  /// into stroke-specific templates that expose those slots.
  /// [sessionFocus] and [goalMetric] add context lines when non-null.
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
    double classificationConf = 1.0,
    double viewConfidence = 1.0,
    double racquetConfidence = 1.0,
    String? sessionFocus,
    String? goalMetric,
  }) {
    return _render(_strokeTemplateKey(stroke), {
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
      'classification_conf': classificationConf.toStringAsFixed(2),
      'view_confidence': viewConfidence.toStringAsFixed(2),
      'session_focus':
          sessionFocus != null ? ' Session focus: $sessionFocus.' : '',
      'goal_metric': goalMetric != null ? ' Goal: $goalMetric.' : '',
      // The racquet tracker couldn't confirm a racquet swing — tell the coach
      // to stay gentle and general rather than confidently coaching a non-shot.
      'racquet_note': racquetConfidence < 0.5
          ? ' Racquet confidence is low — you may not have a clear racquet in '
              'view, so keep the cue gentle and general.'
          : '',
    });
  }

  /// Returns the best available template key for [stroke].
  String _strokeTemplateKey(String stroke) {
    final key = switch (stroke) {
      'serve' => kShotCueServeTemplate,
      'backhand' => kShotCueBackhandTemplate,
      'volley' => kShotCueVolleyTemplate,
      _ => null,
    };
    if (key != null && (_templates[key]?.isNotEmpty ?? false)) return key;
    return kShotCueTemplate;
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
