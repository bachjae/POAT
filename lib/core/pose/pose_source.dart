/// Pose frame sources.
///
/// The engine and session flow consume an abstract stream of [PoseFrame]s so
/// the whole pipeline is testable without a camera: [FixturePoseSource]
/// replays recorded/synthetic keypoint sequences; the production
/// CameraPoseSource (lib/core/camera/) runs MoveNet on live frames.
library;

import 'dart:async';

import '../engine/engine_types.dart';

abstract class PoseSource {
  Stream<PoseFrame> get frames;

  Future<void> start();

  Future<void> stop();
}

/// Replays a recorded keypoint sequence. With [realtime] false the frames are
/// emitted as fast as the listener consumes them (test mode); true paces them
/// by their timestamps.
class FixturePoseSource implements PoseSource {
  FixturePoseSource(this._frames, {this.realtime = false, this.loop = false});

  final List<PoseFrame> _frames;
  final bool realtime;
  final bool loop;

  final _controller = StreamController<PoseFrame>.broadcast();
  bool _running = false;

  @override
  Stream<PoseFrame> get frames => _controller.stream;

  @override
  Future<void> start() async {
    _running = true;
    unawaited(_pump());
  }

  Future<void> _pump() async {
    var epoch = 0;
    do {
      int? prevTs;
      for (final f in _frames) {
        if (!_running) return;
        if (realtime && prevTs != null) {
          await Future<void>.delayed(
              Duration(milliseconds: f.timestampMs - prevTs));
        } else {
          // Yield control so listeners process frame-by-frame.
          await Future<void>.delayed(Duration.zero);
        }
        prevTs = f.timestampMs;
        _controller.add(PoseFrame(
          timestampMs: f.timestampMs + epoch,
          keypoints: f.keypoints,
        ));
      }
      epoch += _frames.isEmpty ? 0 : _frames.last.timestampMs + 33;
    } while (loop && _running);
    if (!loop) await _controller.close();
  }

  @override
  Future<void> stop() async {
    _running = false;
  }
}
