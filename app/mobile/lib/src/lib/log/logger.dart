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

  void info(String message, dynamic data) {
    logger.i({"message": message, "data": data});
  }

  void debug(String message, dynamic obj) {
    logger.d({"message": message, "data": obj});
  }

  void warn(String message, dynamic obj) {
    logger.w({"message": message, "data": obj});
  }

  void error(String message, dynamic obj) {
    logger.e({"message": message, "data": obj});
  }
}
