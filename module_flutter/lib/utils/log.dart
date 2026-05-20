import 'package:logger/logger.dart';

/// 全局日志工具，所有日志统一走这里
final _log = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.dateAndTime,
  ),
);

enum LogTag { common, llm }

extension LogTagExt on LogTag {
  String get prefix {
    switch (this) {
      case LogTag.common:
        return 'jxd';
      case LogTag.llm:
        return 'jxd_llm';
    }
  }
}

void _logWithTag(LogTag tag, Level level, dynamic message, {dynamic error, StackTrace? stackTrace}) {
  final prefix = '[${tag.prefix}] ';
  final msg = message is Function ? message() : message;
  final fullMessage = prefix + msg.toString();

  print(fullMessage);
  // switch (level) {
  //   case Level.trace:
  //     _log.t(fullMessage, error: error, stackTrace: stackTrace);
  //   case Level.debug:
  //     _log.d(fullMessage, error: error, stackTrace: stackTrace);
  //   case Level.info:
  //     _log.i(fullMessage, error: error, stackTrace: stackTrace);
  //   case Level.warning:
  //     _log.w(fullMessage, error: error, stackTrace: stackTrace);
  //   case Level.error:
  //     _log.e(fullMessage, error: error, stackTrace: stackTrace);
  //   case Level.fatal:
  //     _log.f(fullMessage, error: error, stackTrace: stackTrace);
  //   default:
  //     _log.i(fullMessage, error: error, stackTrace: stackTrace);
  // }
}

/// 公共日志，前缀 jxd
class LogByCommon {
  static void d(dynamic message, {dynamic error, StackTrace? stackTrace}) =>
      _logWithTag(LogTag.common, Level.debug, message, error: error, stackTrace: stackTrace);
  static void e(dynamic message, {dynamic error, StackTrace? stackTrace}) =>
      _logWithTag(LogTag.common, Level.error, message, error: error, stackTrace: stackTrace);
}

/// LLM 相关日志，前缀 jxd_llm
class LogByLLM {
  static void d(dynamic message, {dynamic error, StackTrace? stackTrace}) =>
      _logWithTag(LogTag.llm, Level.debug, message, error: error, stackTrace: stackTrace);
  static void e(dynamic message, {dynamic error, StackTrace? stackTrace}) =>
      _logWithTag(LogTag.llm, Level.error, message, error: error, stackTrace: stackTrace);
}
