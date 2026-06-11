/// ModelManager chunk reassembly, verification, idempotence, and gating —
/// against temp dirs and fake in-memory asset chunks.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallycoach/core/brain/model_manager.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('rallycoach_mm_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  final chunk0 = Uint8List.fromList(List.generate(70000, (i) => i % 251));
  final chunk1 = Uint8List.fromList(List.generate(50000, (i) => (i * 7) % 256));
  final whole = Uint8List.fromList([...chunk0, ...chunk1]);
  final wholeSha = sha256.convert(whole).toString();

  Stream<List<int>> openChunk(String key) async* {
    final data = key.endsWith('0') ? chunk0 : chunk1;
    // Emit in small slices like the production asset reader.
    const slice = 8192;
    for (var off = 0; off < data.length; off += slice) {
      final end = off + slice > data.length ? data.length : off + slice;
      yield data.sublist(off, end);
    }
  }

  ModelManager manager({
    bool withChunks = true,
    String? sha,
    Future<int?> Function()? ram,
  }) =>
      ModelManager(
        listBundledChunks: () async => withChunks
            ? ['assets/models/gemma_e2b.chunk0', 'assets/models/gemma_e2b.chunk1']
            : [],
        openAssetRead: openChunk,
        readBundledSha256: () async => sha,
        targetDir: tmp,
        deviceRamBytes: ram,
      );

  test('reassembly produces byte-identical concatenation', () async {
    final m = manager(sha: wholeSha);
    final progress = await m.prepare().toList();
    expect(progress.first, 0.0);
    expect(progress.last, 1.0);
    for (var i = 1; i < progress.length; i++) {
      expect(progress[i], greaterThanOrEqualTo(progress[i - 1]),
          reason: 'progress must be monotonic');
    }
    final out = await File(m.modelFilePath).readAsBytes();
    expect(out, whole);
    expect(await m.status, BrainStatus.ready);
  });

  test('sha mismatch fails, deletes output, reports failed', () async {
    final m = manager(sha: 'deadbeef');
    await expectLater(m.prepare().drain<void>(), throwsStateError);
    expect(await File(m.modelFilePath).exists(), isFalse);
    expect(await m.status, BrainStatus.failed);
  });

  test('missing digest asset skips verification', () async {
    final m = manager(sha: null);
    await m.prepare().drain<void>();
    expect(await m.status, BrainStatus.ready);
  });

  test('idempotent: second prepare emits 1.0 immediately', () async {
    final m = manager(sha: wholeSha);
    await m.prepare().drain<void>();
    final second = await m.prepare().toList();
    expect(second, [1.0]);
  });

  test('meta marker mismatch (truncated file) is not ready', () async {
    final m = manager(sha: wholeSha);
    await m.prepare().drain<void>();
    await File(m.modelFilePath)
        .writeAsBytes(whole.sublist(0, 100), flush: true);
    expect(await m.status, isNot(BrainStatus.ready));
  });

  test('no chunks bundled -> absent + liteOnly', () async {
    final m = manager(withChunks: false);
    expect(await m.status, BrainStatus.absent);
    expect(m.liteOnly, isTrue);
    expect(m.prepare().drain<void>(), throwsStateError);
  });

  test('RAM below 6 GB gates to liteOnly even when ready', () async {
    final m = manager(sha: wholeSha, ram: () async => 4 * 1024 * 1024 * 1024);
    await m.prepare().drain<void>();
    expect(await m.status, BrainStatus.ready);
    expect(m.liteOnly, isTrue);

    final ok = manager(sha: wholeSha, ram: () async => 8 * 1024 * 1024 * 1024);
    expect(await ok.status, BrainStatus.ready);
    expect(ok.liteOnly, isFalse);
  });

  test('meta marker records size and sha', () async {
    final m = manager(sha: wholeSha);
    await m.prepare().drain<void>();
    final meta = jsonDecode(
            await File('${tmp.path}/$kModelMetaFileName').readAsString())
        as Map<String, dynamic>;
    expect(meta['size'], whole.length);
    expect(meta['sha256'], wholeSha);
  });
}
