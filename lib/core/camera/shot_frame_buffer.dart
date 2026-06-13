/// Rolling ring buffer that retains recent camera thumbnails for shot
/// validation (SPEC §3 extension). Each entry is a 96×96 packed RGB image
/// (27,648 bytes) keyed by the camera timestamp that produced it.
///
/// The buffer is cheap: 3 seconds of frames at 24 fps = 72 entries = ~2 MB.
/// Entries older than [capacity] are silently dropped so the buffer never
/// grows beyond its budget.
///
/// Frame lookup is O(n) but n ≤ [capacity] and the buffer is only queried
/// once per detected shot, so this is never on a hot path.
library;

import 'dart:typed_data';

/// Width and height of the stored thumbnails.
const int kThumbnailSize = 96;

class ShotFrameBuffer {
  ShotFrameBuffer({this.capacity = 150});

  final int capacity;

  // Parallel lists so we can scan timestamps cheaply without boxing.
  final List<int> _timestamps = [];
  final List<Uint8List> _frames = [];

  /// Stores a 96×96 packed-RGB [thumbnail] for [timestampMs].
  void store(int timestampMs, Uint8List thumbnail) {
    _timestamps.add(timestampMs);
    _frames.add(thumbnail);
    if (_timestamps.length > capacity) {
      _timestamps.removeAt(0);
      _frames.removeAt(0);
    }
  }

  /// Returns the RGB thumbnail whose timestamp is closest to [timestampMs],
  /// or null when the buffer is empty or the nearest entry is further than
  /// [maxGapMs] milliseconds away (which means the shot predates our buffer).
  Uint8List? frameAt(int timestampMs, {int maxGapMs = 800}) {
    if (_timestamps.isEmpty) return null;
    var bestIdx = 0;
    var bestDiff = (_timestamps[0] - timestampMs).abs();
    for (var i = 1; i < _timestamps.length; i++) {
      final diff = (_timestamps[i] - timestampMs).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestIdx = i;
      }
    }
    return bestDiff <= maxGapMs ? _frames[bestIdx] : null;
  }

  void clear() {
    _timestamps.clear();
    _frames.clear();
  }
}
