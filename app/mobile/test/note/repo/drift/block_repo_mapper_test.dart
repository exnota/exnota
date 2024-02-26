import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/note/block.dart';
import 'package:exnota/src/note/repo/drift/block_repo_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BlockRepoMapper', () {
    group('fromRepo', () {
      group('when repo type has only optional properties', () {
        test('then it should map the properties correctly', () {
          final userCreated = DateTime.utc(1809, DateTime.february, 12);
          final repo = BlockTableData(
            id: 'id',
            type: 'audio',
            user: 'user id',
            userCreated: userCreated,
          );
          final block = BlockRepoMapper.fromRepo(repo);
          expect(
              block,
              Block(
                id: 'id',
                title: null,
                type: BlockType.audio,
                externalUrl: null,
                file: null,
                audio: null,
                userId: 'user id',
                userCreated: userCreated,
                created: null,
                updated: null,
                archived: null,
              ));
        });
      });
      group('when repo type has all properties', () {
        test('then it should map the properties correctly', () {
          final userCreated = DateTime.utc(1533, DateTime.february, 28);
          final created = DateTime.utc(1564, DateTime.february, 15);
          final updated = DateTime.utc(1809, DateTime.february, 12);
          final archived = DateTime.utc(1879, DateTime.march, 14);
          final repo = BlockTableData(
            id: 'id',
            title: 'title',
            type: 'audio',
            externalUrl: 'external url',
            file: 'file',
            audio: '{"transcription": ["paragraph 1", "paragraph 2"]}',
            user: 'user id',
            userCreated: userCreated,
            created: created,
            updated: updated,
            archived: archived,
          );
          final block = BlockRepoMapper.fromRepo(repo);
          expect(
              block,
              Block(
                id: 'id',
                title: 'title',
                type: BlockType.audio,
                externalUrl: 'external url',
                file: 'file',
                audio: const Audio(
                  transcription: ['paragraph 1', 'paragraph 2'],
                ),
                userId: 'user id',
                userCreated: userCreated,
                created: created,
                updated: updated,
                archived: archived,
              ));
        });
      });
      group('when repo type is audio', () {
        test('then it should map the type correctly', () {
          final repo = BlockTableData(
            id: 'id',
            type: 'audio',
            user: 'user id',
            userCreated: DateTime.utc(1809, DateTime.february, 12),
          );
          final block = BlockRepoMapper.fromRepo(repo);
          expect(block.type, BlockType.audio);
        });
      });
      group('when repo type is text', () {
        test('then it should map the type correctly', () {
          final repo = BlockTableData(
            id: 'id',
            type: 'text',
            user: 'user id',
            userCreated: DateTime.utc(1809, DateTime.february, 12),
          );
          final block = BlockRepoMapper.fromRepo(repo);
          expect(block.type, BlockType.text);
        });
      });
      group('when repo type is not known', () {
        test('then it should map to the unknown type', () {
          final repo = BlockTableData(
            id: 'id',
            type: 'some other type',
            user: 'user id',
            userCreated: DateTime.utc(1809, DateTime.february, 12),
          );
          final block = BlockRepoMapper.fromRepo(repo);
          expect(block.type, BlockType.unknown);
        });
      });
      group('when audio is null', () {
        test('then it should map to null', () {
          final repo = BlockTableData(
            id: 'id',
            type: 'audio',
            user: 'user id',
            audio: null,
            userCreated: DateTime.utc(1809, DateTime.february, 12),
          );
          final block = BlockRepoMapper.fromRepo(repo);
          expect(block.audio, null);
        });
      });
      group('when audio is an empty object', () {
        test('then it should map to an empty object', () {
          final repo = BlockTableData(
            id: 'id',
            type: 'audio',
            user: 'user id',
            audio: '{}',
            userCreated: DateTime.utc(1809, DateTime.february, 12),
          );
          final block = BlockRepoMapper.fromRepo(repo);
          expect(block.audio, const Audio(transcription: null));
        });
      });
      group('when audio has a transcription', () {
        test('then it should map the transcription', () {
          final repo = BlockTableData(
            id: 'id',
            type: 'audio',
            user: 'user id',
            audio: '{"transcription": ["paragraph 1", "paragraph 2"]}',
            userCreated: DateTime.utc(1809, DateTime.february, 12),
          );
          final block = BlockRepoMapper.fromRepo(repo);
          expect(
              block.audio,
              const Audio(
                transcription: ['paragraph 1', 'paragraph 2'],
              ));
        });
      });
      group('when audio has other properties but no transcription', () {
        test('then it should map to an empty object', () {
          final repo = BlockTableData(
            id: 'id',
            type: 'audio',
            user: 'user id',
            audio: '{"some other property": "value"}',
            userCreated: DateTime.utc(1809, DateTime.february, 12),
          );
          final block = BlockRepoMapper.fromRepo(repo);
          expect(block.audio, const Audio(transcription: null));
        });
      });
    });
    group('toRepo', () {
      group('when block type has only optional properties', () {
        test('then it should map the properties correctly', () {
          final userCreated = DateTime.utc(1809, DateTime.february, 12);
          final block = Block(
            id: 'the id',
            type: BlockType.audio,
            userId: 'user id',
            userCreated: userCreated,
          );
          final repo = BlockRepoMapper.toRepo(block);
          expect(
              repo,
              BlockTableData(
                id: 'the id',
                title: null,
                type: 'audio',
                externalUrl: null,
                file: null,
                audio: null,
                user: 'user id',
                userCreated: userCreated,
                created: null,
                updated: null,
                archived: null,
              ));
        });
      });
      group('when block type has all properties', () {
        test('then it should map the properties correctly', () {
          final userCreated = DateTime.utc(1533, DateTime.february, 28);
          final created = DateTime.utc(1564, DateTime.february, 15);
          final updated = DateTime.utc(1809, DateTime.february, 12);
          final archived = DateTime.utc(1879, DateTime.march, 14);
          final block = Block(
            id: 'the id',
            title: 'title',
            type: BlockType.audio,
            externalUrl: 'external url',
            file: 'file',
            audio: const Audio(
              transcription: ['paragraph 1', 'paragraph 2'],
            ),
            userId: 'user id',
            userCreated: userCreated,
            created: created,
            updated: updated,
            archived: archived,
          );
          final repo = BlockRepoMapper.toRepo(block);
          expect(
              repo,
              BlockTableData(
                id: 'the id',
                title: 'title',
                type: 'audio',
                externalUrl: 'external url',
                file: 'file',
                audio: '{"transcription":["paragraph 1","paragraph 2"]}',
                user: 'user id',
                userCreated: userCreated,
                created: created,
                updated: updated,
                archived: archived,
              ));
        });
      });
      group('when block type is audio', () {
        test('then it should map the type correctly', () {
          final block = Block(
            id: 'the id',
            type: BlockType.audio,
            userId: 'user id',
            userCreated: DateTime.utc(1809, DateTime.february, 12),
          );
          final repo = BlockRepoMapper.toRepo(block);
          expect(repo.type, 'audio');
        });
      });
      group('when block type is text', () {
        test('then it should map the type correctly', () {
          final block = Block(
            id: 'the id',
            type: BlockType.text,
            userId: 'user id',
            userCreated: DateTime.utc(1809, DateTime.february, 12),
          );
          final repo = BlockRepoMapper.toRepo(block);
          expect(repo.type, 'text');
        });
      });
      group('when block type is unknown', () {
        test('then it should map to the unknown type', () {
          final block = Block(
            id: 'the id',
            type: BlockType.unknown,
            userId: 'user id',
            userCreated: DateTime.utc(1809, DateTime.february, 12),
          );
          final repo = BlockRepoMapper.toRepo(block);
          expect(repo.type, 'unknown');
        });
      });
      group('when audio is null', () {
        test('then it should map to null', () {
          final block = Block(
            id: 'the id',
            type: BlockType.audio,
            userId: 'user id',
            audio: null,
            userCreated: DateTime.utc(1809, DateTime.february, 12),
          );
          final repo = BlockRepoMapper.toRepo(block);
          expect(repo.audio, null);
        });
      });
      group('when audio has no properties', () {
        test('then it should map to an object with null transcription', () {
          final block = Block(
            id: 'the id',
            type: BlockType.audio,
            userId: 'user id',
            audio: const Audio(),
            userCreated: DateTime.utc(1809, DateTime.february, 12),
          );
          final repo = BlockRepoMapper.toRepo(block);
          expect(repo.audio, '{"transcription":null}');
        });
      });
      group('when audio has a transcription', () {
        test('then it should map the transcription', () {
          final block = Block(
            id: 'the id',
            type: BlockType.audio,
            userId: 'user id',
            audio: const Audio(
              transcription: ['paragraph 1', 'paragraph 2'],
            ),
            userCreated: DateTime.utc(1809, DateTime.february, 12),
          );
          final repo = BlockRepoMapper.toRepo(block);
          expect(repo.audio, '{"transcription":["paragraph 1","paragraph 2"]}');
        });
      });
    });
  });
}
