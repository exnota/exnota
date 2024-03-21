import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

// This is the entrypoint of our custom linter
PluginBase createPlugin() => _ExampleLinter();

/// A plugin class is used to list all the assists/lints defined by a plugin.
class _ExampleLinter extends PluginBase {
  /// We list all the custom warnings/infos/errors
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        ExnotaUseClockRule(),
      ];
}

class ExnotaUseClockRule extends DartLintRule {
  ExnotaUseClockRule() : super(code: _code);

  static const _code = LintCode(
    name: 'exnota_use_clock',
    problemMessage: 'Use Clock().now() instead of DateTime.now()',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // This doesn't prevent the user using the `clock` pub.dev package instead
    // of the local clock.dart wrapper. That could be a different rule, perhaps.
    //
    // Some examples of adding quick fixes: https://github.com/invertase/dart_custom_lint/blob/main/packages/custom_lint/example/example_lint/lib/custom_lint_example_lint.dart
    context.registry.addConstructorName((node) {
      if (node.name?.name == 'now' && node.type.toString() == 'DateTime') {
        reporter.reportErrorForNode(code, node);
      }
    });
  }
}
