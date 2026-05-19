import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import '../ffi/llama_bindings.dart';

/// LLM 推理服务 - 封装 FFI 调用，提供 Dart 友好的 API
///
/// 所有 FFI 调用都在后台 worker isolate 中执行，避免阻塞 UI 线程。
/// 主 isolate 通过 SendPort 与 worker 通信；流式 token 通过独立 ReceivePort 推回。
class LlamaService {
  SendPort? _commandPort;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  /// 启动 worker isolate（仅首次调用时启动）
  Future<void> _ensureWorker() async {
    if (_commandPort != null) return;

    final initPort = ReceivePort();
    await Isolate.spawn(
      _workerEntry,
      initPort.sendPort,
      debugName: 'llama-worker',
    );
    _commandPort = await initPort.first as SendPort;
    initPort.close();
  }

  /// 发送一条请求-响应类命令
  Future<dynamic> _send(Map<String, dynamic> request) async {
    await _ensureWorker();
    final replyPort = ReceivePort();
    _commandPort!.send({
      ...request,
      'reply': replyPort.sendPort,
    });
    final response = await replyPort.first as Map;
    replyPort.close();

    if (response['ok'] == true) {
      return response['value'];
    }
    throw LlamaException(response['error'] as String);
  }

  /// 加载 GGUF 模型文件
  Future<bool> loadModel(String modelPath) async {
    await _send({'op': 'load', 'path': modelPath});
    _isLoaded = true;
    return true;
  }

  /// 单轮文本生成
  Future<String> generate(
    String prompt, {
    int maxTokens = 256,
    double temperature = 0.7,
  }) async {
    _ensureLoaded();
    final result = await _send({
      'op': 'generate',
      'prompt': prompt,
      'maxTokens': maxTokens,
      'temperature': temperature,
    });
    return result as String;
  }

  /// 流式文本生成
  Future<String> generateStream(
    String prompt, {
    required void Function(String token) onToken,
    int maxTokens = 256,
    double temperature = 0.7,
  }) async {
    _ensureLoaded();
    await _ensureWorker();

    final tokenPort = ReceivePort();
    final replyPort = ReceivePort();
    final buffer = StringBuffer();

    final tokenSub = tokenPort.listen((message) {
      final token = message as String;
      buffer.write(token);
      onToken(token);
    });

    _commandPort!.send({
      'op': 'stream',
      'prompt': prompt,
      'maxTokens': maxTokens,
      'temperature': temperature,
      'tokenPort': tokenPort.sendPort,
      'reply': replyPort.sendPort,
    });

    try {
      final response = await replyPort.first as Map;
      if (response['ok'] != true) {
        throw LlamaException(response['error'] as String);
      }
      return buffer.toString();
    } finally {
      await tokenSub.cancel();
      tokenPort.close();
      replyPort.close();
    }
  }

  /// 多轮对话生成
  Future<String> chat(
    String formattedPrompt, {
    int maxTokens = 256,
    double temperature = 0.7,
  }) async {
    _ensureLoaded();
    final result = await _send({
      'op': 'chat',
      'prompt': formattedPrompt,
      'maxTokens': maxTokens,
      'temperature': temperature,
    });
    return result as String;
  }

  /// 释放模型资源并关闭 worker
  void dispose() {
    final port = _commandPort;
    if (port != null) {
      port.send({'op': 'shutdown'});
    }
    _commandPort = null;
    _isLoaded = false;
  }

  void _ensureLoaded() {
    if (!_isLoaded) {
      throw LlamaException('模型未加载，请先调用 loadModel()');
    }
  }
}

class LlamaException implements Exception {
  final String message;
  LlamaException(this.message);

  @override
  String toString() => 'LlamaException: $message';
}

// ========== Worker Isolate ==========

/// worker isolate 入口
void _workerEntry(SendPort mainSendPort) {
  final commandPort = ReceivePort();
  mainSendPort.send(commandPort.sendPort);

  Pointer<Void>? ctx;

  commandPort.listen((message) {
    final msg = message as Map;
    final op = msg['op'] as String;
    final reply = msg['reply'] as SendPort?;

    try {
      switch (op) {
        case 'load':
          final path = msg['path'] as String;
          ctx = _workerLoad(path);
          reply?.send({'ok': true, 'value': true});

        case 'generate':
          final out = _workerGenerate(
            ctx,
            msg['prompt'] as String,
            msg['maxTokens'] as int,
            (msg['temperature'] as num).toDouble(),
          );
          reply?.send({'ok': true, 'value': out});

        case 'chat':
          final out = _workerGenerate(
            ctx,
            msg['prompt'] as String,
            msg['maxTokens'] as int,
            (msg['temperature'] as num).toDouble(),
          );
          reply?.send({'ok': true, 'value': out});

        case 'stream':
          _workerStream(
            ctx,
            msg['prompt'] as String,
            msg['maxTokens'] as int,
            (msg['temperature'] as num).toDouble(),
            msg['tokenPort'] as SendPort,
          );
          reply?.send({'ok': true, 'value': null});

        case 'shutdown':
          if (ctx != null && ctx != nullptr) {
            llamaWrapperFree(ctx!);
            ctx = null;
          }
          commandPort.close();
          Isolate.exit();
      }
    } catch (e, stack) {
      reply?.send({'ok': false, 'error': '$e\n$stack'});
    }
  });
}

Pointer<Void> _workerLoad(String modelPath) {
  final pathPtr = modelPath.toNativeUtf8();
  try {
    final ctx = llamaLoadModel(pathPtr);
    if (ctx == nullptr) {
      final error = llamaGetLastError().toDartString();
      throw LlamaException('模型加载失败: $error');
    }
    return ctx;
  } finally {
    calloc.free(pathPtr);
  }
}

String _workerGenerate(
  Pointer<Void>? ctx,
  String prompt,
  int maxTokens,
  double temperature,
) {
  if (ctx == null || ctx == nullptr) {
    throw LlamaException('模型未加载');
  }

  final promptPtr = prompt.toNativeUtf8();
  const outputSize = 8192;
  final outputPtr = calloc.allocate<Utf8>(outputSize);

  try {
    final result = llamaGenerate(
      ctx,
      promptPtr,
      outputPtr,
      outputSize,
      maxTokens,
      temperature,
    );
    if (result < 0) {
      final error = llamaGetLastError().toDartString();
      throw LlamaException('生成失败: $error');
    }
    return outputPtr.toDartString();
  } finally {
    calloc.free(promptPtr);
    calloc.free(outputPtr);
  }
}

void _workerStream(
  Pointer<Void>? ctx,
  String prompt,
  int maxTokens,
  double temperature,
  SendPort tokenPort,
) {
  if (ctx == null || ctx == nullptr) {
    throw LlamaException('模型未加载');
  }

  final promptPtr = prompt.toNativeUtf8();

  // isolateLocal: 回调同步执行在 worker 线程上，不依赖事件循环
  final callback = NativeCallable<TokenCallbackC>.isolateLocal(
    (Pointer<Utf8> token, Pointer<Void> userData) {
      tokenPort.send(token.toDartString());
    },
  );

  try {
    final result = llamaGenerateStream(
      ctx,
      promptPtr,
      callback.nativeFunction,
      nullptr,
      maxTokens,
      temperature,
    );
    if (result < 0) {
      final error = llamaGetLastError().toDartString();
      throw LlamaException('流式生成失败: $error');
    }
  } finally {
    callback.close();
    calloc.free(promptPtr);
  }
}
