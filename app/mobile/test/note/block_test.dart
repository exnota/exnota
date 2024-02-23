import 'package:exnota/src/note/block.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  group('Block', () {
    group('fromRecord', () {
      group('Given an audio block record with transcription', () {
        group('and a valid transcription', () {
          test('Then it should return an audio block', () {
            final record = RecordModel(
              id: "kof2l65gpu4m1au",
              created: "2024-02-22 05:54:31.448Z",
              updated: "2024-02-22 05:54:38.464Z",
              collectionId: "lrffu3q1yweoljo",
              collectionName: "block",
              data: {
                "archived": "",
                "audio": {
                  "transcription": [
                    "And so my fellow Americans ask not what your country can do for you, ask what you can do for your country."
                  ]
                },
                "externalUrl": "https://www.exnota.com",
                "file": "jfk_cksDY70lDs.wav",
                "title": "audio record 2",
                "type": "audio",
                "user": "31fa2e03sqircla",
                "userCreated": "2024-02-22 12:00:00.000Z"
              },
            );
            final block = Block.fromRecord(record);
            expect(
                block,
                equals(Block(
                  id: "kof2l65gpu4m1au",
                  created: DateTime.parse("2024-02-22 05:54:31.448Z"),
                  updated: DateTime.parse("2024-02-22 05:54:38.464Z"),
                  archived: null,
                  audio: const Audio(transcription: [
                    "And so my fellow Americans ask not what your country can do for you, ask what you can do for your country."
                  ]),
                  externalUrl: "https://www.exnota.com",
                  file: "jfk_cksDY70lDs.wav",
                  title: "audio record 2",
                  type: BlockType.audio,
                  userId: "31fa2e03sqircla",
                  userCreated: DateTime.parse("2024-02-22 12:00:00.000Z"),
                )));
          });
        });
        group("and a null audio property", () {
          test('Then it should return an audio block', () {
            final record = RecordModel(
              id: "kof2l65gpu4m1au",
              created: "2024-02-22 05:54:31.448Z",
              updated: "2024-02-22 05:54:38.464Z",
              collectionId: "lrffu3q1yweoljo",
              collectionName: "block",
              data: {
                "archived": "",
                "audio": null,
                "externalUrl": "https://www.exnota.com",
                "file": "jfk_cksDY70lDs.wav",
                "title": "audio record 2",
                "type": "audio",
                "user": "31fa2e03sqircla",
                "userCreated": "2024-02-22 12:00:00.000Z"
              },
            );
            final block = Block.fromRecord(record);
            expect(
                block,
                equals(Block(
                  id: "kof2l65gpu4m1au",
                  created: DateTime.parse("2024-02-22 05:54:31.448Z"),
                  updated: DateTime.parse("2024-02-22 05:54:38.464Z"),
                  archived: null,
                  audio: null,
                  externalUrl: "https://www.exnota.com",
                  file: "jfk_cksDY70lDs.wav",
                  title: "audio record 2",
                  type: BlockType.audio,
                  userId: "31fa2e03sqircla",
                  userCreated: DateTime.parse("2024-02-22 12:00:00.000Z"),
                )));
          });
        });
        group("and an empty string audio property", () {
          test('Then it should return an audio block', () {
            final record = RecordModel(
              id: "kof2l65gpu4m1au",
              created: "2024-02-22 05:54:31.448Z",
              updated: "2024-02-22 05:54:38.464Z",
              collectionId: "lrffu3q1yweoljo",
              collectionName: "block",
              data: {
                "archived": "",
                "audio": "",
                "externalUrl": "https://www.exnota.com",
                "file": "jfk_cksDY70lDs.wav",
                "title": "audio record 2",
                "type": "audio",
                "user": "31fa2e03sqircla",
                "userCreated": "2024-02-22 12:00:00.000Z"
              },
            );
            final block = Block.fromRecord(record);
            expect(
                block,
                equals(Block(
                  id: "kof2l65gpu4m1au",
                  created: DateTime.parse("2024-02-22 05:54:31.448Z"),
                  updated: DateTime.parse("2024-02-22 05:54:38.464Z"),
                  archived: null,
                  audio: null,
                  externalUrl: "https://www.exnota.com",
                  file: "jfk_cksDY70lDs.wav",
                  title: "audio record 2",
                  type: BlockType.audio,
                  userId: "31fa2e03sqircla",
                  userCreated: DateTime.parse("2024-02-22 12:00:00.000Z"),
                )));
          });
        });
        group('and an empty object audio property', () {
          test('Then it should return an audio block', () {
            final record = RecordModel(
              id: "kof2l65gpu4m1au",
              created: "2024-02-22 05:54:31.448Z",
              updated: "2024-02-22 05:54:38.464Z",
              collectionId: "lrffu3q1yweoljo",
              collectionName: "block",
              data: {
                "archived": "",
                "audio": {},
                "externalUrl": "https://www.exnota.com",
                "file": "jfk_cksDY70lDs.wav",
                "title": "audio record 2",
                "type": "audio",
                "user": "31fa2e03sqircla",
                "userCreated": "2024-02-22 12:00:00.000Z"
              },
            );
            final block = Block.fromRecord(record);
            expect(
                block,
                equals(Block(
                  id: "kof2l65gpu4m1au",
                  created: DateTime.parse("2024-02-22 05:54:31.448Z"),
                  updated: DateTime.parse("2024-02-22 05:54:38.464Z"),
                  archived: null,
                  audio: null,
                  externalUrl: "https://www.exnota.com",
                  file: "jfk_cksDY70lDs.wav",
                  title: "audio record 2",
                  type: BlockType.audio,
                  userId: "31fa2e03sqircla",
                  userCreated: DateTime.parse("2024-02-22 12:00:00.000Z"),
                )));
          });
        });
        group('and an empty transcription', () {
          test('Then it should return an audio block', () {
            final record = RecordModel(
              id: "kof2l65gpu4m1au",
              created: "2024-02-22 05:54:31.448Z",
              updated: "2024-02-22 05:54:38.464Z",
              collectionId: "lrffu3q1yweoljo",
              collectionName: "block",
              data: {
                "archived": "",
                "audio": {"transcription": []},
                "externalUrl": "https://www.exnota.com",
                "file": "jfk_cksDY70lDs.wav",
                "title": "audio record 2",
                "type": "audio",
                "user": "31fa2e03sqircla",
                "userCreated": "2024-02-22 12:00:00.000Z"
              },
            );
            final block = Block.fromRecord(record);
            expect(
                block,
                equals(Block(
                  id: "kof2l65gpu4m1au",
                  created: DateTime.parse("2024-02-22 05:54:31.448Z"),
                  updated: DateTime.parse("2024-02-22 05:54:38.464Z"),
                  archived: null,
                  audio: const Audio(transcription: []),
                  externalUrl: "https://www.exnota.com",
                  file: "jfk_cksDY70lDs.wav",
                  title: "audio record 2",
                  type: BlockType.audio,
                  userId: "31fa2e03sqircla",
                  userCreated: DateTime.parse("2024-02-22 12:00:00.000Z"),
                )));
          });
        });
        group('and an invalid transcription', () {
          // TODO: SHOULD it throw?!
          test('Then it should throw an error', () {
            final record = RecordModel(
              id: "kof2l65gpu4m1au",
              created: "2024-02-22 05:54:31.448Z",
              updated: "2024-02-22 05:54:38.464Z",
              collectionId: "lrffu3q1yweoljo",
              collectionName: "block",
              data: {
                "archived": "",
                "audio": {"transcription": "invalid"},
                "externalUrl": "https://www.exnota.com",
                "file": "jfk_cksDY70lDs.wav",
                "title": "audio record 2",
                "type": "audio",
                "user": "31fa2e03sqircla",
                "userCreated": "2024-02-22 12:00:00.000Z"
              },
            );
            expect(() => Block.fromRecord(record), throwsA(isA<TypeError>()));
          });
        });
      });
      group('Given a text block record', () {
        test('Then it should return a text block', () {
          final record = RecordModel(
            id: "kof2l65gpu4m1au",
            created: "2024-02-22 05:54:31.448Z",
            updated: "2024-02-22 05:54:38.464Z",
            collectionId: "lrffu3q1yweoljo",
            collectionName: "block",
            data: {
              "archived": "",
              "audio": null,
              "externalUrl": "",
              "file": "",
              "title": "text record 1",
              "type": "text",
              "user": "31fa2e03sqircla",
              "userCreated": "2024-02-22 12:00:00.000Z"
            },
          );
          final block = Block.fromRecord(record);
          expect(
              block,
              equals(Block(
                id: "kof2l65gpu4m1au",
                created: DateTime.parse("2024-02-22 05:54:31.448Z"),
                updated: DateTime.parse("2024-02-22 05:54:38.464Z"),
                archived: null,
                audio: null,
                externalUrl: "",
                file: "",
                title: "text record 1",
                type: BlockType.text,
                userId: "31fa2e03sqircla",
                userCreated: DateTime.parse("2024-02-22 12:00:00.000Z"),
              )));
        });
      });
      group('Given an archived block', () {
        test('Then it should return an archived block', () {
          final record = RecordModel(
            id: "kof2l65gpu4m1au",
            created: "2024-02-22 05:54:31.448Z",
            updated: "2024-02-22 05:54:38.464Z",
            collectionId: "lrffu3q1yweoljo",
            collectionName: "block",
            data: {
              "archived": "2024-02-22 05:54:38.464Z",
              "audio": null,
              "externalUrl": "",
              "file": "",
              "title": "text record 1",
              "type": "text",
              "user": "31fa2e03sqircla",
              "userCreated": "2024-02-22 12:00:00.000Z"
            },
          );
          final block = Block.fromRecord(record);
          expect(
              block,
              equals(Block(
                id: "kof2l65gpu4m1au",
                created: DateTime.parse("2024-02-22 05:54:31.448Z"),
                updated: DateTime.parse("2024-02-22 05:54:38.464Z"),
                archived: DateTime.parse("2024-02-22 05:54:38.464Z"),
                audio: null,
                externalUrl: "",
                file: "",
                title: "text record 1",
                type: BlockType.text,
                userId: "31fa2e03sqircla",
                userCreated: DateTime.parse("2024-02-22 12:00:00.000Z"),
              )));
        });
      });
    });
  });
}
