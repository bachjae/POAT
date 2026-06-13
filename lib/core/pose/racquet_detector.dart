/// Optical racquet-detector seam (SPEC §5a upgrade path).
///
/// The racquet metrics run today from a forearm-extension estimate in
/// `lib/core/engine/racquet.dart`. This interface is the drop-in point for an
/// optical racquet-keypoint model (e.g. a TFLite detector bundled via
/// `tool/fetch_models.sh --racquet`): an implementation returns the racquet's
/// `[handle, throat, tip]` in the SAME image-space coordinates as the MoveNet
/// [PoseFrame], plus a 0..1 presence score. The pose pipeline normalizes those
/// points alongside the body (hip-mid origin, torso scale, y-up) and passes
/// them to `racquetPose(..., detected:)` and
/// `racquetConfidence(..., detectedPresence:)`, at which point every racquet
/// metric and the presence gate become *measured* rather than estimated — no
/// downstream change required.
library;

import '../engine/engine_types.dart';

/// A detected racquet for one camera frame.
class RacquetObservation {
  const RacquetObservation({
    required this.handle,
    required this.throat,
    required this.tip,
    required this.presence,
  });

  /// Image-space `[x, y]` points in the PoseFrame's coordinate space (the
  /// pipeline normalizes them to torso units before the engine sees them).
  final List<double> handle;
  final List<double> throat;
  final List<double> tip;

  /// 0..1 confidence that a racquet is actually present in this frame.
  final double presence;
}

/// Detects the racquet in a pose frame. Returns null when no racquet is found
/// (or for the no-op default), which leaves the engine on the
/// forearm-extension estimate.
abstract interface class RacquetDetector {
  RacquetObservation? detect(PoseFrame frame);
}

/// Default: no optical model bundled — the engine estimates the racquet from
/// the forearm. Swap in a TFLite-backed detector to upgrade in place.
class NoRacquetDetector implements RacquetDetector {
  const NoRacquetDetector();

  @override
  RacquetObservation? detect(PoseFrame frame) => null;
}
