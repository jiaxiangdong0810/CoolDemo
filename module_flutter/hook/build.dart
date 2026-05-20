import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }

    final libFile = await _buildLlamaWrapper(input);
    if (libFile != null) {
      output.assets.code.add(
        CodeAsset(
          package: input.packageName,
          name: 'llama_wrapper',
          linkMode: DynamicLoadingBundled(),
          file: libFile.uri,
        ),
      );
    }
  });
}

Future<File?> _buildLlamaWrapper(BuildInput input) async {
  final sourceDir = input.packageRoot.resolve('src/llama_native/');
  final codeConfig = input.config.code;
  final targetOS = codeConfig.targetOS;
  final targetArch = codeConfig.targetArchitecture;

  // 当前项目仅支持 arm64-v8a，跳过其他 ABI
  if (targetOS == OS.android && targetArch != Architecture.arm64) {
    return null;
  }

  final buildDir = Directory.fromUri(
    input.outputDirectory.resolve(
      'build_${targetOS.name}_${targetArch.name}',
    ),
  );
  await buildDir.create(recursive: true);

  final libName = _getLibraryName(targetOS);
  final expectedLib = _findLibrary(buildDir, libName);

  // 增量构建：已编译则直接复用
  if (expectedLib != null && await expectedLib.exists()) {
    return expectedLib;
  }

  // 构建 CMake 参数
  final cmakeArgs = <String>[
    '-S', sourceDir.toFilePath(),
    '-B', buildDir.path,
    '-DCMAKE_BUILD_TYPE=Release',
  ];

  // Android 平台：NDK 交叉编译
  if (targetOS == OS.android) {
    final ndkPath = _findNdkPath(input);
    final toolchain = '$ndkPath/build/cmake/android.toolchain.cmake';
    final abi = _getAndroidAbi(targetArch);

    if (!File(toolchain).existsSync()) {
      throw Exception('Android toolchain not found: $toolchain');
    }

    cmakeArgs.addAll([
      '-DCMAKE_TOOLCHAIN_FILE=$toolchain',
      '-DANDROID_ABI=$abi',
      '-DANDROID_PLATFORM=android-24',
      '-DANDROID_STL=c++_static',
    ]);
  }

  // macOS 特定架构（可选）
  if (targetOS == OS.macOS) {
    final arch = _getMacOSArch(targetArch);
    if (arch != null) {
      cmakeArgs.add('-DCMAKE_OSX_ARCHITECTURES=$arch');
    }
  }

  // iOS 特定架构（可选）
  if (targetOS == OS.iOS) {
    final arch = _getIOSArch(targetArch);
    if (arch != null) {
      cmakeArgs.add('-DCMAKE_OSX_ARCHITECTURES=$arch');
    }
    cmakeArgs.add('-DCMAKE_SYSTEM_NAME=iOS');
  }

  // Step 1: CMake Configure
  final configureResult = await Process.run(
    'cmake',
    cmakeArgs,
    workingDirectory: buildDir.path,
    runInShell: Platform.isWindows,
  );
  if (configureResult.exitCode != 0) {
    stderr.writeln(configureResult.stderr);
    throw Exception('CMake configure failed (exit ${configureResult.exitCode})');
  }

  // Step 2: CMake Build
  final buildResult = await Process.run(
    'cmake',
    ['--build', buildDir.path, '--parallel'],
    workingDirectory: buildDir.path,
    runInShell: Platform.isWindows,
  );
  if (buildResult.exitCode != 0) {
    stderr.writeln(buildResult.stderr);
    throw Exception('CMake build failed (exit ${buildResult.exitCode})');
  }

  // Step 3: 找到编译产物
  final libFile = _findLibrary(buildDir, libName);
  if (libFile == null) {
    throw Exception('Library not found after build: $libName');
  }

  return libFile;
}

String _getLibraryName(OS os) {
  return switch (os) {
    OS.android || OS.linux => 'libllama_wrapper.so',
    OS.macOS || OS.iOS => 'libllama_wrapper.dylib',
    OS.windows => 'llama_wrapper.dll',
    _ => throw UnsupportedError('Unsupported OS: $os'),
  };
}

String _getAndroidAbi(Architecture arch) {
  return switch (arch) {
    Architecture.arm64 => 'arm64-v8a',
    Architecture.arm => 'armeabi-v7a',
    Architecture.x64 => 'x86_64',
    Architecture.ia32 => 'x86',
    _ => throw UnsupportedError('Unsupported Android arch: $arch'),
  };
}

String? _getMacOSArch(Architecture? arch) {
  return switch (arch) {
    Architecture.arm64 => 'arm64',
    Architecture.x64 => 'x86_64',
    _ => null,
  };
}

String? _getIOSArch(Architecture? arch) {
  return switch (arch) {
    Architecture.arm64 => 'arm64',
    _ => null,
  };
}

String _findNdkPath(BuildInput input) {
  // 1. 从 input.config.code.cCompiler 反推 NDK 路径
  // 例如 clang 路径: /path/to/ndk/27.2.12479018/toolchains/llvm/prebuilt/.../bin/clang
  final cCompiler = input.config.code.cCompiler;
  if (cCompiler != null) {
    final compilerPath = cCompiler.compiler.toFilePath();
    final ndkMatch = RegExp(r'(.+?/ndk/[^/]+)/').firstMatch(compilerPath);
    if (ndkMatch != null) {
      final ndkPath = ndkMatch.group(1)!;
      if (Directory(ndkPath).existsSync()) {
        return ndkPath;
      }
    }
  }

  // 2. 环境变量（hooks 会传递这些变量）
  final env = Platform.environment;
  for (final key in [
    'ANDROID_NDK',
    'ANDROID_NDK_HOME',
    'ANDROID_NDK_LATEST_HOME',
    'ANDROID_NDK_ROOT',
  ]) {
    final path = env[key];
    if (path != null && Directory(path).existsSync()) {
      return path;
    }
  }

  // 3. 从 ANDROID_HOME 的 ndk 目录找最新版本
  final androidHome = env['ANDROID_HOME'];
  if (androidHome != null) {
    final ndkDir = Directory('$androidHome/ndk');
    if (ndkDir.existsSync()) {
      final versions = ndkDir.listSync()
          .whereType<Directory>()
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      if (versions.isNotEmpty) {
        return versions.first.path;
      }
    }
    // 旧版 ndk-bundle
    final ndkBundle = Directory('$androidHome/ndk-bundle');
    if (ndkBundle.existsSync()) {
      return ndkBundle.path;
    }
  }

  throw Exception(
    'Android NDK not found. '
    '请设置 ANDROID_NDK 环境变量，或确保 NDK 已安装在 \$ANDROID_HOME/ndk/ 下',
  );
}

File? _findLibrary(Directory buildDir, String libName) {
  for (final entry in buildDir.listSync(recursive: true)) {
    if (entry is File) {
      final basename = entry.uri.pathSegments.last;
      if (basename == libName) {
        return entry;
      }
    }
  }
  return null;
}
