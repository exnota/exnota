import 'package:exnota/src/note/capture.dart';
import 'package:exnota/src/note/data/id_generator.dart';

enum NoteLocalStatus { capturing, captured, synced }

sealed class Note {
  abstract final String id;
  abstract final String? title;
  abstract final List<Capture> captures;
  abstract final NoteLocalData localData;
  abstract final ({String? url}) integratedData;
  abstract final DateTime createdAt;

  String typeAsString();
  Map<String, String?> toNonPrivateData();
}

sealed class NoteLocalData {
  abstract final NoteLocalStatus status;

  String typeAsString();
  Map<String, String?> toNonPrivateData();
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

  @override
  final DateTime createdAt;

  /// To create a new object, use an appropriate factory instead of this
  /// constructor.
  VoiceNote._(
      {required this.id,
      this.title,
      required List<Capture> captures,
      required this.integratedData,
      required this.createdAt})
      : captures = List.unmodifiable(captures),
        localData = VoiceNoteLocalData(
          // Derive status from captures.
          status: captures.fold(NoteLocalStatus.synced, (status, capture) {
            // If at least one is capturing, the whole note is capturing.
            if (capture.localData.status == CaptureLocalStatus.capturing) {
              return NoteLocalStatus.capturing;
            }

            // If none are capturing and at least one is captured, the whole
            // note is captured.
            if (status != NoteLocalStatus.capturing &&
                capture.localData.status == CaptureLocalStatus.captured) {
              return NoteLocalStatus.captured;
            }
            return status;
          }),
        );

  // Local status mutations

  VoiceNote withCaptured({required String captureId}) {
    if (captures.every((capture) => capture.id != captureId)) {
      throw ArgumentError("No capture with id $captureId");
    }
    final updatedCaptures = captures.map((capture) {
      if (capture.id == captureId) {
        if (capture is! AudioFileCapture) {
          throw ArgumentError("Cannot set file path on non-audio capture");
        }
        return capture.withStatus(status: CaptureLocalStatus.captured);
      }
      return capture;
    }).toList();
    return _copyWith(captures: updatedCaptures);
  }

  VoiceNote withSynced({required String captureId}) {
    if (captures.every((capture) => capture.id != captureId)) {
      throw ArgumentError("No capture with id $captureId");
    }
    final updatedCaptures = captures.map((capture) {
      if (capture.id == captureId) {
        if (capture is! AudioFileCapture) {
          throw ArgumentError("Cannot set file path on non-audio capture");
        }
        return capture.withStatus(status: CaptureLocalStatus.synced);
      }
      return capture;
    }).toList();
    return _copyWith(captures: updatedCaptures);
  }

  // Other mutations

  VoiceNote withIntegratedUrl({String? url}) {
    return _copyWith(integratedData: (url: url));
  }

  VoiceNote withFilePath(
      {required String captureId, required String filePath}) {
    if (captures.every((capture) => capture.id != captureId)) {
      throw ArgumentError("No capture with id $captureId");
    }
    final updatedCaptures = captures.map((capture) {
      if (capture.id == captureId) {
        if (capture is! AudioFileCapture) {
          throw ArgumentError("Cannot set file path on non-audio capture");
        }
        return capture.withFilePath(filePath: filePath);
      }
      return capture;
    }).toList();
    return _copyWith(captures: updatedCaptures);
  }

  VoiceNote withTranscription(
      {required String captureId, required String transcription}) {
    if (captures.every((capture) => capture.id != captureId)) {
      throw ArgumentError("No capture with id $captureId");
    }
    final updatedCaptures = captures.map((capture) {
      if (capture.id == captureId) {
        if (capture is! AudioFileCapture) {
          throw ArgumentError("Cannot set file path on non-audio capture");
        }
        return capture.withTranscription(transcription: transcription);
      }
      return capture;
    }).toList();

    final title = this.title ?? transcription;
    return _copyWith(title: title, captures: updatedCaptures);
  }

  // Factories

  factory VoiceNote.createCapturing() {
    final id = generateId();
    final capture = AudioFileCapture.createEmptyCapturing();
    return VoiceNote._(
      id: id,
      title: null,
      captures: [capture],
      integratedData: (url: null),
      createdAt: capture.createdAt,
    );
  }

  /// Accept notes from the database with no/minimal invariants checks.
  factory VoiceNote.fromDb(
      {required String id,
      String? title,
      required List<Capture> captures,
      required ({String? url}) integratedData,
      required DateTime createdAt}) {
    return VoiceNote._(
        id: id,
        title: title,
        captures: captures,
        integratedData: integratedData,
        createdAt: createdAt);
  }

  // Mutation helpers

  VoiceNote _copyWith({
    String? title,
    ({String? url})? integratedData,
    List<Capture>? captures,
  }) {
    return VoiceNote._(
        id: id,
        title: title ?? this.title,
        captures: captures ?? this.captures.toList(),
        integratedData: integratedData ?? this.integratedData,
        createdAt: createdAt);
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

class VoiceNoteLocalData implements NoteLocalData {
  @override
  final NoteLocalStatus status;

  VoiceNoteLocalData({
    required this.status,
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceNoteLocalData &&
          runtimeType == other.runtimeType &&
          status == other.status;

  @override
  int get hashCode => Object.hash(runtimeType, status);
}

class UnknownNote extends Note {
  @override
  final String id;

  @override
  final String? title;

  @override
  final List<Capture> captures;

  @override
  final NoteLocalData localData;

  @override
  final ({String? url}) integratedData;

  @override
  final DateTime createdAt;

  /// To create a new object, use an appropriate factory instead of this
  /// constructor.
  UnknownNote._(
      {required this.id,
      this.title,
      required this.captures,
      required this.integratedData,
      required this.createdAt})
      : localData = UnknownLocalData();

  // Factories

  /// Accept notes from the database with no/minimal invariants checks.
  factory UnknownNote.fromDb({
    required String id,
    String? title,
    required List<Capture> captures,
    required ({String? url}) integratedData,
    required DateTime createdAt,
  }) {
    return UnknownNote._(
      id: id,
      title: title,
      captures: captures,
      integratedData: integratedData,
      createdAt: createdAt,
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

class UnknownLocalData implements NoteLocalData {
  @override
  final NoteLocalStatus status;

  UnknownLocalData({
    // Unknown notes should never be locally modified.
    this.status = NoteLocalStatus.synced,
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
