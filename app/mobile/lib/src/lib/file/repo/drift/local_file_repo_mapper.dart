import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/file/local_file.dart';
import 'package:exnota/src/lib/log/logger.dart';

class LocalFileRepoMapper {
  static final _log = Logger(context: 'LocalFileRepoMapper');

  static LocalFileTableData toRepo(LocalFile file) {
    return LocalFileTableData(
      id: file.id,
      fileType: fileTypeToRepo(file.fileType),
      status: statusToRepo(file.status),
      path: file.path,
      entityType: entityTypeToRepo(file.entityType),
      entityId: file.entityId,
      created: file.created,
    );
  }

  static LocalFile fromRepo(LocalFileTableData file) {
    return LocalFile(
      id: file.id,
      fileType: fileTypeFromRepo(file.fileType),
      status: statusFromRepo(file.status),
      path: file.path,
      entityType: entityTypeFromRepo(file.entityType),
      entityId: file.entityId,
      created: file.created,
    );
  }

  static String statusToRepo(Status status) {
    switch (status) {
      case Status.recording:
        return 'recording';
      case Status.saved:
        return 'saved';
    }
  }

  static Status statusFromRepo(String status) {
    switch (status) {
      case 'recording':
        return Status.recording;
      case 'saved':
        return Status.saved;
      default:
        _log.error('Unknown status: $status');
        throw Exception('Unknown status: $status');
    }
  }

  static String fileTypeToRepo(FileType type) {
    switch (type) {
      case FileType.audioRecording:
        return 'audioRecording';
    }
  }

  static FileType fileTypeFromRepo(String type) {
    switch (type) {
      case 'audioRecording':
        return FileType.audioRecording;
      default:
        _log.error('Unknown file type: $type');
        throw Exception('Unknown file type: $type');
    }
  }

  static String? entityTypeToRepo(EntityType? type) {
    switch (type) {
      case EntityType.block:
        return 'block';
      case null:
        return null;
    }
  }

  static EntityType? entityTypeFromRepo(String? type) {
    switch (type) {
      case 'block':
        return EntityType.block;
      case null:
        return null;
      default:
        _log.error('Unknown entity type: $type');
        throw Exception('Unknown entity type: $type');
    }
  }
}
