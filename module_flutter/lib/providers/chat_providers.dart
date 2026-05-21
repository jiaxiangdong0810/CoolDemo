import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../services/chat_session.dart';
import '../services/chat_session_manager.dart';
import '../services/llama_service.dart';

/// LlamaService 单例 Provider
final llamaServiceProvider = Provider<LlamaService>((ref) => LlamaService());

/// ChatSessionManager Provider
///
/// 注意：此 Provider 默认抛出异常，实际值需要通过 [ProviderScope] override 传入。
/// 这是因为 [ChatSessionManager] 需要异步初始化（[ChatSessionManager.init]），
/// 且依赖 [LlamaService] 已加载模型后才能使用。
final chatSessionManagerProvider = ChangeNotifierProvider<ChatSessionManager>((ref) {
  throw UnimplementedError(
    'ChatSessionManager must be provided via ProviderScope override',
  );
});

// ========== 细粒度 Provider ==========
// 利用 Riverpod 的自动缓存和 == 比较，实现选择性重建。
//
// 底层 [ChatSessionManager] 每次变化都走同一个 notifyListeners()，
// 但 Riverpod 会重新计算 Provider 值并比较 ==，只有值变化时才通知下游。
//
// 注意：所有依赖 [chatSessionManagerProvider] 的 Provider 都必须显式声明
// dependencies，否则当 [chatSessionManagerProvider] 在 ProviderScope 中被
// override 时，会触发 Riverpod 的作用域安全错误。

/// 当前消息列表
///
/// 每次 token 到来底层都会 notifyListeners()，
/// 但列表引用总是新的，所以此 Provider 每次都会认为值变化，
/// 依赖它的组件会重建（这是正确行为，消息内容确实变了）。
final currentMessagesProvider = Provider<List<ChatMessage>>(
  (ref) {
    final manager = ref.watch(chatSessionManagerProvider);
    return manager.currentSession?.messages ?? [];
  },
  dependencies: [chatSessionManagerProvider],
);

/// 是否正在生成回复
///
/// [bool] 类型的 == 比较可靠，token 流式输出期间值不变，
/// 所以依赖此 Provider 的组件在逐 token 更新时**不会重建**。
/// 只在生成开始/结束时重建。
final isGeneratingProvider = Provider<bool>(
  (ref) {
    final manager = ref.watch(chatSessionManagerProvider);
    return manager.isGenerating;
  },
  dependencies: [chatSessionManagerProvider],
);

/// 当前会话标题
///
/// [String] 类型的 == 比较可靠，只在标题变化时通知下游。
final currentSessionTitleProvider = Provider<String>(
  (ref) {
    final manager = ref.watch(chatSessionManagerProvider);
    return manager.currentSession?.title ?? '本地 AI 助手';
  },
  dependencies: [chatSessionManagerProvider],
);

/// 当前会话是否有消息
///
/// [bool] 类型，只在 0→有 或 有→0 时变化，频率极低。
final hasMessagesProvider = Provider<bool>(
  (ref) {
    final manager = ref.watch(chatSessionManagerProvider);
    return (manager.currentSession?.messages.length ?? 0) > 0;
  },
  dependencies: [chatSessionManagerProvider],
);

/// 历史会话列表
final sessionsProvider = Provider<List<ChatSession>>(
  (ref) {
    final manager = ref.watch(chatSessionManagerProvider);
    return manager.sessions;
  },
  dependencies: [chatSessionManagerProvider],
);

/// 当前激活会话
final currentSessionProvider = Provider<ChatSession?>(
  (ref) {
    final manager = ref.watch(chatSessionManagerProvider);
    return manager.currentSession;
  },
  dependencies: [chatSessionManagerProvider],
);
