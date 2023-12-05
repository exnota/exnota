import 'package:exnota/src/lib/optional.dart';
import 'package:exnota/src/note/capture.dart';
import 'package:exnota/src/note/note.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VoiceNote', () {
    group('withCaptured', () {
      group('Given a note with two captures', () {
        late VoiceNote initial;

        setUp(() {
          final capture1 = AudioFileCapture.fromDb(
              id: 'id1',
              createdAt: DateTime.utc(1809, DateTime.february, 12),
              transcription: const Optional('a transcription'),
              filePath: const Optional('a file path'),
              status: CaptureLocalStatus.capturing);
          final capture2 = AudioFileCapture.fromDb(
              id: 'id2',
              createdAt: DateTime.utc(1879, DateTime.march, 14),
              transcription: const Optional('a transcription 2'),
              filePath: const Optional('a file path 2'),
              status: CaptureLocalStatus.captured);
          initial = VoiceNote.fromDb(
              id: 'an id',
              captures: [capture1, capture2],
              integratedData: (url: 'a url'),
              createdAt: DateTime.utc(1809, DateTime.february, 12),
              title: 'a title');
        });

        test('Then the given capture\'s status is updated', () {
          final updated = initial.withCaptured(captureId: 'id1');
          expect(updated.captures[0] is AudioFileCapture, true);
          expect(updated.captures[0].asAudioFileCapture()?.id, 'id1');
          expect(updated.captures[0].asAudioFileCapture()?.localData.status,
              CaptureLocalStatus.captured);
          expect(updated.captures[1] is AudioFileCapture, true);
          expect(updated.captures[1].asAudioFileCapture()?.id, 'id2');
          expect(updated.captures[1].asAudioFileCapture()?.localData.status,
              CaptureLocalStatus.captured);
        });
        test('Then the note\'s derived status is updated', () {
          expect(initial.localData.status, NoteLocalStatus.capturing);

          final updated = initial.withCaptured(captureId: 'id1');
          expect(updated.localData.status, NoteLocalStatus.captured);
        });
      });
    });
    group('withSynced', () {
      group('Given a note with two captures', () {
        late VoiceNote initial;

        setUp(() {
          final capture1 = AudioFileCapture.fromDb(
              id: 'id1',
              createdAt: DateTime.utc(1809, DateTime.february, 12),
              transcription: const Optional('a transcription'),
              filePath: const Optional('a file path'),
              status: CaptureLocalStatus.captured);
          final capture2 = AudioFileCapture.fromDb(
              id: 'id2',
              createdAt: DateTime.utc(1879, DateTime.march, 14),
              transcription: const Optional('a transcription 2'),
              filePath: const Optional('a file path 2'),
              status: CaptureLocalStatus.synced);
          initial = VoiceNote.fromDb(
              id: 'an id',
              captures: [capture1, capture2],
              integratedData: (url: 'a url'),
              createdAt: DateTime.utc(1809, DateTime.february, 12),
              title: 'a title');
        });
        test('Then the given capture\'s status is updated', () {
          final updated = initial.withSynced(captureId: 'id1');
          expect(updated.captures[0] is AudioFileCapture, true);
          expect(updated.captures[0].asAudioFileCapture()?.id, 'id1');
          expect(updated.captures[0].asAudioFileCapture()?.localData.status,
              CaptureLocalStatus.synced);
          expect(updated.captures[1] is AudioFileCapture, true);
          expect(updated.captures[1].asAudioFileCapture()?.id, 'id2');
          expect(updated.captures[1].asAudioFileCapture()?.localData.status,
              CaptureLocalStatus.synced);
        });
        test('Then the note\'s derived status is updated', () {
          expect(initial.localData.status, NoteLocalStatus.captured);

          final updated = initial.withSynced(captureId: 'id1');
          expect(updated.localData.status, NoteLocalStatus.synced);
        });
      });
    });
    group('withFilePath', () {
      test('Should return a copy with only the capture\'s file path modified',
          () {
        final capture1 = AudioFileCapture.fromDb(
            id: 'id1',
            createdAt: DateTime.utc(1809, DateTime.february, 12),
            transcription: const Optional('a transcription'),
            filePath: const Optional('a file path'),
            status: CaptureLocalStatus.synced);
        final capture2 = AudioFileCapture.fromDb(
            id: 'id2',
            createdAt: DateTime.utc(1879, DateTime.march, 14),
            transcription: const Optional('a transcription 2'),
            filePath: const Optional('a file path 2'),
            status: CaptureLocalStatus.synced);
        final initial = VoiceNote.fromDb(
            id: 'an id',
            captures: [capture1, capture2],
            integratedData: (url: 'a url'),
            createdAt: DateTime.utc(1809, DateTime.february, 12),
            title: 'a title');
        final updated = initial.withFilePath(
            captureId: 'id1', filePath: 'an updated file path');

        expect(updated.id, initial.id);
        expect(updated.captures[0] is AudioFileCapture, true);
        expect(updated.captures[0].asAudioFileCapture()?.id, 'id1');
        expect(updated.captures[0].asAudioFileCapture()?.localData.filePath,
            'an updated file path');
        expect(updated.captures[1] is AudioFileCapture, true);
        expect(updated.captures[1].asAudioFileCapture()?.id, 'id2');
        expect(updated.captures[1].asAudioFileCapture()?.localData.filePath,
            'a file path 2');
      });
      test('Should throw if the capture for the ID is not an AudioFileCapture',
          () {
        final capture1 = AudioFileCapture.fromDb(
            id: 'id1',
            createdAt: DateTime.utc(1809, DateTime.february, 12),
            transcription: const Optional('a transcription'),
            filePath: const Optional('a file path'),
            status: CaptureLocalStatus.synced);
        final capture2 = UnknownCapture.fromDb(
            id: 'id2',
            createdAt: DateTime.utc(1879, DateTime.march, 14),
            localData: const UnknownCaptureLocalData(
                status: CaptureLocalStatus.synced));
        final initial = VoiceNote.fromDb(
            id: 'an id',
            captures: [capture1, capture2],
            integratedData: (url: 'a url'),
            createdAt: DateTime.utc(1809, DateTime.february, 12),
            title: 'a title');

        expect(() => initial.withFilePath(captureId: 'id2', filePath: 'a path'),
            throwsArgumentError);
      });
      test('Should throw if the capture ID is not found', () {
        final capture1 = AudioFileCapture.fromDb(
            id: 'id1',
            createdAt: DateTime.utc(1809, DateTime.february, 12),
            transcription: const Optional('a transcription'),
            filePath: const Optional('a file path'),
            status: CaptureLocalStatus.synced);
        final capture2 = AudioFileCapture.fromDb(
            id: 'id2',
            createdAt: DateTime.utc(1879, DateTime.march, 14),
            transcription: const Optional('a transcription 2'),
            filePath: const Optional('a file path 2'),
            status: CaptureLocalStatus.synced);
        final initial = VoiceNote.fromDb(
            id: 'an id',
            captures: [capture1, capture2],
            integratedData: (url: 'a url'),
            createdAt: DateTime.utc(1809, DateTime.february, 12),
            title: 'a title');

        expect(() => initial.withFilePath(captureId: 'id3', filePath: 'a path'),
            throwsArgumentError);
      });
    });
    group('withIntegratedUrl', () {
      test('Should return a copy with the integrated URL modified', () {
        final initial = VoiceNote.fromDb(
            id: 'an id',
            captures: [],
            integratedData: (url: 'a url'),
            createdAt: DateTime.utc(1809, DateTime.february, 12),
            title: 'a title');

        final updated = initial.withIntegratedUrl(url: 'an updated url');
        expect(updated.id, initial.id);
        expect(updated.integratedData, (url: 'an updated url'));
      });
    });
    group('withTranscription', () {
      group('Given a note that does not have it\'s title set', () {
        late VoiceNote initial;
        setUp(() {
          initial = VoiceNote.fromDb(
              id: 'an id',
              captures: [
                AudioFileCapture.fromDb(
                    id: 'a capture id',
                    createdAt: DateTime.utc(1809, DateTime.february, 12),
                    transcription: Optional.empty(),
                    filePath: const Optional('a file path'),
                    status: CaptureLocalStatus.synced)
              ],
              integratedData: (url: 'a url'),
              createdAt: DateTime.utc(1809, DateTime.february, 12),
              title: null);
        });
        test('Then the capture\'s transcription is updated', () {
          final updated = initial.withTranscription(
              captureId: 'a capture id',
              transcription: 'an updated transcription');
          expect(updated.captures[0].asAudioFileCapture()?.transcription,
              'an updated transcription');
        });
        test('Then the note\'s title is updated', () {
          final updated = initial.withTranscription(
              captureId: 'a capture id',
              transcription: 'an updated transcription');
          expect(updated.title, 'an updated transcription');
        });
      });
    });
    group('createCapturing', () {
      test('Creates a note with capturing status', () {
        final note = VoiceNote.createCapturing();
        expect(note.localData.status, NoteLocalStatus.capturing);
      });
    });
    group('fromDb', () {
      group('Given a note with two captures', () {
        group('and their statuses are both capturing', () {
          test('Then the note\'s status is capturing', () {
            final capture1 = AudioFileCapture.fromDb(
                id: 'id1',
                createdAt: DateTime.utc(1809, DateTime.february, 12),
                transcription: const Optional('a transcription'),
                filePath: const Optional('a file path'),
                status: CaptureLocalStatus.capturing);
            final capture2 = AudioFileCapture.fromDb(
                id: 'id2',
                createdAt: DateTime.utc(1879, DateTime.march, 14),
                transcription: const Optional('a transcription 2'),
                filePath: const Optional('a file path 2'),
                status: CaptureLocalStatus.capturing);
            final note = VoiceNote.fromDb(
                id: 'an id',
                captures: [capture1, capture2],
                integratedData: (url: 'a url'),
                createdAt: DateTime.utc(1809, DateTime.february, 12),
                title: 'a title');
            expect(note.localData.status, NoteLocalStatus.capturing);
          });
        });
        group('and their statuses are captured, and capturing', () {
          test('Then the note\'s status is capturing', () {
            final capture1 = AudioFileCapture.fromDb(
                id: 'id1',
                createdAt: DateTime.utc(1809, DateTime.february, 12),
                transcription: const Optional('a transcription'),
                filePath: const Optional('a file path'),
                status: CaptureLocalStatus.capturing);
            final capture2 = AudioFileCapture.fromDb(
                id: 'id2',
                createdAt: DateTime.utc(1879, DateTime.march, 14),
                transcription: const Optional('a transcription 2'),
                filePath: const Optional('a file path 2'),
                status: CaptureLocalStatus.captured);
            final note = VoiceNote.fromDb(
                id: 'an id',
                captures: [capture1, capture2],
                integratedData: (url: 'a url'),
                createdAt: DateTime.utc(1809, DateTime.february, 12),
                title: 'a title');
            expect(note.localData.status, NoteLocalStatus.capturing);
          });
        });
        group('and their statuses are captured, and synced', () {
          test('Then the note\'s status is captured', () {
            final capture1 = AudioFileCapture.fromDb(
                id: 'id1',
                createdAt: DateTime.utc(1809, DateTime.february, 12),
                transcription: const Optional('a transcription'),
                filePath: const Optional('a file path'),
                status: CaptureLocalStatus.captured);
            final capture2 = AudioFileCapture.fromDb(
                id: 'id2',
                createdAt: DateTime.utc(1879, DateTime.march, 14),
                transcription: const Optional('a transcription 2'),
                filePath: const Optional('a file path 2'),
                status: CaptureLocalStatus.synced);
            final note = VoiceNote.fromDb(
                id: 'an id',
                captures: [capture1, capture2],
                integratedData: (url: 'a url'),
                createdAt: DateTime.utc(1809, DateTime.february, 12),
                title: 'a title');
            expect(note.localData.status, NoteLocalStatus.captured);
          });
        });
        group('and their statuses are both synced', () {
          test('Then the note\'s status is synced', () {
            final capture1 = AudioFileCapture.fromDb(
                id: 'id1',
                createdAt: DateTime.utc(1809, DateTime.february, 12),
                transcription: const Optional('a transcription'),
                filePath: const Optional('a file path'),
                status: CaptureLocalStatus.synced);
            final capture2 = AudioFileCapture.fromDb(
                id: 'id2',
                createdAt: DateTime.utc(1879, DateTime.march, 14),
                transcription: const Optional('a transcription 2'),
                filePath: const Optional('a file path 2'),
                status: CaptureLocalStatus.synced);
            final note = VoiceNote.fromDb(
                id: 'an id',
                captures: [capture1, capture2],
                integratedData: (url: 'a url'),
                createdAt: DateTime.utc(1809, DateTime.february, 12),
                title: 'a title');
            expect(note.localData.status, NoteLocalStatus.synced);
          });
        });
      });
      test('Should construct the expected object', () {
        final captures = [
          AudioFileCapture.fromDb(
            id: 'id',
            createdAt: DateTime.now(),
            transcription: const Optional('a transcription'),
            filePath: const Optional('a file path'),
            status: CaptureLocalStatus.captured,
          ),
          AudioFileCapture.fromDb(
            id: 'id2',
            createdAt: DateTime.now(),
            transcription: const Optional('a transcription 2'),
            filePath: const Optional('a file path 2'),
            status: CaptureLocalStatus.capturing,
          ),
        ];
        final voiceNote = VoiceNote.fromDb(
          id: 'an id',
          createdAt: DateTime.utc(1809, DateTime.february, 12),
          captures: captures,
          integratedData: (url: 'a url'),
          title: 'a title',
        );
        expect(voiceNote.id, 'an id');
        expect(voiceNote.createdAt, DateTime.utc(1809, DateTime.february, 12));
        expect(voiceNote.localData.status, NoteLocalStatus.capturing);
        expect(voiceNote.integratedData, (url: 'a url'));
        expect(voiceNote.title, 'a title');
        expect(voiceNote.captures, captures);
      });
    });
  });
}
