import 'dart:async';

import 'package:drift_db_viewer/drift_db_viewer.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/account/settings/environment_service.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/note/capture.dart';
import 'package:exnota/src/note/note.dart';
import 'package:exnota/src/note/service/block_mutation_service.dart';
import 'package:exnota/src/note/service/deprecated_note_list_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animated_icons/icons8.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:exnota/src/integration/service/notion_connected_service.dart';
import 'package:exnota/src/integration/screen/notion_settings_screen.dart';
import 'package:exnota/src/note/service/deprecated_note_mutation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:exnota/src/account/settings/settings_screen.dart';
import 'package:lottie/lottie.dart';

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
        true => const NoteList(),
      },
      floatingActionButton: switch (notionConnected) {
        false => null,
        true => switch (kDebugMode) {
            false => const RecordButton(),
            true => Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (kDebugMode)
                  FloatingActionButton(
                      heroTag: "fab-test",
                      child: const Text("Test"),
                      onPressed: () async {
                        final file = await ref
                            .read(blockMutationServiceProvider.notifier)
                            .createAudioBlock(extension: "m4a");
                        ref
                            .read(loggerProvider('NoteListScreen'))
                            .debug("Created audio block with file}", file);
                      }),
                const RecordButton()
              ]),
          },
      },
    );
  }
}

class NoteList extends ConsumerWidget {
  const NoteList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteStream = ref.watch(deprecatedNoteListServiceProvider);

