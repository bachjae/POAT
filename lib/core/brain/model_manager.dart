/// Bundled-model lifecycle for the Coach Brain (SPEC §9).
///
/// The Gemma 4 E2B `.litertlm` (2.58 GB) ships INSIDE the APK as flutter
/// assets split into <2 GB chunks (`assets/models/gemma_e2b.chunkN`) plus an
/// optional `gemma_e2b.sha256` digest asset. Chunks may be absent in dev
/// builds — the app then runs in Lite mode (rules only). On first launch
/// [ModelManager.prepare] reassembles the chunks (streamed, never fully in
/// memory) into the app-support dir and verifies the SHA-256.
///
/// There is no network code anywhere in this app, by design.
library;

// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../platform/backup_exclusion.dart';

/// Lifecycle of the on-device model file.
enum BrainStatus {
  /// No usable model file (no chunks bundled, or not yet reassembled).
  absent,

  /// [ModelManager.prepare] is currently reassembling/verifying.
  preparing,

  /// Reassembled file exists and matches the recorded size.
  ready,

  /// Last [ModelManager.prepare] failed (e.g. checksum mismatch).
  failed,
}

/// Reassembled model file name inside the target directory.
const String kModelFileName = 'gemma_e2b.litertlm';

/// Marker written next to the model on successful preparation.
const String kModelMetaFileName = 'gemma_e2b.meta';

/// Pro model (Gemma 4 E4B) file name — imported by the user from a file.
const String kProModelFileName = 'gemma_e4b.litertlm';

/// Marker written next to the pro model on successful import.
const String kProModelMetaFileName = 'gemma_e4b.meta';

/// Gemma 4 E2B needs >= 6 GB devices; below that the app stays Lite.
const int kMinRamBytes = 6 * 1024 * 1024 * 1024;

/// Gemma 4 E4B (Pro) needs >= 8 GB RAM.
const int kMinProRamBytes = 8 * 1024 * 1024 * 1024;

/// Asset key prefix for the bundled chunks (suffix is the chunk index).
const String kChunkAssetPrefix = 'assets/models/gemma_e2b.chunk';

/// Asset key of the bundled hex digest of the reassembled file.
const String kSha256AssetKey = 'assets/models/gemma_e2b.sha256';

/// Upper bound on a single bundled chunk (chunks are split below 2 GB so
/// the asset pipeline and 32-bit size fields never overflow). Also used as
/// the intra-chunk progress denominator.
const int kChunkSizeHint = 2 * 1024 * 1024 * 1024;

/// Reassembles and verifies the bundled Gemma model; gatekeeper for whether
/// the Coach Brain may run at all (Lite mode otherwise).
///
/// All I/O is injected so tests run against temp dirs and in-memory chunks;
/// [ModelManager.production] wires the real Flutter asset bundle.
class ModelManager {
  ModelManager({
    required Future<List<String>> Function() listBundledChunks,
    required Stream<List<int>> Function(String assetKey) openAssetRead,
    required Future<String?> Function() readBundledSha256,
    required Directory targetDir,
    Future<int?> Function()? deviceRamBytes,
  })  : _listBundledChunks = listBundledChunks,
        _openAssetRead = openAssetRead,
        _readBundledSha256 = readBundledSha256,
        _targetDir = targetDir,
        _deviceRamBytes = deviceRamBytes;

