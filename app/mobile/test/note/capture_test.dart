import 'package:exnota/src/lib/optional.dart';
import 'package:exnota/src/note/capture.dart';
import 'package:flutter_test/flutter_test.dart';

Capture createUnknownCapture() {
  return UnknownCapture.fromDb(
    id: 'id',
    createdAt: DateTime.now(),
    localData: const UnknownCaptureLocalData(status: CaptureLocalStatus.synced),
  );
}

void main() {
  group('AudioFileCapture', () {
    group('fromDb', () {
      test('Should construct the expected object', () {
        final audioFileCapture = AudioFileCapture.fromDb(
          id: 'an id',
          createdAt: DateTime.utc(1809, DateTime.february, 12),
          filePath: const Optional('a file path'),
          transcription: const Optional('a transcription'),
          status: CaptureLocalStatus.captured,
        );
        expect(audioFileCapture.id, 'an id');
        expect(audioFileCapture.createdAt,
            DateTime.utc(1809, DateTime.february, 12));
        expect(audioFileCapture.localData.filePath, 'a file path');
        expect(audioFileCapture.localData.status, CaptureLocalStatus.captured);
        expect(audioFileCapture.transcription, 'a transcription');
      });
    });
    group('asAudioFileCapture', () {
      late Capture audioFileCapture;
      late Capture unknownCapture;

      setUp(() {
        audioFileCapture = AudioFileCapture.fromDb(
            id: 'id',
            createdAt: DateTime.now(),
            transcription: const Optional('a transcription'),
            filePath: const Optional('a file path'),
            status: CaptureLocalStatus.captured);
        unknownCapture = UnknownCapture.fromDb(
          id: 'id',
          createdAt: DateTime.now(),
          localData:
              const UnknownCaptureLocalData(status: CaptureLocalStatus.synced),
        );
      });
      test('Should return AudioFileCapture type if type is AudioFileCapture',
          () {
        expect(audioFileCapture.asAudioFileCapture(), isNot(null));
      });
      test('Should return null if type is not AudioFileCapture', () {
        expect(unknownCapture.asAudioFileCapture(), null);
      });
    });
    group('withFilePath', () {
      test('Should set the filePath', () {
        final capture = AudioFileCapture.fromDb(
          id: 'id',
          createdAt: DateTime.now(),
          transcription: const Optional('a transcription'),
          filePath: const Optional('a file path'),
          status: CaptureLocalStatus.captured,
        );
        final updatedCapture =
            capture.withFilePath(filePath: 'an updated file path');
        expect(updatedCapture.localData.filePath, 'an updated file path');
      });
    });
    group('withStatus', () {
      test('Should set the status', () {
        final capture = AudioFileCapture.fromDb(
          id: 'id',
          createdAt: DateTime.now(),
          transcription: const Optional('a transcription'),
          filePath: const Optional('a file path'),
          status: CaptureLocalStatus.captured,
        );
        final updatedCapture =
            capture.withStatus(status: CaptureLocalStatus.synced);
        expect(updatedCapture.localData.status, CaptureLocalStatus.synced);
      });
    });
    group('withTranscription', () {
      test('Should set the transcription', () {
        final capture = AudioFileCapture.fromDb(
          id: 'id',
          createdAt: DateTime.now(),
          transcription: const Optional('a transcription'),
          filePath: const Optional('a file path'),
          status: CaptureLocalStatus.captured,
        );
        final updatedCapture = capture.withTranscription(
            transcription: 'an updated transcription');
        expect(updatedCapture.transcription, 'an updated transcription');
      });
    });
    group('createEmptyCapturing', () {
      test('Should create an AudioFileCapture with the expected values', () {
        final capture = AudioFileCapture.createEmptyCapturing();
        expect(capture.id, isNotEmpty);
        expect(capture.createdAt, isNotNull);
        expect(capture.localData.status, CaptureLocalStatus.capturing);
        expect(capture.localData.filePath, isNull);
        expect(capture.transcription, isNull);
      });
    });
  });
  group('UnknownCapture', () {
    group('fromDb', () {
      test('Should construct the expected object', () {
        const localData =
            UnknownCaptureLocalData(status: CaptureLocalStatus.captured);
        final unknownCapture = UnknownCapture.fromDb(
          id: 'an id',
          createdAt: DateTime.utc(1809, DateTime.february, 12),
          localData: localData,
        );
        expect(unknownCapture.id, 'an id');
        expect(unknownCapture.createdAt,
            DateTime.utc(1809, DateTime.february, 12));
        expect(unknownCapture.localData, localData);
      });
    });
  });
}