    // final noteStream = ref.watch(blockListerProvider);
    return noteStream.when(
      data: (notes) {
        return ListView.builder(
          // Providing a restorationId allows the ListView to restore the
          // scroll position when a user leaves and returns to the app after it
          // has been killed while running in the background.
          restorationId: 'noteListView',
          itemCount: notes.length,
          itemBuilder: (BuildContext context, int index) {
            final note = notes[index];
            return BlockListTile(block: note, key: Key(note.id));
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text("Error: $err"),
    );
  }
}

class BlockListTile extends StatefulWidget {
  final Note block;

  const BlockListTile({Key? key, required this.block}) : super(key: key);

  @override
  State<BlockListTile> createState() => _BlockListTileState();
}

enum PendingStatus { capturing, uploading, transcribing, exporting }

class _BlockListTileState extends State<BlockListTile> {
  ({String text, Widget icon, PendingStatus status})? pendingConfig;
  Timer? pendingConfigTranscribingTimer;
  Timer? pendingConfigExportingTimer;

  @override
  void dispose() {
    pendingConfigTranscribingTimer?.cancel();
    pendingConfigExportingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // final url = widget.block.externalUrl;
    final url = widget.block.integratedData.url;

    // When note status has changed to capturing, update config
    if (pendingConfig == null &&
        widget.block.localData.status == LocalStatus.capturing) {
      setState(() {
        pendingConfig = (
          text: "Recording",
          icon: Lottie.asset(Icons8.sound),
          status: PendingStatus.capturing
        );
      });
    }

    // When note status has changed to captured, update config and set timers
    if ((pendingConfig?.status == null ||
            pendingConfig?.status == PendingStatus.capturing) &&
        widget.block.localData.status == LocalStatus.captured) {
      final transcribingTimer = Timer(const Duration(seconds: 7), () {
        setState(() {
          pendingConfig = (
            text: "Transcribing",
            icon: Lottie.asset(Icons8.document),
            status: PendingStatus.transcribing
          );
        });
      });
      final exportingTimer = Timer(const Duration(seconds: 14), () {
        setState(() {
          pendingConfig = (
            text: "Exporting to Notion",
            icon: Lottie.asset(Icons8.synchronize_cloud),
            status: PendingStatus.exporting
          );
        });
      });
      setState(() {
        pendingConfig = (
          text: "Uploading",
          icon: Lottie.asset(Icons8.upload_to_cloud),
          status: PendingStatus.uploading
        );
        pendingConfigTranscribingTimer = transcribingTimer;
        pendingConfigExportingTimer = exportingTimer;
      });
    }

    // When note status has changed to synced, clear config and cancel timers
    if (pendingConfig != null &&
        widget.block.localData.status == LocalStatus.synced) {
      pendingConfigTranscribingTimer?.cancel();
      pendingConfigExportingTimer?.cancel();
      setState(() {
        pendingConfig = null;
      });
    }

    return ListTile(
        key: Key(widget.block.id),
        title: Visibility(
          visible: pendingConfig != null,
          replacement: Text(
            widget.block.title ?? "",
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          child: Text(pendingConfig?.text ?? "",
              style: const TextStyle(color: Colors.grey)),
        ),
        leading: Icon(
          Icons.audio_file,
          color: widget.block.localData.status == LocalStatus.synced
              ? null
              : Colors.grey,
        ),
        // Accessible tap area according to https://api.flutter.dev/flutter/material/ListTile-class.html#material.ListTile.9
        trailing: Visibility(
            visible: url is String,
            replacement: switch (widget.block.localData.status) {
              LocalStatus.captured => SizedBox(
                  height: 48,
                  width: 48,
                  child: Center(
                    child: SizedBox(
                        width: 24, height: 24, child: pendingConfig?.icon),
                  ),
                ),
              LocalStatus.capturing => SizedBox(
                  height: 48,
                  width: 48,
                  child: Center(
                    child: SizedBox(
                        width: 24,
                        height: 24,
                        child: Lottie.asset(Icons8.sound)),
                  ),
                ),
              LocalStatus.synced => const Icon(Icons.question_mark),
            },
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
  AudioFileCapture? audioFileCapture;
  bool isRecording = false;
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    _initialiseControllers();
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
        heroTag: "fab-record",
        onPressed: () async {
          controller.reset();

          final actualPath = await controller.stop(false);
          ref
              .read(loggerProvider('RecordButton'))
              .debug("Stopped recording. Saved to $actualPath");
          setState(() {
            isRecording = false;
          });
          if (actualPath == null) {
            throw Exception("No path for audio file");
          }

          setState(() {
            isUploading = true;
          });
          await ref
              .read(deprecatedNoteMutationServiceProvider.notifier)
              .setAudioFileCaptured(capture: audioFileCapture!);
          setState(() {
            isUploading = false;
            audioFileCapture = null;
          });
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
        // Verify permissions
        // --
        var micPermission = await Permission.microphone.status;

        // Show dialogs for situations where we (probably) can't request
        // permissions.
        if (micPermission.isPermanentlyDenied) {
          ref.read(loggerProvider('RecordButton')).info(
              "Microphone permission permanently denied. Showing dialog.");
          await _showPermanentlyDeniedDialog();
          return;
        }
        if (micPermission.isRestricted) {
          ref
              .read(loggerProvider('RecordButton'))
              .info("Microphone permission restricted. Showing dialog.");
          await _showRestrictedDialog();
          return;
        }

        // Prompt for permission
        if (!micPermission.isGranted && !micPermission.isLimited) {
          ref.read(loggerProvider('RecordButton')).info(
              "Microphone permission not granted or limited. Requesting permission.");
          micPermission = await Permission.microphone.request();
          if (micPermission != PermissionStatus.granted &&
              micPermission != PermissionStatus.limited) {
            ref.read(loggerProvider('RecordButton')).info(
                "Microphone permission not granted or limited after requesting.");
            _showSnackError("Microphone permission denied");
            return;
          }
        }
        ref
            .read(loggerProvider('RecordButton'))
            .info("Microphone permission should be granted or limited.");

        ref.read(loggerProvider('RecordButton')).debug("Creating note");
        final note = await ref
            .read(deprecatedNoteMutationServiceProvider.notifier)
            .createCapturingAudioNote(extension: "m4a");
        setState(() {
          audioFileCapture = note.captures.first.asAudioFileCapture();
        });
        ref.read(loggerProvider('RecordButton')).debug("Created note", note);

        final path =
            note.captures.first.asAudioFileCapture()?.localData.filePath;
        if (path == null) {
          // TODO: Handle error
          throw Exception("No path for audio file");
        }
        ref
            .read(loggerProvider('RecordButton'))
            .debug("About to record to $path");
        await controller.record(path: path);
        ref.read(loggerProvider('RecordButton')).debug("Recording");

        setState(() {
          isRecording = true;
        });
      },
      label: const Text('Record'),
      icon: const Icon(Icons.mic),
    );
  }

  Future<void> _showPermanentlyDeniedDialog() async {
    return await showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Microphone permission'),
        content:
            const Text('Please allow microphone access to record audio notes.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await openAppSettings();
              _popNavigator();
            },
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRestrictedDialog() async {
    return await showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Microphone permission'),
        content: const Text(
            'Please allow microphone access to record audio notes. You can do this in the settings app.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await openAppSettings();
              _popNavigator();
            },
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }

  void _popNavigator() {
    Navigator.pop(context);
  }
}
