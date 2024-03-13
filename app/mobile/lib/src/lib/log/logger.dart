import 'dart:convert';

import 'package:exnota/src/lib/log/report.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart' as l;
import 'package:logger/logger.dart';
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
      : logger = WrappedLogger(
            printer: CustomSimplePrinter(
          printTime: true,
          // Colors don't work on macOS and cause artifacts: https://pub.dev/packages/logger#colors
          colors: false,
        ));

  void info(String message, [dynamic data]) {
    // Use toString() to avoid needing to support .toJson() on all objects,
    // without which NoSuchMethodError will be thrown.
    logger.i({'message': _message(message), 'data': _loggableData(data)});
  }

  void debug(String message, [dynamic data]) {
    // Use toString() to avoid needing to support .toJson() on all objects,
    // without which NoSuchMethodError will be thrown.
    logger.d({'message': _message(message), 'data': _loggableData(data)});
  }

  // Don't attach PII or any personal information as we may in future
  // send this data to a third-party crash reporting service.
  void warn(String message, {dynamic nonPrivateData, Object? error}) {
    logger.w(
        {'message': _message(message), 'data': _loggableData(nonPrivateData)},
        error: error);
    report(
        description: 'Warn: ${_message(message)}',
        nonPrivateData: {'data': nonPrivateData, 'error': error});
  }

  // Don't attach PII or any personal information as we may in future
  // send this data to a third-party crash reporting service.
  void error(String message,
      {dynamic nonPrivateData, Error? error, Object? exception}) {
    logger.e(
        {'message': _message(message), 'data': _loggableData(nonPrivateData)},
        error: error);
    report(
        description: 'Error: ${_message(message)}',
        nonPrivateData: {'data': nonPrivateData, 'error': error});
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

// Modified version of SimplePrinter from logger package
class CustomSimplePrinter extends LogPrinter {
  final DateFormat _format = DateFormat('H:m:s');

  static final levelPrefixes = {
    Level.trace: '[T]',
    Level.debug: '[D]',
    Level.info: '[I]',
    Level.warning: '[W]',
    Level.error: '[E]',
    Level.fatal: '[FATAL]',
  };

  static final levelColors = {
    Level.trace: AnsiColor.fg(AnsiColor.grey(0.5)),
    Level.debug: const AnsiColor.none(),
    Level.info: const AnsiColor.fg(12),
    Level.warning: const AnsiColor.fg(208),
    Level.error: const AnsiColor.fg(196),
    Level.fatal: const AnsiColor.fg(199),
  };

  final bool printTime;
  final bool colors;

  CustomSimplePrinter({this.printTime = false, this.colors = true});

  @override
  List<String> log(LogEvent event) {
    var messageStr = _stringifyMessage(event.message);
    var errorStr = event.error != null ? '  ERROR: ${event.error}' : '';
    var timeStr = printTime ? _formatTime(event.time) : '';
    var eventStr = _labelFor(event.level);
    return ['$eventStr $timeStr $messageStr$errorStr'];
  }

  String _formatTime(DateTime time) {
    return '${_format.format(time)}.${time.millisecond}';
  }

  String _labelFor(Level level) {
    var prefix = levelPrefixes[level]!;
    var color = levelColors[level]!;

    return colors ? color(prefix) : prefix;
  }

  String _stringifyMessage(dynamic message) {
    final finalMessage = message is Function ? message() : message;
    if (finalMessage is Map && finalMessage['message'] != null) {
      final data = finalMessage['data'];
      if (data != null) {
        return '${finalMessage["message"]} ${jsonEncode(data)}';
      }
      return '${finalMessage["message"]}';
    } else if (finalMessage is Map || finalMessage is Iterable) {
      var encoder = const JsonEncoder.withIndent(null);
      return encoder.convert(finalMessage);
    } else {
      return finalMessage.toString();
    }
  }
}
