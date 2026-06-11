import 'package:flutter_test/flutter_test.dart';

import 'package:rallycoach/core/session/calibration.dart';

void main() {
  test('tier boundaries', () {
    expect(skillTierForScores([44.9]), 'beginner');
    expect(skillTierForScores([45.0]), 'intermediate');
    expect(skillTierForScores([70.0]), 'intermediate');
    expect(skillTierForScores([70.1]), 'advanced');
  });

  test('odd count uses the middle value', () {
    // Sorted: [10, 50, 90] -> median 50.
    expect(skillTierForScores([90, 10, 50]), 'intermediate');
    // One outlier cannot drag the tier down.
    expect(skillTierForScores([0, 80, 85]), 'advanced');
  });

  test('even count uses the mean of the middle two', () {
    // Sorted: [40, 44, 46, 90] -> (44 + 46) / 2 = 45.
    expect(skillTierForScores([90, 40, 46, 44]), 'intermediate');
    // Sorted: [10, 40, 44, 90] -> 42 -> beginner.
    expect(skillTierForScores([44, 90, 10, 40]), 'beginner');
    // Sorted middle two 70, 72 -> 71 -> advanced.
    expect(skillTierForScores([50, 70, 72, 95]), 'advanced');
  });

  test('empty list defaults to beginner', () {
    expect(skillTierForScores([]), 'beginner');
  });

  test('typical ten-shot calibration', () {
    final scores = [38.0, 42.0, 51.0, 47.0, 55.0, 44.0, 49.0, 52.0, 46.0, 41.0];
    // Sorted middle two are 46 and 47 -> 46.5.
    expect(skillTierForScores(scores), 'intermediate');
  });
}
