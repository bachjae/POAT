/// On-device LLM access for the Coach Brain (SPEC §9).
///
/// [LlmRunner] is the seam between coaching logic and the model runtime:
/// [GemmaLlmRunner] wraps flutter_gemma's LiteRT-LM path against the file
/// reassembled by [ModelManager] (device-only, excluded from unit tests);
/// [FakeLlmRunner] is the scriptable double used by tests and by Lite-mode
/// demos. There is no network code anywhere in this app, by design.
library;

// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_gemma/flutter_gemma.dart';

import 'model_manager.dart';

/// Minimal generation interface the coaching layer depends on.
abstract class LlmRunner {
  /// Whether generation can be attempted at all (model ready, RAM gate ok).
  Future<bool> isAvailable();

  /// Loads the model into memory so the first cue is not paid at hit time.
  Future<void> warmUp();

  /// Single full response. When [deadline] elapses, the returned future
  /// completes with a [TimeoutException] which the caller maps to the
  /// deterministic rule-engine fallback.
  ///
  /// [contactFrame] is an optional 96×96 packed-RGB thumbnail captured at
  /// the shot peak. When provided and the active model supports multimodal
  /// input, the brain receives the raw visual frame alongside the text prompt
  /// so it can verify that the detected swing actually happened.
  Future<String> generate(
    String prompt, {
    required int maxTokens,
    double temperature = 0.4,
    Duration? deadline,
    Uint8List? contactFrame,
  });

  /// Token stream for live UI (chat, summary typing effect).
  Stream<String> generateStream(
    String prompt, {
    required int maxTokens,
    double temperature = 0.4,
    Uint8List? contactFrame,
  });

  /// Releases the loaded model.
  Future<void> dispose();
}

/// flutter_gemma-backed runner for the bundled Gemma 4 E2B `.litertlm`.
///
/// Device-only — excluded from unit tests; kept thin and obviously correct.
///
/// Wiring (flutter_gemma 0.16.x modern API):
/// - `FlutterGemma.installModel(modelType: ModelType.gemma4,
///   fileType: ModelFileType.litertlm).fromFile(path).install()` registers
///   the reassembled file as the active model (no copy — FileSource keeps
///   the file in place).
/// - `FlutterGemma.getActiveModel(maxTokens: ...)` loads the weights once.
/// - Per request: `createSession(temperature, topK) → addQueryChunk(
///   Message) → getResponse() / getResponseAsync()`, then session.close().
class GemmaLlmRunner implements LlmRunner {
  GemmaLlmRunner({
    required ModelManager modelManager,
    int contextTokens = 2048,
    PreferredBackend? preferredBackend,
    String? modelPathOverride,
  })  : _modelManager = modelManager,
        _contextTokens = contextTokens,
        _preferredBackend = preferredBackend,
        _modelPathOverride = modelPathOverride;

  final ModelManager _modelManager;

  /// Context window requested at model load. flutter_gemma fixes the token
  /// budget when the model is created, so the per-call `maxTokens` acts as
  /// an upper bound the caller designs prompts around (output stops at the
  /// session budget; cue/summary/chat prompts + 700 output fit in 2048).
  final int _contextTokens;
  final PreferredBackend? _preferredBackend;

  /// When set, used instead of [ModelManager.modelFilePath] — allows the
  /// Pro model path to be injected without subclassing.
  final String? _modelPathOverride;

  static const int _topK = 40;

  InferenceModel? _model;

  @override
  Future<bool> isAvailable() async {
    final status = await _modelManager.status;
    return status == BrainStatus.ready && !_modelManager.liteOnly;
  }

  @override
  Future<void> warmUp() async {
    if (_model != null) return;
    if (!await isAvailable()) {
      throw StateError('Coach Brain unavailable (Lite mode).');
    }
    await FlutterGemma.installModel(
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
    ).fromFile(_modelPathOverride ?? _modelManager.modelFilePath).install();
    _model = await FlutterGemma.getActiveModel(
      maxTokens: _contextTokens,
      preferredBackend: _preferredBackend,
    );
  }

  @override
  Future<String> generate(
    String prompt, {
    required int maxTokens,
    double temperature = 0.4,
    Duration? deadline,
    Uint8List? contactFrame,
  }) async {
    final session = await _session(temperature);
    try {
      await session.addQueryChunk(_message(prompt, contactFrame));
      var response = session.getResponse();
      if (deadline != null) {
        response = response.timeout(deadline, onTimeout: () async {
          await session.stopGeneration();
          throw TimeoutException('Coach Brain deadline elapsed', deadline);
        });
      }
      return await response;
    } finally {
      await session.close();
    }
  }

  @override
  Stream<String> generateStream(
    String prompt, {
    required int maxTokens,
    double temperature = 0.4,
    Uint8List? contactFrame,
  }) async* {
    final session = await _session(temperature);
    try {
      await session.addQueryChunk(_message(prompt, contactFrame));
      yield* session.getResponseAsync();
    } finally {
      await session.close();
    }
  }

  /// Builds a [Message], attaching the RGB thumbnail as a multimodal image
  /// when available. Gemma 4 (E2B and up) processes both text and images via
  /// its SigLIP vision encoder — the frame lets the model confirm that an arm
  /// swing is actually visible before committing to a technique cue.
  Message _message(String prompt, Uint8List? frame) {
    if (frame != null) {
      return Message(text: prompt, isUser: true, images: [frame]);
    }
    return Message(text: prompt, isUser: true);
  }

  Future<InferenceModelSession> _session(double temperature) async {
    await warmUp();
    return _model!.createSession(temperature: temperature, topK: _topK);
  }

  @override
  Future<void> dispose() async {
    await _model?.close();
    _model = null;
  }
}

/// Scriptable in-memory runner for tests and Lite-mode demos.
///
/// Responses are consumed FIFO; when the queue is empty, [fallbackResponse]
/// is returned. [generateStream] emits the response word by word.
class FakeLlmRunner implements LlmRunner {
  FakeLlmRunner({
    List<String> responses = const [],
    this.fallbackResponse = '',
    this.delay = Duration.zero,
    this.available = true,
  }) : _responses = List.of(responses);

  final List<String> _responses;
  final String fallbackResponse;

  /// Injected per-call (and per-token in [generateStream]) latency.
  final Duration delay;
  bool available;

  bool warmedUp = false;
  bool disposed = false;

  /// Every prompt passed to [generate] / [generateStream], in order.
  final List<String> prompts = [];

  /// Appends a scripted response to the queue.
  void enqueue(String response) => _responses.add(response);

  String _next() =>
      _responses.isEmpty ? fallbackResponse : _responses.removeAt(0);

  @override
  Future<bool> isAvailable() async => available && !disposed;

  @override
  Future<void> warmUp() async {
    warmedUp = true;
  }

  @override
  Future<String> generate(
    String prompt, {
    required int maxTokens,
    double temperature = 0.4,
    Duration? deadline,
    Uint8List? contactFrame,
  }) async {
    prompts.add(prompt);
    if (deadline != null && delay > deadline) {
      throw TimeoutException('FakeLlmRunner deadline elapsed', deadline);
    }
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return _next();
  }

  @override
  Stream<String> generateStream(
    String prompt, {
    required int maxTokens,
    double temperature = 0.4,
    Uint8List? contactFrame,
  }) async* {
    prompts.add(prompt);
    final response = _next();
    final words = response.split(' ');
    for (var i = 0; i < words.length; i++) {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      yield i == 0 ? words[i] : ' ${words[i]}';
    }
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
