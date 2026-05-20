import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../utils/log.dart';

/// 下载状态
enum DownloadStatus { idle, downloading, completed, failed, cancelled }

/// 下载进度信息
class DownloadProgress {
  final DownloadStatus status;
  final double progress; // 0.0 - 1.0
  final int downloadedBytes;
  final int totalBytes;

  const DownloadProgress({
    this.status = DownloadStatus.idle,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
  });

  double get percentage => totalBytes > 0 ? (downloadedBytes / totalBytes) * 100 : 0;
}

/// 模型管理器 - 负责模型文件的下载、校验、路径管理
///
/// 支持两个存储位置：
/// 1. 内部存储（getApplicationDocumentsDirectory）—— 默认下载位置
/// 2. 外部存储（getExternalStorageDirectory）—— 可通过 adb push 导入
class ModelManager {
  static const String _modelsDir = 'models';

  DownloadProgress _progress = const DownloadProgress();
  DownloadProgress get progress => _progress;

  http.Client? _httpClient;

  /// 获取内部存储的模型目录
  Future<Directory> _getInternalModelsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/$_modelsDir');
    LogByCommon.d('内部存储目录: ${modelsDir.path}');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  /// 获取模型文件的完整路径（内部存储，大小写不敏感匹配）
  Future<String> getModelPath(String modelName) async {
    LogByCommon.d('getModelPath 查找: $modelName');
    final internalDir = await _getInternalModelsDirectory();
    final entities = await internalDir.list().toList();
    LogByCommon.d('内部存储文件数: ${entities.length}');
    for (final entity in entities) {
      if (entity is File) {
        final name = entity.path.split('/').last;
        LogByCommon.d('  内部文件: $name');
        if (name.toLowerCase() == modelName.toLowerCase()) {
          LogByCommon.d('找到模型: ${entity.path}');
          return entity.path;
        }
      }
    }
    LogByCommon.d('未找到模型，返回默认路径: ${internalDir.path}/$modelName');
    return '${internalDir.path}/$modelName';
  }

  /// 检查模型是否可用（在内部存储中查找，文件名大小写不敏感）
  Future<bool> isModelAvailable(String modelName) async {
    LogByCommon.d('isModelAvailable 查找: $modelName');
    final dir = await _getInternalModelsDirectory();
    if (!await dir.exists()) {
      LogByCommon.d('模型不可用: $modelName');
      return false;
    }
    LogByCommon.d('扫描目录: ${dir.path}');

    final entities = await dir.list().toList();
    for (final entity in entities) {
      if (entity is! File) continue;
      final name = entity.path.split('/').last;
      final size = await entity.length();
      LogByCommon.d('  文件: $name, 大小: ${(size / 1024 / 1024).toStringAsFixed(1)} MB');
      if (name.toLowerCase() == modelName.toLowerCase()) {
        if (size > 1024 * 1024) {
          LogByCommon.d('模型可用: $name');
          return true;
        }
      }
    }
    LogByCommon.d('模型不可用: $modelName');
    return false;
  }

