/// One-Euro pose smoothing: jitter suppression, low-confidence holds,
/// and reset-on-gap behavior.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rallycoach/core/engine/engine_types.dart';
import 'package:rallycoach/core/pose/pose_smoother.dart';

PoseFrame frame(int t, double x, double y, [double conf = 0.9]) => PoseFrame(
      timestampMs: t,
      keypoints: [
        for (var i = 0; i < Kp.count; i++) [x, y, conf],
      ],
    );

void main() {
  test('suppresses static jitter well below its raw amplitude', () {
    final smoother = PoseSmoother();
    PoseFrame? out;
    for (var i = 0; i < 40; i++) {
      final jitter = i.isEven ? 3.0 : -3.0;
      out = smoother.smooth(frame(i * 33, 100 + jitter, 200 - jitter),
          width: 640, height: 480);
    }
    final wrist = out!.keypoints[Kp.rightWrist];
    expect((wrist[0] - 100).abs(), lessThan(1.0));
    expect((wrist[1] - 200).abs(), lessThan(1.0));
  });

  test('tracks fast motion with little lag', () {
    final smoother = PoseSmoother();
    PoseFrame? out;
    // 25 px/frame ≈ 750 px/s — swing-speed motion must pass through.
    for (var i = 0; i < 30; i++) {
      out = smoother.smooth(frame(i * 33, 100.0 + i * 25, 200),
          width: 640, height: 480);
    }
    final wrist = out!.keypoints[Kp.rightWrist];
    final target = 100.0 + 29 * 25;
    expect((wrist[0] - target).abs(), lessThan(25.0),
        reason: 'lag must stay under one frame of motion');
  });

  test('holds the last good position through a brief low-confidence dip',
      () {
    final smoother = PoseSmoother();
    for (var i = 0; i < 10; i++) {
      smoother.smooth(frame(i * 33, 100, 200), width: 640, height: 480);
    }
    final held = smoother.smooth(frame(330, 500, 500, 0.05),
        width: 640, height: 480);
    final wrist = held.keypoints[Kp.rightWrist];
    expect(wrist[0], closeTo(100, 0.5), reason: 'position held');
    expect(wrist[1], closeTo(200, 0.5));
    expect(wrist[2], 0.05, reason: 'raw confidence passes through');
  });

  test('resets after a long frame gap instead of dragging from stale state',
      () {
    final smoother = PoseSmoother();
    for (var i = 0; i < 10; i++) {
      smoother.smooth(frame(i * 33, 100, 100), width: 640, height: 480);
    }
    final out = smoother.smooth(frame(10 * 33 + 2000, 500, 400),
        width: 640, height: 480);
    final wrist = out.keypoints[Kp.rightWrist];
    expect(wrist[0], 500.0);
    expect(wrist[1], 400.0);
  });
}
