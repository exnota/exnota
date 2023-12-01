sealed class Capture {
  final String id;
  final DateTime createdAt;

  Capture({
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

class AudioFileCapture extends Capture {
  final String? transcription;
  final String? url;

  AudioFileCapture({
    required String id,
    required DateTime createdAt,
    this.transcription,
    this.url,
  }) : super(id: id, createdAt: createdAt);

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

class UnknownCapture extends Capture {
  UnknownCapture({
    required String id,
    required DateTime createdAt,
  }) : super(id: id, createdAt: createdAt);

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
