/// Skill-tier calibration from the ten-shot warm-up (SPEC §12).
///
/// The median is used instead of the mean so one fluffed or lucky shot
/// cannot move the player a whole tier.
library;

/// Maps calibration shot scores to 'beginner' (<45), 'intermediate'
/// (45–70 inclusive) or 'advanced' (>70) by median score. An empty list
/// (no shots detected) defaults to 'beginner'.
String skillTierForScores(List<double> tenShotScores) {
  if (tenShotScores.isEmpty) return 'beginner';
  final sorted = [...tenShotScores]..sort();
  final n = sorted.length;
  final median = n.isOdd
      ? sorted[n ~/ 2]
      : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
  if (median < 45) return 'beginner';
  if (median <= 70) return 'intermediate';
  return 'advanced';
}
