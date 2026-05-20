import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// C API 绑定层 - 直接映射 llama_wrapper.h 中的函数
///
/// 注意：这个文件只包含 FFI 绑定定义，不包含业务逻辑。
/// 业务逻辑请使用 [LlamaService]。

// ========== 类型定义 ==========

typedef LLamaLoadModelC = Pointer<Void> Function(Pointer<Utf8> modelPath);
typedef LLamaLoadModelDart = Pointer<Void> Function(Pointer<Utf8> modelPath);

typedef LLamaGenerateC = Int32 Function(
  Pointer<Void> modelCtx,
  Pointer<Utf8> prompt,
  Pointer<Utf8> output,
  Int32 outputSize,
  Int32 maxTokens,
  Float temperature,
);
typedef LLamaGenerateDart = int Function(
  Pointer<Void> modelCtx,
  Pointer<Utf8> prompt,
  Pointer<Utf8> output,
  int outputSize,
  int maxTokens,
  double temperature,
);

typedef LLamaGenerateStreamC = Int32 Function(
  Pointer<Void> modelCtx,
  Pointer<Utf8> prompt,
  Pointer<NativeFunction<TokenCallbackC>> callback,
  Pointer<Void> userData,
  Int32 maxTokens,
  Float temperature,
);
typedef LLamaGenerateStreamDart = int Function(
  Pointer<Void> modelCtx,
  Pointer<Utf8> prompt,
  Pointer<NativeFunction<TokenCallbackC>> callback,
  Pointer<Void> userData,
  int maxTokens,
  double temperature,
);

typedef LLamaChatC = Int32 Function(
  Pointer<Void> modelCtx,
  Pointer<Utf8> chatPrompt,
  Pointer<Utf8> output,
  Int32 outputSize,
  Int32 maxTokens,
  Float temperature,
);
typedef LLamaChatDart = int Function(
  Pointer<Void> modelCtx,
  Pointer<Utf8> chatPrompt,
  Pointer<Utf8> output,
  int outputSize,
  int maxTokens,
  double temperature,
);

typedef LLamaWrapperFreeC = Void Function(Pointer<Void> modelCtx);
typedef LLamaWrapperFreeDart = void Function(Pointer<Void> modelCtx);

typedef LLamaGetLastErrorC = Pointer<Utf8> Function();
typedef LLamaGetLastErrorDart = Pointer<Utf8> Function();

// 流式生成的 token 回调类型
typedef TokenCallbackC = Void Function(Pointer<Utf8> token, Pointer<Void> userData);

// ========== 库加载 ==========

DynamicLibrary _openLibrary() {
  if (Platform.isAndroid) {
    return DynamicLibrary.open('libllama_wrapper.so');
  } else if (Platform.isLinux) {
    return DynamicLibrary.open('libllama_wrapper.so');
  } else if (Platform.isMacOS) {
    return DynamicLibrary.open('libllama_wrapper.dylib');
  } else if (Platform.isWindows) {
    return DynamicLibrary.open('llama_wrapper.dll');
  }
  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}

final DynamicLibrary _lib = _openLibrary();

// ========== 函数绑定 ==========

final LLamaLoadModelDart llamaLoadModel = _lib
    .lookup<NativeFunction<LLamaLoadModelC>>('llama_load_model')
    .asFunction();

final LLamaGenerateDart llamaGenerate = _lib
    .lookup<NativeFunction<LLamaGenerateC>>('llama_generate')
    .asFunction();

final LLamaGenerateStreamDart llamaGenerateStream = _lib
    .lookup<NativeFunction<LLamaGenerateStreamC>>('llama_generate_stream')
    .asFunction();

final LLamaChatDart llamaChat = _lib
    .lookup<NativeFunction<LLamaChatC>>('llama_chat')
    .asFunction();

final LLamaWrapperFreeDart llamaWrapperFree = _lib
    .lookup<NativeFunction<LLamaWrapperFreeC>>('llama_wrapper_free')
    .asFunction();

final LLamaGetLastErrorDart llamaGetLastError = _lib
    .lookup<NativeFunction<LLamaGetLastErrorC>>('llama_get_last_error')
    .asFunction();
