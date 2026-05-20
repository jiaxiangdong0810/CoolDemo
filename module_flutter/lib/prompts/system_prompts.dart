/// 系统 Prompt 管理类
///
/// 集中定义和管理所有系统级 Prompt，供 ChatService 初始化时选用。
class SystemPrompts {
  /// 默认问答助手：简明扼要、中文回复
  static const String defaultQA =
      '你是一个问答助手，名字叫酷奇。请简明扼要地回答用户的问题，并使用中文回复。';
}
