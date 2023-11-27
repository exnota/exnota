import 'dart:io';

import 'package:drift_db_viewer/drift_db_viewer.dart';
import 'package:exnota/database.dart';
import 'package:exnota/src/account/settings/environment_service.dart';
import 'package:exnota/src/note/data/sync/sync_command_repo.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:exnota/src/integration/service/notion_connected_service.dart';
import 'package:exnota/src/integration/screen/notion_settings_screen.dart';
import 'package:exnota/src/note/service/note_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:exnota/src/account/settings/settings_screen.dart';
import 'package:path_provider/path_provider.dart';

class NoteListScreen extends ConsumerStatefulWidget {
  static const routeName = '/';

  const NoteListScreen({super.key});

  @override
  ConsumerState<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends ConsumerState<NoteListScreen> {
  @override
  Widget build(BuildContext context) {
    final notionConnected = ref.watch(notionConnectedServiceProvider);
    final notes = ref.watch(noteServiceProvider).valueOrNull ?? [];
    final environment = ref.watch(environmentServiceProvider);
    String title;
    switch (environment) {
      case Environment.prod:
        title = kDebugMode ? "Exnota (🌐 prod)" : "Exnota";
        break;
      case Environment.local:
        title = kDebugMode ? "Exnota (🧑‍💻 local)" : "Exnota";
        break;
    }
    // TODO: Remove
    final db = ref.read(databaseProvider);
    SyncCommandRepo(db).fetchAllStream().listen((event) {
      print("length=${event.length}");
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (kDebugMode)
            IconButton(
                icon: const Icon(Icons.storage),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) =>
                          DriftDbViewer(ref.read(databaseProvider))));
                }),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to the settings page. If the user leaves and returns
              // to the app after it has been killed while running in the
              // background, the navigation stack is restored.
              Navigator.restorablePushNamed(context, SettingsScreen.routeName);
            },
          ),
        ],
      ),
      body: switch (notionConnected) {
        false => Center(
            child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const NotionSettingsScreen()),
                  );
                },
                child:
                    Text(AppLocalizations.of(context)!.note_connectToNotion)),
          ),
        // To work with lists that may contain a large number of items, it’s best
        // to use the ListView.builder constructor.
        //
        // In contrast to the default ListView constructor, which requires
        // building all Widgets up front, the ListView.builder constructor lazily
        // builds Widgets as they’re scrolled into view.
        // true => const Text("connected"),
        true => ListView.builder(
            // Providing a restorationId allows the ListView to restore the
            // scroll position when a user leaves and returns to the app after it
            // has been killed while running in the background.
            restorationId: 'noteListView',
            itemCount: notes.length,
            itemBuilder: (BuildContext context, int index) {
              final note = notes[index];
              final url = note.url;

              return ListTile(
                  title: Text(note.transcription),
                  leading: const Icon(Icons.audio_file),
                  // Accessible tap area according to https://api.flutter.dev/flutter/material/ListTile-class.html#material.ListTile.9
                  trailing: Visibility(
                      visible: url is String,
                      replacement: const Icon(Icons.question_mark),
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          if (url is String) {
                            launchUrl(Uri.parse(url));
                          }
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          alignment: Alignment.center,
                          child: const Icon(Icons.link),
                        ),
                      )),
                  onTap: () {
                    // Navigate to the details page. If the user leaves and returns to
                    // the app after it has been killed while running in the
                    // background, the navigation stack is restored.
                    // Navigator.restorablePushNamed(
                    //   context,
                    //   SampleItemDetailsScreen.routeName,
                    // );
                  });
            },
          ),
      },
      floatingActionButton: switch (notionConnected) {
        false => null,
        true => const RecordButton()
      },
    );
  }
}

class RecordButton extends ConsumerStatefulWidget {
  const RecordButton({super.key});

  @override
  ConsumerState<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends ConsumerState<RecordButton> {
  late final RecorderController controller;

  String? path;
  bool isRecording = false;
  bool isUploading = false;
  late Directory appDirectory;

  @override
  void initState() {
    super.initState();
    _getDir();
    _initialiseControllers();
  }

  void _getDir() async {
    appDirectory = await getApplicationDocumentsDirectory();
    path = "${appDirectory.path}/recording.m4a";
    setState(() {});
  }

  void _initialiseControllers() {
    controller = RecorderController()
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
      ..sampleRate = 44100;
  }

  _showSnackError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        // Don't auto-dimiss
        duration: const Duration(days: 1),
        action: SnackBarAction(
          label: 'Dismiss',
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Can't use controller.isRecording here was it won't trigger a re-render.
    // This could possibly be done with a listener on:
    // controller.onRecorderStateChanged.
    if (isRecording) {
      return FloatingActionButton.extended(
        onPressed: () async {
          controller.reset();

          final path = await controller.stop(false);
          setState(() {
            isRecording = false;
          });
          if (path == null) {
            throw Exception("No path for audio file");
          }

          setState(() {
            isUploading = true;
          });
          final err = await ref.read(noteServiceProvider.notifier).create(path);
          setState(() {
            isUploading = false;
          });

          String? errorMessage;
          switch (err) {
            case NoteCreateError.authError:
              errorMessage = "Access to Notion lost. Please reconnect.";
              break;
            case NoteCreateError.noPageError:
              errorMessage =
                  "No page or database to export to. Please reconnect and select a page.";
              break;
            case NoteCreateError.network:
              errorMessage = "There seems to be a network issue. Please retry.";
              break;
            case NoteCreateError.other:
              errorMessage = "Couldn't export for an unknown reason.";
              break;
            case null:
              break;
          }
          if (errorMessage != null) {
            _showSnackError(errorMessage);
          }
        },
        label: const Text('Stop'),
        icon: const Icon(Icons.stop),
      );
    }
    if (isUploading) {
      return const FloatingActionButton.extended(
        onPressed: null,
        backgroundColor: Colors.grey,
        label: Row(children: [
          CircularProgressIndicator(),
          Text('Uploading (may take a min)'),
        ]),
        // icon: const Icon(Icons.),
      );
    }
    return FloatingActionButton.extended(
      onPressed: () async {
        print('about to record');
        await controller.record(path: path!);
        print('recording...');
        setState(() {
          isRecording = true;
        });
      },
      label: const Text('Record'),
      icon: const Icon(Icons.mic),
    );
  }
}
