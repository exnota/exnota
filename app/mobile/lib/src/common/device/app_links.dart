import 'package:app_links/app_links.dart' as app_links;
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'app_links.g.dart';

@Riverpod(keepAlive: true)
class AppLinks extends _$AppLinks {
  @override
  app_links.AppLinks build() {
    return app_links.AppLinks();
  }
}
