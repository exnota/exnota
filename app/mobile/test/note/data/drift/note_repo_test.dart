import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/optional.dart';
import 'package:exnota/src/note/capture.dart';
import 'package:exnota/src/note/data/drift/capture_table.dart';
import 'package:exnota/src/note/data/drift/note_repo.dart';
import 'package:exnota/src/note/data/drift/note_table.dart';
import 'package:exnota/src/note/note.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.inMemory();
  });

  tearDown(() async {
    await db.close();
  });

  group('NoteRepo', () {
    group('list', () {
      group('given no notes', () {
        test('returns empty list', () async {
          final repo = NoteRepo(db);
          final stream = repo.list();
          expect(stream, emits([]));
        });
      });
      group('given notes', () {
        setUp(() async {
          final capture1IsCaptured = CaptureTableData(
              id: 'capture1',
              createdAt: DateTime.utc(1809, DateTime.february, 12),
              type: CaptureTableType.audio,
              localData: CaptureLocalDataAll.audioFile(
                  status: CaptureLocalStatusRepo.captured,
                  filePath: 'capture1 file path'),
              typeData: CaptureTypeDataAll.audioFile(
                  transcription: 'capture 1 transcription'));
          final capture2IsCapturing = CaptureTableData(
              id: 'capture2',
              createdAt: DateTime.utc(1879, DateTime.march, 14),
              type: CaptureTableType.audio,
              localData: CaptureLocalDataAll.audioFile(
                  status: CaptureLocalStatusRepo.capturing, filePath: null),
              typeData: CaptureTypeDataAll.audioFile(transcription: null));
          final note1 = NoteTableData(
              id: 'note1',
              type: NoteTableType.voice,
              integratedData: IntegratedDataRepo(url: 'note1 url'),
              localData: LocalDataAll(status: NoteLocalStatusRepo.capturing),
              createdAt: DateTime.utc(1809, DateTime.february, 12),
              title: 'a title',
              captures: [capture1IsCaptured.id, capture2IsCapturing.id]);

          await db.into(db.captureTable).insert(capture1IsCaptured);
          await db.into(db.captureTable).insert(capture2IsCapturing);
          await db.into(db.noteTable).insert(note1);
        });
        test('returns list of notes', () async {
          final repo = NoteRepo(db);
          final stream = repo.list().timeout(const Duration(seconds: 30));
          expectLater(
              stream,
              emitsInOrder([
                predicate<List<Note>>((notes) {
                  expect(notes, hasLength(1));
                  final note = notes.first;
                  expect(note.id, 'note1');
                  expect(note, isA<VoiceNote>());
                  if (note is! VoiceNote) {
                    throw Exception('Should be a VoiceNote');
                  }
                  expect(note.integratedData, (url: 'note1 url'));
                  expect(note.localData,
                      VoiceNoteLocalData(status: NoteLocalStatus.capturing));
                  // TODO: Fix
                  // expect(note.createdAt,
                  //     DateTime.utc(1809, DateTime.february, 12));
                  expect(note.title, 'a title');
                  expect(note.captures, hasLength(2));

                  final capture1 = note.captures[0];
                  expect(capture1.id, 'capture1');
                  // TODO: Fix
                  // expect(capture1.createdAt,
                  //     DateTime.utc(1809, DateTime.february, 12));
                  expect(capture1, isA<AudioFileCapture>());
                  if (capture1 is! AudioFileCapture) {
                    throw Exception('Should be an AudioFileCapture');
                  }
                  expect(capture1.transcription, 'capture 1 transcription');
                  expect(capture1.localData, isA<AudioFileCaptureLocalData>());
                  expect(
                      capture1.localData,
                      AudioFileCaptureLocalData(
                          status: CaptureLocalStatus.captured,
                          filePath: const Optional('capture1 file path')));

                  final capture2 = note.captures[1];
                  expect(capture2.id, 'capture2');
                  // TODO: Fix
                  // expect(capture2.createdAt,
                  //     DateTime.utc(1879, DateTime.march, 14));
                  expect(capture2, isA<AudioFileCapture>());
                  if (capture2 is! AudioFileCapture) {
                    throw Exception('Should be an AudioFileCapture');
                  }
                  expect(capture2.transcription, isNull);
                  expect(capture2.localData, isA<AudioFileCaptureLocalData>());
                  expect(
                      capture2.localData,
                      AudioFileCaptureLocalData(
                          status: CaptureLocalStatus.capturing,
                          filePath: Optional.empty()));

                  return true;
                }),
              ]));
        });
      });
    });
  });
}
