import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/chat_session_manager.dart';
import '../services/llama_service.dart';
import '../services/model_manager.dart';
import '../utils/log.dart';
import 'chat_page.dart';

/// 模型设置页面 - 首次启动时引导用户下载模型
class ModelSetupPage extends StatefulWidget {
  const ModelSetupPage({super.key});

  @override
  State<ModelSetupPage> createState() => _ModelSetupPageState();
}

class _ModelSetupPageState extends State<ModelSetupPage> {
  final LlamaService _llamaService = LlamaService();
  final ModelManager _modelManager = ModelManager();
  bool _isLoading = true;
  bool _isDownloading = false;
  bool _isImporting = false;
  double _importProgress = 0.0;
  bool _hasModel = false;
  String? _modelPath;
  DownloadProgress _downloadProgress = const DownloadProgress();

  // 默认模型配置
  static const String _defaultModelName = 'LLM.gguf';
  static const String _defaultModelUrl =
      'https://huggingface.co/bartowski/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/Qwen2.5-0.5B-Instruct-Q4_0.gguf';

  /// 标记是否正在跳转到聊天页，用于区分 dispose 场景：
  /// - true: pushReplacement 去 ChatPage，不销毁 LlamaService
  /// - false: pop 回主页面，销毁 LlamaService 释放资源
  bool _navigatingToChat = false;

  @override
  void initState() {
    super.initState();
    _checkModel();
  }

  @override
  void dispose() {
    if (!_navigatingToChat) {
      _llamaService.dispose();
    }
    super.dispose();
  }

  Future<void> _checkModel() async {
    LogByCommon.d('开始检查模型: $_defaultModelName');
    try {
      final hasModel = await _modelManager.isModelAvailable(_defaultModelName);
      final modelPath = hasModel ? await _modelManager.getModelPath(_defaultModelName) : null;
      LogByCommon.d('模型检查结果 — hasModel=$hasModel, path=$modelPath');

      setState(() {
        _isLoading = false;
        _hasModel = hasModel;
        _modelPath = modelPath;
      });
    } catch (e, stack) {
      LogByCommon.d('检查模型失败', error: e, stackTrace: stack);
      setState(() {
        _isLoading = false;
        _hasModel = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检查模型失败: $e')),
        );
      }
    }
  }

  Future<void> _loadModelAndNavigate() async {
    setState(() => _isLoading = true);
    LogByCommon.d('开始加载模型...');

    try {
      final modelPath = await _modelManager.getModelPath(_defaultModelName);
      LogByCommon.d('模型路径: $modelPath');

      // 同一模型已加载则跳过
      if (!_llamaService.isLoaded || _llamaService.loadedModelPath != modelPath) {
        await _llamaService.loadModel(modelPath);
        LogByCommon.d('模型加载成功');
      } else {
        LogByCommon.d('模型已加载，跳过重复加载');
      }

      if (mounted) {
        final sessionManager = ChatSessionManager(
          llamaService: _llamaService,
        );
        await sessionManager.init();

        if (mounted) {
          _navigatingToChat = true;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ChatPage(
                sessionManager: sessionManager,
              ),
            ),
          );
        }
      }
    } catch (e, stack) {
      LogByCommon.d('模型加载失败', error: e, stackTrace: stack);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('模型加载失败: $e')),
        );
      }
    }
  }

  Future<void> _downloadModel() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = const DownloadProgress(status: DownloadStatus.downloading);
    });
    LogByCommon.d('开始下载模型: $_defaultModelUrl');

    final path = await _modelManager.downloadModel(
      _defaultModelUrl,
      _defaultModelName,
      onProgress: (progress) {
        setState(() => _downloadProgress = progress);
        LogByCommon.d('下载进度: ${(progress.progress * 100).toStringAsFixed(1)}%');
      },
    );

    if (path != null && mounted) {
      LogByCommon.d('模型下载完成: $path');
      _loadModelAndNavigate();
    } else if (mounted) {
      LogByCommon.d('模型下载失败');
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('下载失败，请检查网络后重试')),
      );
    }
  }

  Future<void> _importModel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        LogByCommon.d('用户取消选择文件');
        return;
      }

      final filePath = result.files.single.path;
      if (filePath == null || !filePath.toLowerCase().endsWith('.gguf')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请选择 .gguf 格式的模型文件')),
          );
        }
        return;
      }

      setState(() {
        _isImporting = true;
        _importProgress = 0.0;
      });
      LogByCommon.d('开始导入模型: $filePath');

      final importedPath = await _modelManager.importModel(
        filePath,
        targetName: _defaultModelName,
        onProgress: (progress) {
          setState(() => _importProgress = progress);
          LogByCommon.d('导入进度: ${(progress * 100).toStringAsFixed(1)}%');
        },
      );

      if (importedPath != null && mounted) {
        LogByCommon.d('模型导入成功: $importedPath');
        // 导入新模型后，释放旧模型上下文，下次点击"开始聊天"时重新加载
        await _llamaService.unloadModel();
        setState(() {
          _isImporting = false;
          _hasModel = true;
          _modelPath = importedPath;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('模型导入成功')),
        );
      } else if (mounted) {
        LogByCommon.d('模型导入失败');
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导入失败，请检查文件后重试')),
        );
      }
    } catch (e, stack) {
      LogByCommon.d('导入模型异常', error: e, stackTrace: stack);
      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入出错: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在加载模型...'),
            ],
          ),
        ),
      );
    }

    // 本地已有模型 —— 显示模型信息 + 开始聊天按钮
    if (_hasModel) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.memory,
                  size: 80,
                  color: Colors.green,
                ),
                const SizedBox(height: 24),
                const Text(
                  '本地模型已就绪',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '检测到已下载的模型文件',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '模型文件',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _defaultModelName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '存储路径',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _modelPath ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: _loadModelAndNavigate,
                  icon: const Icon(Icons.chat_bubble),
                  label: const Text('开始聊天'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isImporting ? null : _importModel,
                  icon: _isImporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.folder_open),
                  label: Text(_isImporting ? '正在导入...' : '重新导入模型'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 没有模型 —— 保持原有下载逻辑
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.memory,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              const Text(
                '本地 AI 助手',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '模型完全在设备本地运行\n数据不会上传到任何服务器',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 40),
              if (_isDownloading) ...[
                LinearProgressIndicator(
                  value: _downloadProgress.progress > 0
                      ? _downloadProgress.progress
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  '正在下载模型... ${_downloadProgress.percentage.toStringAsFixed(1)}%',
                  textAlign: TextAlign.center,
                ),
                Text(
                  '${(_downloadProgress.downloadedBytes / 1024 / 1024).toStringAsFixed(1)} MB / '
                  '${(_downloadProgress.totalBytes / 1024 / 1024).toStringAsFixed(1)} MB',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    _modelManager.cancelDownload();
                    setState(() => _isDownloading = false);
                  },
                  child: const Text('取消下载'),
                ),
              ] else if (_isImporting) ...[
                LinearProgressIndicator(
                  value: _importProgress > 0 ? _importProgress : null,
                ),
                const SizedBox(height: 12),
                Text(
                  '正在导入模型... ${(_importProgress * 100).toStringAsFixed(1)}%',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() => _isImporting = false);
                  },
                  child: const Text('取消'),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _downloadModel,
                  icon: const Icon(Icons.download),
                  label: const Text('下载模型并启动'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _importModel,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('从本地导入'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '模型大小约 350MB，建议在 WiFi 环境下载\n或选择已下载好的 .gguf 文件导入',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
