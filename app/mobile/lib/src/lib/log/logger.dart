import 'package:logger/logger.dart' as l show Logger;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'logger.g.dart';

typedef WrappedLogger = l.Logger;

@riverpod
Logger logger(LoggerRef ref) {
  return Logger();
}

class Logger {
  final WrappedLogger logger;

  Logger() : logger = WrappedLogger();

  void info(String message, [dynamic data]) {
    logger.i({"message": message, "data": data});
  }

  void debug(String message, [dynamic data]) {
    logger.d({"message": message, "data": data});
  }

  void warn(String message, [dynamic data]) {
    logger.w({"message": message, "data": data});
  }

  void error(String message, [dynamic data]) {
    logger.e({"message": message, "data": data});
  }
}