  /// Production wiring against the Flutter asset bundle.
  ///
  /// Memory note: `rootBundle.load` is the only public API for reading an
  /// asset, and it materializes the WHOLE asset — there is no streamed asset
  /// read in Flutter. That is exactly why the model is split into <2 GB
  /// chunks: per-chunk peak memory is one chunk (< 2 GB) rather than the
  /// full 2.58 GB model. We process strictly chunk-by-chunk, slice the
  /// buffer into small pieces for the copy/hash pipeline, and explicitly
  /// drop + evict the chunk before loading the next one so at most one
  /// chunk is resident at a time.
  factory ModelManager.production({
    required Directory targetDir,
    Future<int?> Function()? deviceRamBytes,
  }) {
    return ModelManager(
      listBundledChunks: () async {
        final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
        final chunks = manifest
            .listAssets()
            .where((k) => k.startsWith(kChunkAssetPrefix))
            .toList();
        // Numeric sort on the chunkN suffix (lexicographic would misorder
        // chunk10 before chunk2).
        chunks.sort((a, b) {
          final ia = int.parse(a.substring(kChunkAssetPrefix.length));
          final ib = int.parse(b.substring(kChunkAssetPrefix.length));
          return ia.compareTo(ib);
        });
        return chunks;
      },
      openAssetRead: (assetKey) async* {
        // Whole-chunk load is unavoidable (see factory doc); slice it so the
        // IOSink/hash pipeline never copies the full chunk again.
        ByteData? data = await rootBundle.load(assetKey);
        final length = data.lengthInBytes;
        const slice = 8 * 1024 * 1024;
        for (var off = 0; off < length; off += slice) {
          final end = math.min(off + slice, length);
          yield data.buffer.asUint8List(data.offsetInBytes + off, end - off);
        }
        data = null; // Drop our reference before evicting the bundle cache.
        rootBundle.evict(assetKey);
      },
      readBundledSha256: () async {
        try {
          final raw = await rootBundle.loadString(kSha256AssetKey);
          final hex = raw.trim();
          return hex.isEmpty ? null : hex;
        } on FlutterError {
          return null; // Digest asset absent (dev build) — skip verification.
        }
      },
      targetDir: targetDir,
      deviceRamBytes: deviceRamBytes,
    );
  }

  final Future<List<String>> Function() _listBundledChunks;
  final Stream<List<int>> Function(String assetKey) _openAssetRead;
  final Future<String?> Function() _readBundledSha256;
  final Directory _targetDir;
  final Future<int?> Function()? _deviceRamBytes;

  bool _preparing = false;
  bool _failed = false;
  bool _liteOnly = false;

  /// Absolute path of the reassembled bundled (E2B) model file.
  String get modelFilePath => '${_targetDir.path}/$kModelFileName';

  String get _metaFilePath => '${_targetDir.path}/$kModelMetaFileName';

  /// Absolute path of the imported Pro (E4B) model file.
  String get proModelFilePath => '${_targetDir.path}/$kProModelFileName';

  String get _proMetaFilePath => '${_targetDir.path}/$kProModelMetaFileName';

  /// True when the Coach Brain must not run: no model bundled, or the
  /// device has < 6 GB RAM (Gemma 4 E2B requirement). Recomputed by
  /// [status] / [prepare]; query [status] first.
  bool get liteOnly => _liteOnly;

  /// Current lifecycle state. `ready` iff the reassembled file exists and
  /// matches the size recorded in the meta marker; `absent` when no chunks
  /// are bundled or the file has not been materialized yet.
  Future<BrainStatus> get status async {
    final ram = await _deviceRamBytes?.call();
    final ramTooSmall = ram != null && ram < kMinRamBytes;
    if (_preparing) {
      _liteOnly = ramTooSmall;
      return BrainStatus.preparing;
    }
    if (await _markerMatchesFile()) {
      _liteOnly = ramTooSmall;
      return BrainStatus.ready;
    }
    final chunks = await _listBundledChunks();
    if (chunks.isEmpty) {
      _liteOnly = true;
      return BrainStatus.absent;
    }
    _liteOnly = ramTooSmall;
    return _failed ? BrainStatus.failed : BrainStatus.absent;
  }

  /// True when the success marker exists and the model file matches its
  /// recorded size (full re-hash on every launch would cost ~2.6 GB of I/O).
  /// Uses [metaPath]/[modelPath] overrides when provided (for the Pro model).
  Future<bool> _markerMatchesFile([
    String? modelPath,
    String? metaPath,
  ]) async {
    final meta = File(metaPath ?? _metaFilePath);
    final model = File(modelPath ?? modelFilePath);
    if (!await meta.exists() || !await model.exists()) return false;
    try {
      final json = jsonDecode(await meta.readAsString());
      return json is Map<String, dynamic> &&
          json['size'] is int &&
          json['size'] == await model.length();
    } on FormatException {
      return false;
    }
  }

  /// Status of the imported Pro (Gemma 4 E4B) model.
  Future<BrainStatus> get proStatus async {
    if (await _markerMatchesFile(proModelFilePath, _proMetaFilePath)) {
      return BrainStatus.ready;
    }
    return BrainStatus.absent;
  }

