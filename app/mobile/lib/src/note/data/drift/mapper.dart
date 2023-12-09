import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/optional.dart';
import 'package:exnota/src/note/capture.dart';
import 'package:exnota/src/note/data/drift/capture_table.dart';
import 'package:exnota/src/note/data/drift/note_table.dart';
import 'package:exnota/src/note/note.dart';

class NoteRepoMapper {
  static NoteTableData noteToData(Note note) {
    return NoteTableData(
      id: note.id,
      type: NoteTypeRepo.voice,
      title: note.title,
      captures: note.captures.map((c) => c.id).toList(),
      localData:
          LocalDataRepo.voice(status: localStatusToData(note.localData.status)),
      integratedData: IntegratedDataRepo.voice(url: note.integratedData.url),
      createdAt: note.createdAt,
    );
  }

  static CaptureTableData captureToData(Capture capture) {
    switch (capture) {
      case AudioFileCapture():
        return CaptureTableData(
          id: capture.id,
          type: CaptureTypeRepo.audio,
          createdAt: capture.createdAt,
          localData: CaptureLocalDataRepo.audioFile(
            filePath: capture.localData.filePath,
            status: NoteRepoMapper.captureLocalStatusToData(
                capture.localData.status),
          ),
          typeData: CaptureTypeDataRepo.audioFile(
            transcription: capture.transcription,
          ),
        );
      case UnknownCapture():
        return CaptureTableData(
            id: capture.id,
            type: CaptureTypeRepo.unknown,
            createdAt: capture.createdAt,
            localData: CaptureLocalDataRepo.unknown(
              status: NoteRepoMapper.captureLocalStatusToData(
                  capture.localData.status),
            ),
            typeData: CaptureTypeDataRepo.unknown());
    }
  }

  static Note fromData(NoteTableData data, List<CaptureTableData> captures) {
    switch (data.type) {
      case NoteTypeRepo.voice:
        return _voiceNoteFromData(data, captures);
      default:
        throw Exception("Unknown note type: ${data.type}");
    }
  }

  static VoiceNote _voiceNoteFromData(
      NoteTableData data, List<CaptureTableData> captures) {
    return VoiceNote.fromDb(
      id: data.id,
      title: data.title,
      captures: captures.map((capture) {
        switch (capture.type) {
          case CaptureTypeRepo.audio:
            return AudioFileCapture.fromDb(
              id: capture.id,
              createdAt: capture.createdAt,
              filePath: Optional(capture.localData.filePath),
              status: captureLocalStatusFromData(capture.localData.status),
              transcription: Optional(capture.typeData.transcription),
            );

          case CaptureTypeRepo.unknown:
            return UnknownCapture.fromDb(
                id: capture.id,
                createdAt: capture.createdAt,
                localData: UnknownCaptureLocalData(
                    status:
                        captureLocalStatusFromData(capture.localData.status)));
        }
      }).toList(),
      integratedData: (url: data.integratedData.url),
      createdAt: data.createdAt,
    );
  }

  static LocalStatus _localStatusFromData(NoteLocalStatusRepo status) {
    switch (status) {
      case NoteLocalStatusRepo.capturing:
        return LocalStatus.capturing;
      case NoteLocalStatusRepo.captured:
        return LocalStatus.captured;
      case NoteLocalStatusRepo.synced:
        return LocalStatus.synced;
    }
  }

  static NoteLocalStatusRepo localStatusToData(LocalStatus status) {
    switch (status) {
      case LocalStatus.capturing:
        return NoteLocalStatusRepo.capturing;
      case LocalStatus.captured:
        return NoteLocalStatusRepo.captured;
      case LocalStatus.synced:
        return NoteLocalStatusRepo.synced;
    }
  }

  static CaptureLocalStatus captureLocalStatusFromData(
      CaptureLocalStatusRepo status) {
    switch (status) {
      case CaptureLocalStatusRepo.capturing:
        return CaptureLocalStatus.capturing;
      case CaptureLocalStatusRepo.captured:
        return CaptureLocalStatus.captured;
      case CaptureLocalStatusRepo.synced:
        return CaptureLocalStatus.synced;
    }
  }

  static CaptureLocalStatusRepo captureLocalStatusToData(
      CaptureLocalStatus status) {
    switch (status) {
      case CaptureLocalStatus.capturing:
        return CaptureLocalStatusRepo.capturing;
      case CaptureLocalStatus.captured:
        return CaptureLocalStatusRepo.captured;
      case CaptureLocalStatus.synced:
        return CaptureLocalStatusRepo.synced;
    }
  }
}
