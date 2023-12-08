import 'dart:convert';

import 'package:exnota/src/lib/log/report.dart';
import 'package:logger/logger.dart' as l;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'logger.g.dart';

typedef WrappedLogger = l.Logger;

@riverpod
Logger logger(LoggerRef ref, [String? context]) {
  return Logger(context: context);
}

class Logger {
  final WrappedLogger logger;
  final String? context;

  Logger({this.context})
      : logger = WrappedLogger(printer: l.SimplePrinter(printTime: true));

  void info(String message, [dynamic data]) {
    // Use toString() to avoid needing to support .toJson() on all objects,
    // without which NoSuchMethodError will be thrown.
    logger.i({"message": _message(message), "data": _loggableData(data)});
  }

  void debug(String message, [dynamic data]) {
    // Use toString() to avoid needing to support .toJson() on all objects,
    // without which NoSuchMethodError will be thrown.
    logger.d({"message": _message(message), "data": _loggableData(data)});
  }

  // Don't attach PII or any personal information as we may in future
  // send this data to a third-party crash reporting service.
  void warn(String message, {dynamic nonPrivateData}) {
    logger.w({
      "message": _message(message),
      "nonPrivateData": _loggableData(nonPrivateData)
    });
    report(
        description: 'Warn: ${_message(message)}',
        nonPrivateData: nonPrivateData);
  }

  // Don't attach PII or any personal information as we may in future
  // send this data to a third-party crash reporting service.
  void error(String message, {dynamic nonPrivateData}) {
    logger.e({
      "message": _message(message),
      "nonPrivateData": _loggableData(nonPrivateData)
    });
    report(
        description: 'Error: ${_message(message)}',
        nonPrivateData: nonPrivateData);
  }

  String _message(String message) {
    return context == null ? message : '[$context] $message';
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
