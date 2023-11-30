import 'package:exnota/src/note/capture.dart';
import 'package:exnota/src/note/data/id_generator.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'note.freezed.dart';

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

  VoiceNote._(
      {required this.id,
      this.title,
      required List<Capture> captures,
      required this.localData})
      : captures = List.unmodifiable(captures);

  VoiceNote copyAsCaptured() {
    final newLocalData = localData.copyWith(status: LocalStatus.captured);
    return _copyWith(localData: newLocalData);
  }

  VoiceNote copyAsSynced() {
    final newLocalData = localData.copyWith(status: LocalStatus.synced);
    return _copyWith(localData: newLocalData);
  }

  VoiceNote _copyWith({
    String? title,
    VoiceNoteLocalData? localData,
  }) {
    return VoiceNote._(
      id: id,
      title: title ?? this.title,
      captures: captures,
      localData: localData ?? this.localData,
    );
  }

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
    );
  }

  /// Accept notes from the database with no/minimal invariants checks.
  factory VoiceNote.fromDb(
      {required String id,
      String? title,
      required List<Capture> captures,
      required VoiceNoteLocalData localData}) {
    return VoiceNote._(
      id: id,
      title: title,
      captures: captures,
      localData: localData,
    );
  }

  @override
  Map<String, String?> toNonPrivateData() {
    return {
      "id": id,
      "type": typeAsString(),
      "localData": localData.toNonPrivateData().toString(),
      "captures":
          captures.map((capture) => capture.toNonPrivateData()).toString(),
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

  UnknownNote({
    required this.id,
    this.title,
    required this.captures,
  }) : localData = UnknownLocalData();

  @override
  Map<String, String?> toNonPrivateData() {
    return {
      "id": id,
      "type": typeAsString(),
      "localData": localData.toNonPrivateData().toString(),
      "captures":
          captures.map((capture) => capture.toNonPrivateData()).toString(),
    };
  }

  @override
  String typeAsString() {
    return runtimeType.toString();
  }
}

// TODO: Remove
@freezed
sealed class AudioNote with _$AudioNote {
  const factory AudioNote({
    required String path,
    required String transcription,
    String? url,
  }) = _AudioNote;
}