  /// 从本地文件系统导入模型文件到内部存储
  ///
  /// [sourcePath] 用户选择的源文件路径（来自 file_picker）
  /// [targetName] 导入后保存的文件名（可选，默认使用原文件名）
  /// [onProgress] 进度回调（每 1MB 回调一次）
  Future<String?> importModel(
    String sourcePath, {
    String? targetName,
    void Function(double)? onProgress,
  }) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        LogByCommon.d('源文件不存在: $sourcePath');
        return null;
      }

      final fileName = targetName ?? sourcePath.split('/').last;
      final modelsDir = await _getInternalModelsDirectory();
      final targetPath = '${modelsDir.path}/$fileName';
      final targetFile = File(targetPath);

      // 如果目标文件已存在，先删除
      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      // 流式复制，支持大文件
      final sourceLength = await sourceFile.length();
      final sourceStream = sourceFile.openRead();
      final sink = targetFile.openWrite();

      int copiedBytes = 0;
      int lastReportedMb = 0;

      await for (final chunk in sourceStream) {
        sink.add(chunk);
        copiedBytes += chunk.length;

        final currentMb = copiedBytes ~/ (1024 * 1024);
        if (currentMb > lastReportedMb) {
          lastReportedMb = currentMb;
          if (sourceLength > 0) {
            onProgress?.call(copiedBytes / sourceLength);
          }
        }
      }

      await sink.close();

      // 校验
      if (!await validateModel(targetPath)) {
        await targetFile.delete();
        LogByCommon.d('导入文件校验失败');
        return null;
      }

      LogByCommon.d('模型导入成功: $targetPath');
      return targetPath;
    } catch (e, stack) {
      LogByCommon.d('导入模型失败', error: e, stackTrace: stack);
      return null;
    }
  }

  /// 校验模型文件
  Future<bool> validateModel(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return false;
    }
    final size = await file.length();
    // 至少 1MB，避免空文件或损坏文件
    return size > 1024 * 1024;
  }

  /// 下载模型文件
  ///
  /// [url] 模型文件的下载链接
  /// [modelName] 保存的文件名
  /// [onProgress] 进度回调
  Future<String?> downloadModel(
    String url,
    String modelName, {
    void Function(DownloadProgress)? onProgress,
  }) async {
    _httpClient?.close();
    _httpClient = http.Client();

    _progress = const DownloadProgress(status: DownloadStatus.downloading);
    onProgress?.call(_progress);

    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await _httpClient!.send(request);

      if (response.statusCode != 200) {
        _progress = const DownloadProgress(status: DownloadStatus.failed);
        onProgress?.call(_progress);
        return null;
      }

      final totalBytes = response.contentLength ?? 0;
      final modelsDir = await _getInternalModelsDirectory();
      final filePath = '${modelsDir.path}/$modelName';
      final file = File(filePath);

      // 清理已存在的部分文件
      if (await file.exists()) {
        await file.delete();
      }

      final sink = file.openWrite();
      int downloadedBytes = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;

        _progress = DownloadProgress(
          status: DownloadStatus.downloading,
          downloadedBytes: downloadedBytes,
          totalBytes: totalBytes,
          progress: totalBytes > 0 ? downloadedBytes / totalBytes : 0,
        );
        onProgress?.call(_progress);
      }

      await sink.close();

      // 校验下载的文件
      if (!await validateModel(filePath)) {
        await file.delete();
        _progress = const DownloadProgress(status: DownloadStatus.failed);
        onProgress?.call(_progress);
        return null;
      }

      _progress = DownloadProgress(
        status: DownloadStatus.completed,
        downloadedBytes: downloadedBytes,
        totalBytes: totalBytes,
        progress: 1.0,
      );
      onProgress?.call(_progress);

      return filePath;
    } catch (e) {
      _progress = const DownloadProgress(status: DownloadStatus.failed);
      onProgress?.call(_progress);
      return null;
    }
  }

  /// 取消下载
  void cancelDownload() {
    _httpClient?.close();
    _httpClient = null;
    _progress = const DownloadProgress(status: DownloadStatus.cancelled);
  }

  /// 获取当前下载进度
  DownloadProgress getDownloadProgress() => _progress;

  /// 删除模型文件
  Future<bool> deleteModel(String modelName) async {
    final path = await getModelPath(modelName);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }

  /// 获取已下载的模型列表（搜索内部存储）
  Future<List<String>> getDownloadedModels() async {
    try {
      final modelsDir = await _getInternalModelsDirectory();
      if (!await modelsDir.exists()) return [];

      final entities = await modelsDir.list().toList();
      return entities
          .whereType<File>()
          .where((f) => f.path.endsWith('.gguf'))
          .map((f) => f.path.split('/').last)
          .toList();
    } catch (e) {
      return [];
    }
  }
}
