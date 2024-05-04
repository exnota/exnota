import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notion_auth.g.dart';
part 'notion_auth.freezed.dart';

enum NotionAuthStatus { none, waitingForCode }

@freezed
class NotionAuth with _$NotionAuth {
  const factory NotionAuth({
    required NotionAuthStatus status,
  }) = _NotionAuth;
}

@riverpod
NotionAuth notionAuth(NotionAuthRef ref) {
  return const NotionAuth(status: NotionAuthStatus.none);
}
