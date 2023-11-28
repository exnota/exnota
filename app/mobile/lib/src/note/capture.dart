sealed class Capture {
  final String id;

  Capture({
    required this.id,
  });
}

class AudioFileCapture extends Capture {
  final String? transcription;
  final String? url;

  AudioFileCapture({
    required String id,
    this.transcription,
    this.url,
  }) : super(id: id);
}
