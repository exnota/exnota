sealed class Capture {
  final String id;

  Capture({
    required this.id,
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
    this.transcription,
    this.url,
  }) : super(id: id);

  @override
  String typeAsString() {
    return runtimeType.toString();
  }

  @override
  Map<String, String?> toNonPrivateData() {
    return {
      "id": id,
      "type": typeAsString(),
    };
  }
}

class UnknownCapture extends Capture {
  UnknownCapture({
    required String id,
  }) : super(id: id);

  @override
  String typeAsString() {
    return runtimeType.toString();
  }

  @override
  Map<String, String?> toNonPrivateData() {
    return {
      "id": id,
      "type": typeAsString(),
    };
  }
}
