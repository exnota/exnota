import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

// This is the entrypoint of our custom linter
PluginBase createPlugin() => _ExampleLinter();

/// A plugin class is used to list all the assists/lints defined by a plugin.
class _ExampleLinter extends PluginBase {
  /// We list all the custom warnings/infos/errors
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        ExnotaUseClockNowRule(),
        ExnotaUseCustomClock(),
      ];
}

class ExnotaUseClockNowRule extends DartLintRule {
  ExnotaUseClockNowRule() : super(code: _code);

  static const _code = LintCode(
    name: 'exnota_use_clock_now',
    problemMessage: 'Use Clock().now() instead of DateTime.now()',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Some examples of adding quick fixes: https://github.com/invertase/dart_custom_lint/blob/main/packages/custom_lint/example/example_lint/lib/custom_lint_example_lint.dart
    context.registry.addConstructorName((node) {
      if (node.name?.name == 'now' && node.type.toString() == 'DateTime') {
        reporter.reportErrorForNode(code, node);
      }
    });
  }
}

class ExnotaUseCustomClock extends DartLintRule {
  ExnotaUseCustomClock() : super(code: _code);

  static const _code = LintCode(
    name: 'exnota_use_custom_clock',
    problemMessage:
        'Use custom lib/clock.dart instead of clock/clock from pub.dev',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Some examples of adding quick fixes: https://github.com/invertase/dart_custom_lint/blob/main/packages/custom_lint/example/example_lint/lib/custom_lint_example_lint.dart
    context.registry.addImportDirective((node) {
      if (node.uri.stringValue == 'package:clock/clock.dart') {
        reporter.reportErrorForNode(code, node);
      }
    });
  }
}
