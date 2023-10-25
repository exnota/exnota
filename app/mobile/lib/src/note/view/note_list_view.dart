import 'dart:io';

import 'package:url_launcher/url_launcher.dart';
import 'package:exnota/src/integration/service/notion_connected_service.dart';
import 'package:exnota/src/integration/view/notion_settings_view.dart';
import 'package:exnota/src/note/service/note_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:exnota/src/account/settings/settings_view.dart';
import 'package:path_provider/path_provider.dart';

class NoteListView extends ConsumerStatefulWidget {
  static const routeName = '/';

  const NoteListView({super.key});

  @override
  ConsumerState<NoteListView> createState() => _NoteListViewState();
}

class _NoteListViewState extends ConsumerState<NoteListView> {
  @override
  Widget build(BuildContext context) {
    final notionConnected = ref.watch(notionConnectedServiceProvider);
    final notes = ref.watch(noteServiceProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exnota'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to the settings page. If the user leaves and returns
              // to the app after it has been killed while running in the
              // background, the navigation stack is restored.
              Navigator.restorablePushNamed(context, SettingsView.routeName);
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
                        builder: (context) => const NotionSettingsView()),
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

              return ListTile(
                  title: Text(note.transcription),
                  leading: const Icon(Icons.audio_file),
                  // Accessible tap area according to https://api.flutter.dev/flutter/material/ListTile-class.html#material.ListTile.9
                  trailing: Visibility(
                      visible: note.url is String,
                      replacement: const Icon(Icons.question_mark),
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          // note.url guaranteed to be non-null due to `visible`
                          // property condition.
                          launchUrl(Uri.parse(note.url!));
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
                    //   SampleItemDetailsView.routeName,
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
          final success =
              await ref.read(noteServiceProvider.notifier).create(path);
          setState(() {
            isUploading = false;
          });

          if (!success) {
            throw Exception("Did not upload");
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
