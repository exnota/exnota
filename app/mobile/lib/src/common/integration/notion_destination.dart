// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'notion_destination.freezed.dart';
part 'notion_destination.g.dart';

@freezed
class Destinations with _$Destinations {
  const factory Destinations({
    @JsonKey(name: 'notion') List<NotionDestination>? notion,
  }) = _Destinations;

  const Destinations._();

  factory Destinations.fromJson(Map<String, dynamic> json) =>
      _$DestinationsFromJson(json);
}

@freezed
class NotionDestination with _$NotionDestination {
  const factory NotionDestination({
    @JsonKey(name: 'name') required String name,
    @JsonKey(name: 'object') required NotionObject object,
    @JsonKey(name: 'icon') NotionIcon? icon,
  }) = _NotionDestination;

  const NotionDestination._();

  factory NotionDestination.fromJson(Map<String, dynamic> json) =>
      _$NotionDestinationFromJson(json);
}

@freezed
class NotionObject with _$NotionObject {
  const factory NotionObject({
    @JsonKey(name: 'id') required String id,
    @JsonKey(name: 'object') required NotionObjectType object,
  }) = _NotionObject;

  const NotionObject._();

  factory NotionObject.fromJson(Map<String, dynamic> json) =>
      _$NotionObjectFromJson(json);
}

enum NotionObjectType {
  @JsonValue('page')
  page,
  @JsonValue('database')
  database,
}

@freezed
class NotionIcon with _$NotionIcon {
  const factory NotionIcon({
    @JsonKey(name: 'type') required IconType type,
    @JsonKey(name: 'emoji') String? emoji,
    @JsonKey(name: 'url') String? url,
  }) = _NotionIcon;

  const NotionIcon._();

  factory NotionIcon.fromJson(Map<String, dynamic> json) =>
      _$NotionIconFromJson(json);
}

enum IconType {
  @JsonValue('emoji')
  emoji,
  @JsonValue('url')
  url,
}
