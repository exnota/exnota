import 'package:exnota/src/note/capture.dart';
import 'package:exnota/src/note/data/id_generator.dart';

enum LocalStatus { capturing, captured, synced }

sealed class LocalData {
  abstract final LocalStatus status;

  String typeAsString();
  Map<String, String?> toNonPrivateData();
}

sealed class Note {
  abstract final String id;
  abstract final String? title;
  abstract final List<Capture> captures;
  abstract final LocalData localData;
  abstract final ({String? url}) integratedData;

  String typeAsString();
  Map<String, String?> toNonPrivateData();
}

class VoiceNoteLocalData implements LocalData {
  @override
  final LocalStatus status;

  final String? filePath;

  VoiceNoteLocalData({
    required this.filePath,
    required this.status,
  });

  VoiceNoteLocalData copyWith({
    LocalStatus? status,
  }) {
    return VoiceNoteLocalData(
      status: status ?? this.status,
      filePath: filePath,
    );
  }

  @override
  Map<String, String?> toNonPrivateData() {
    return {
      "filePath": filePath,
      "status": status.toString(),
    };
  }

  @override
  String typeAsString() {
    return runtimeType.toString();
  }
}

class VoiceNote extends Note {
  @override
  final String id;

  @override
  final String? title;

  @override
  final List<Capture> captures;

  @override
  final VoiceNoteLocalData localData;

  @override
  final ({String? url}) integratedData;

  /// To create a new object, use an appropriate factory instead of this
  /// constructor.
  VoiceNote._(
      {required this.id,
      this.title,
      required List<Capture> captures,
      required this.localData,
      required this.integratedData})
      : captures = List.unmodifiable(captures);

  // Local status  mutations

  VoiceNote copyAsCaptured() {
    final newLocalData = localData.copyWith(status: LocalStatus.captured);
    return _copyWith(localData: newLocalData);
  }

  VoiceNote copyAsSynced() {
    final newLocalData = localData.copyWith(status: LocalStatus.synced);
    return _copyWith(localData: newLocalData);
  }

  // Other mutations

  VoiceNote copyWithTitle({required String title}) {
    return _copyWith(title: title);
  }

  VoiceNote copyWithIntegratedUrl({String? url}) {
    return _copyWith(integratedData: (url: url));
  }

  // Factories

  factory VoiceNote.createCapturing({required String filePath}) {
    final id = generateId();
    final captureId = generateId();
    final capture = AudioFileCapture(id: captureId);
    final localData = VoiceNoteLocalData(
      filePath: filePath,
      status: LocalStatus.capturing,
    );
    return VoiceNote._(
      id: id,
      title: null,
      captures: [capture],
      localData: localData,
      integratedData: (url: null),
    );
  }

  /// Accept notes from the database with no/minimal invariants checks.
  factory VoiceNote.fromDb(
      {required String id,
      String? title,
      required List<Capture> captures,
      required VoiceNoteLocalData localData,
      required ({String? url}) integratedData}) {
    return VoiceNote._(
      id: id,
      title: title,
      captures: captures,
      localData: localData,
      integratedData: integratedData,
    );
  }

  // Mutation helpers

  VoiceNote _copyWith({
    String? title,
    VoiceNoteLocalData? localData,
    ({String? url})? integratedData,
  }) {
    return VoiceNote._(
      id: id,
      title: title ?? this.title,
      captures: captures,
      localData: localData ?? this.localData,
      integratedData: integratedData ?? this.integratedData,
    );
  }

  // Other abstract

  @override
  Map<String, String?> toNonPrivateData() {
    return {
      "id": id,
      "type": typeAsString(),
      "captures":
          captures.map((capture) => capture.toNonPrivateData()).toString(),
      "localData": localData.toNonPrivateData().toString(),
      "integratedData": integratedData.toString(),
    };
  }

  @override
  String typeAsString() {
    return runtimeType.toString();
  }
}

class UnknownLocalData implements LocalData {
  @override
  final LocalStatus status;

  UnknownLocalData({
    // Unknown notes should never be locally modified.
    this.status = LocalStatus.synced,
  });

  @override
  Map<String, String?> toNonPrivateData() {
    return {
      "status": status.toString(),
    };
  }

  @override
  String typeAsString() {
    return runtimeType.toString();
  }
}

class UnknownNote extends Note {
  @override
  final String id;

  @override
  final String? title;

  @override
  final List<Capture> captures;

  @override
  final LocalData localData;

  @override
  final ({String? url}) integratedData;

  /// To create a new object, use an appropriate factory instead of this
  /// constructor.
  UnknownNote._({
    required this.id,
    this.title,
    required this.captures,
    required this.integratedData,
  }) : localData = UnknownLocalData();

  // Factories

  /// Accept notes from the database with no/minimal invariants checks.
  factory UnknownNote.fromDb(
      {required String id,
      String? title,
      required List<Capture> captures,
      required ({String? url}) integratedData}) {
    return UnknownNote._(
      id: id,
      title: title,
      captures: captures,
      integratedData: integratedData,
    );
  }

  // Other abstract

  @override
  Map<String, String?> toNonPrivateData() {
    return {
      "id": id,
      "type": typeAsString(),
      "captures":
          captures.map((capture) => capture.toNonPrivateData()).toString(),
      "localData": localData.toNonPrivateData().toString(),
      "integratedData": integratedData.toString(),
    };
  }

  @override
  String typeAsString() {
    return runtimeType.toString();
  }
}
