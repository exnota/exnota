import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/note/block.dart';
import 'package:exnota/src/note/repo/drift/block_repo_mapper.dart';
import 'package:exnota/src/note/repo/drift/block_table.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BlockRepoMapper', () {
    group('toRepo', () {
      test('given block, returns BlockTableData', () {
        final now = DateTime.now();
        final input = Block(
            id: 'block id',
            type: BlockType.audio,
            properties: {
              Property.title.toString(): [
                ['a title']
              ]
            },
            createdAt: now,
            lastEditedAt: now);
        final output = BlockRepoMapper.toRepo(input);
        expect(output.id, input.id);
        expect(output.type, BlockTypeRepo.audio);
        expect(output.properties, '{"title":[["a title"]]}');
        expect(output.createdAt, input.createdAt);
        expect(output.lastEditedAt, input.lastEditedAt);
      });
    });
    group('fromRepo', () {
      test('given BlockTableData, returns Block', () {
        final now = DateTime.now();
        final input = BlockTableData(
            id: 'block id',
            type: BlockTypeRepo.audio,
            properties: '{"title":[["a title"]]}',
            createdAt: now,
            lastEditedAt: now);
        final output = BlockRepoMapper.fromRepo(input);
        expect(output.id, input.id);
        expect(output.type, BlockType.audio);
        expect(output.properties, {
          Property.title.toString(): [
            ['a title']
          ]
        });
        expect(output.title, 'a title');
        expect(output.createdAt, input.createdAt);
        expect(output.lastEditedAt, input.lastEditedAt);
      });
    });
  });
}
