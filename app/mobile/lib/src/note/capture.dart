import 'package:exnota/src/note/data/id_generator.dart';
import 'package:exnota/src/lib/optional.dart';
import 'package:flutter/material.dart';

enum CaptureLocalStatus { capturing, captured, synced }

@immutable
sealed class Capture {
  final String id;
  final DateTime createdAt;
  abstract final CaptureLocalData localData;

  const Capture({
    required this.id,
    required this.createdAt,
  });

  String typeAsString();
  Map<String, String?> toNonPrivateData();

  // Type helpers

  AudioFileCapture? asAudioFileCapture() {
    if (this is AudioFileCapture) {
      return this as AudioFileCapture;
    }
    return null;
  }
}

@immutable
sealed class CaptureLocalData {
  abstract final CaptureLocalStatus status;
  Map<String, String?> toNonPrivateData();
}

@immutable
class AudioFileCapture extends Capture {
  final String? transcription;

  @override
  final AudioFileCaptureLocalData localData;

  AudioFileCapture._({
    required String id,
    required DateTime createdAt,
    required Optional<String> transcription,
    required this.localData,
  })  : transcription = transcription.value,
        super(id: id, createdAt: createdAt);

  // Local status mutations

  AudioFileCapture withFilePath({required String filePath}) {
    return AudioFileCapture._(
      id: id,
      createdAt: createdAt,
      transcription: Optional(transcription),
      localData: AudioFileCaptureLocalData(
          status: localData.status, filePath: Optional(filePath)),
    );
  }

  AudioFileCapture withStatus({required CaptureLocalStatus status}) {
    return AudioFileCapture._(
      id: id,
      createdAt: createdAt,
      transcription: Optional(transcription),
      localData: AudioFileCaptureLocalData(
          status: status, filePath: Optional(localData.filePath)),
    );
  }

  AudioFileCapture withTranscription({required String transcription}) {
    return AudioFileCapture._(
      id: id,
      createdAt: createdAt,
      transcription: Optional(transcription),
      localData: localData,
    );
  }

  // Factories

  AudioFileCapture.createEmptyCapturing()
      : this._(
          id: generateId(),
          createdAt: DateTime.now(),
          transcription: Optional.empty(),
          localData: AudioFileCaptureLocalData(
              status: CaptureLocalStatus.capturing, filePath: Optional.empty()),
        );

  AudioFileCapture.fromDb({
    required String id,
    required DateTime createdAt,
    required Optional<String> transcription,
    required Optional<String> filePath,
    required CaptureLocalStatus status,
  }) : this._(
          id: id,
          createdAt: createdAt,
          transcription: transcription,
          localData:
              AudioFileCaptureLocalData(status: status, filePath: filePath),
        );

  // Other abstract

  @override
  Map<String, String?> toNonPrivateData() {
    return {
      "id": id,
      "createdAt": createdAt.toString(),
      "type": typeAsString(),
      "localData": localData.toNonPrivateData().toString(),
    };
  }

  @override
  String typeAsString() {
    return runtimeType.toString();
  }
}

@immutable
class AudioFileCaptureLocalData implements CaptureLocalData {
  @override
  final CaptureLocalStatus status;

  // Initially empty because the path includes the capture ID, which is not
  // known until the capture is created.
  final String? filePath;

  AudioFileCaptureLocalData({
    required this.status,
    required Optional<String> filePath,
  }) : filePath = filePath.value;

  @override
  Map<String, String?> toNonPrivateData() {
    return {
      "filePath": filePath,
    };
  }
}

@immutable
class UnknownCapture extends Capture {
  @override
  final UnknownCaptureLocalData localData;

  const UnknownCapture._({
    required String id,
    required DateTime createdAt,
    required this.localData,
  }) : super(id: id, createdAt: createdAt);

  // Factories

  const UnknownCapture.fromDb({
    required String id,
    required DateTime createdAt,
    required UnknownCaptureLocalData localData,
  }) : this._(
          id: id,
          createdAt: createdAt,
          localData: localData,
        );

  // Other abstract

  @override
  String typeAsString() {
    return runtimeType.toString();
  }

  @override
  Map<String, String?> toNonPrivateData() {
    return {
      "id": id,
      "type": typeAsString(),
      "createdAt": createdAt.toString(),
    };
  }
}

@immutable
class UnknownCaptureLocalData implements CaptureLocalData {
  @override
  final CaptureLocalStatus status;

  const UnknownCaptureLocalData({
    required this.status,
  });

  @override
  Map<String, String?> toNonPrivateData() {
    return {};
  }
}