  /// Imports [source] as the Pro model (Gemma 4 E4B) into the target dir.
  /// RAM-gated at 8 GB. Emits progress 0..1.
  /// On success writes a `{size, sha256}` meta marker.
  Stream<double> importProModel(File source) async* {
    final ram = await _deviceRamBytes?.call();
    if (ram != null && ram < kMinProRamBytes) {
      throw StateError(
          'Pro model requires at least 8 GB RAM; this device has '
          '${(ram / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB.');
    }
    yield 0.0;
    await _targetDir.create(recursive: true);
    final dest = File(proModelFilePath);
    IOSink? out;
    try {
      out = dest.openWrite();
      final digestOut = _DigestCapture();
      final hashSink = sha256.startChunkedConversion(digestOut);
      final sourceSize = await source.length();
      var written = 0;
      await for (final chunk in source.openRead()) {
        out.add(chunk);
        hashSink.add(chunk);
        written += chunk.length;
        yield sourceSize > 0 ? written / sourceSize : 0.0;
      }
      await out.flush();
      await out.close();
      out = null;
      hashSink.close();
      final actual = digestOut.digest.toString();
      await File(_proMetaFilePath)
          .writeAsString(jsonEncode({'size': written, 'sha256': actual}));
      try {
        await BackupExclusion.excludeFromBackup(proModelFilePath);
      } catch (_) {}
      yield 1.0;
    } catch (_) {
      await out?.close();
      if (await dest.exists()) await dest.delete();
      final meta = File(_proMetaFilePath);
      if (await meta.exists()) await meta.delete();
      rethrow;
    }
  }

  /// Streams the bundled chunks into [modelFilePath], emitting progress
  /// 0..1. SHA-256 is computed incrementally DURING the copy and compared
  /// to the bundled digest (verification is skipped when the digest asset
  /// is absent). On success a meta marker `{size, sha256}` is written.
  ///
  /// Idempotent: when the marker already matches the file, emits 1.0
  /// immediately. On checksum mismatch the output is deleted and the
  /// stream errors ([status] then reports `failed`).
  ///
  /// Progress is `done-chunks / total-chunks` plus an intra-chunk fraction
  /// against [kChunkSizeHint] — monotonic by construction (the fraction is
  /// capped below the next chunk boundary).
  Stream<double> prepare() async* {
    if (await _markerMatchesFile()) {
      yield 1.0;
      return;
    }
    final chunks = await _listBundledChunks();
    if (chunks.isEmpty) {
      throw StateError('No model chunks bundled — Lite mode only.');
    }

    _preparing = true;
    _failed = false;
    final model = File(modelFilePath);
    IOSink? out;
    try {
      await _targetDir.create(recursive: true);
      out = model.openWrite();
      final digestOut = _DigestCapture();
      final hashSink = sha256.startChunkedConversion(digestOut);

      yield 0.0;
      var size = 0;
      for (var i = 0; i < chunks.length; i++) {
        var chunkBytes = 0;
        await for (final slice in _openAssetRead(chunks[i])) {
          out.add(slice);
          hashSink.add(slice);
          size += slice.length;
          chunkBytes += slice.length;
          final fraction =
              math.min(chunkBytes / kChunkSizeHint, 1.0 - 1e-9);
          yield (i + fraction) / chunks.length;
        }
        yield (i + 1) / chunks.length;
      }
      await out.flush();
      await out.close();
      out = null;
      hashSink.close();

      final actual = digestOut.digest.toString();
      final expected = (await _readBundledSha256())?.trim().toLowerCase();
      if (expected != null && expected != actual) {
        throw StateError(
            'Model checksum mismatch: expected $expected, got $actual');
      }

      await File(_metaFilePath)
          .writeAsString(jsonEncode({'size': size, 'sha256': actual}));
      // Exclude the large model file from iCloud backup on iOS.
      try {
        await BackupExclusion.excludeFromBackup(modelFilePath);
      } catch (_) {
        // Swallow MissingPluginException in test environments; the attribute
        // persists on the real filesystem once set successfully.
      }
      yield 1.0;
    } catch (_) {
      _failed = true;
      await out?.close();
      if (await model.exists()) await model.delete();
      final meta = File(_metaFilePath);
      if (await meta.exists()) await meta.delete();
      rethrow;
    } finally {
      _preparing = false;
    }
  }
}

/// Terminal sink capturing the single [Digest] from a chunked conversion.
class _DigestCapture implements Sink<Digest> {
  late Digest digest;

  @override
  void add(Digest data) => digest = data;

  @override
  void close() {}
}
