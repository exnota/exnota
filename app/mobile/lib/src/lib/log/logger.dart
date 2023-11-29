import 'dart:convert';

import 'package:logger/logger.dart' as l;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'logger.g.dart';

typedef WrappedLogger = l.Logger;

@riverpod
Logger logger(LoggerRef ref) {
  return Logger();
}

class Logger {
  final WrappedLogger logger;

  Logger() : logger = WrappedLogger(printer: l.SimplePrinter(printTime: true));

  void info(String message, [dynamic data]) {
    // Use toString() to avoid needing to support .toJson() on all objects,
    // without which NoSuchMethodError will be thrown.
    logger.i({"message": message, "data": _loggableData(data)});
  }

  void debug(String message, [dynamic data]) {
    // Use toString() to avoid needing to support .toJson() on all objects,
    // without which NoSuchMethodError will be thrown.
    logger.d({"message": message, "data": _loggableData(data)});
  }

  void warn(String message, [dynamic data]) {
    logger.w({"message": message, "data": _loggableData(data)});
  }

  // Don't attach PII or any personal information as we may in future
  // send this data to a third-party crash reporting service.
  void error(String message, {dynamic nonPrivateData}) {
    // TODO: Send report to some crash report service
    logger.e(
        {"message": message, "nonPrivateData": _loggableData(nonPrivateData)});
  }

  dynamic _loggableData(dynamic data) {
    try {
      json.encode(data);
      return data;
    } catch (e) {
      return data.toString();
    }
  }
}
