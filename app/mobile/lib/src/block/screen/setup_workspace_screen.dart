import 'package:exnota/src/block/repo/drift/workspace_importer.dart';
import 'package:exnota/src/block/workspace.dart';
import 'package:exnota/src/context/sync/request_handler.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'setup_workspace_screen.freezed.dart';
part 'setup_workspace_screen.g.dart';

class SetupWorkspaceScreen extends ConsumerStatefulWidget {
  const SetupWorkspaceScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _SetupWorkspaceScreenState();
}

class _SetupWorkspaceScreenState extends ConsumerState<SetupWorkspaceScreen> {
  @override
  void initState() {
    super.initState();
    // Set state for consistency with above, even though at time of writing this
    // is the default state
    //
    // Need to wrap in Future to avoid provider throwing an error that its
    // state was modified during the widget's lifecycle.
    Future(() {
      ref
          .read(setupWorkspaceScreenControllerProvider.notifier)
          .transitionStatus(
            newStatus: WorkspaceSetupStatus.loadingWorkspace,
          );
      ref
          .read(setupWorkspaceScreenControllerProvider.notifier)
          .loadOrRefreshWorkspace();
    });
  }

  @override
  Widget build(BuildContext context) {
    final setupState = ref.watch(setupWorkspaceScreenControllerProvider);

    // On status change, trigger the appropriate action
    ref.listen(setupWorkspaceScreenControllerProvider, (prevState, nextState) {
      // Flows:
      // - Load -> Update locally
      // - Load -> Create remotely -> Create locally
      switch (nextState.status) {
        case WorkspaceSetupStatus.loadingWorkspace:
          ref
              .read(setupWorkspaceScreenControllerProvider.notifier)
              .loadOrRefreshWorkspace();
          break;
        default:
        // TODO:
      }
    });

    return Scaffold(
      body: Center(
        child: Container(
          child: switch (setupState.status) {
            WorkspaceSetupStatus.loadingWorkspace =>
              const Text('Loading workspace'),
            WorkspaceSetupStatus.loadingWorkspaceError => SetupErrorMessage(
                error: setupState.error!,
                errorRetryStatus: setupState.errorRetryStatus,
              ),
            WorkspaceSetupStatus.createWorkspace => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      ref
                          .read(setupWorkspaceScreenControllerProvider.notifier)
                          .createWorkspace(type: WorkspaceType.database);
                    },
                    child: const Text('I use a note database'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      ref
                          .read(setupWorkspaceScreenControllerProvider.notifier)
                          .createWorkspace(type: WorkspaceType.custom);
                    },
                    child: const Text('I don\'t use a note database'),
                  ),
                ],
              ),
            WorkspaceSetupStatus.creatingWorkspace =>
              const Text('Creating workspace'),
            WorkspaceSetupStatus.creatingWorkspaceError => SetupErrorMessage(
                error: setupState.error!,
                errorRetryStatus: setupState.errorRetryStatus,
              ),
            WorkspaceSetupStatus.workspaceReady =>
              const Text('Workspace ready'),
          },
        ),
      ),
    );
  }
}

class SetupErrorMessage extends ConsumerWidget {
  final String error;
  final WorkspaceSetupStatus? errorRetryStatus;

  const SetupErrorMessage(
      {super.key, required this.error, this.errorRetryStatus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Error: $error'),
        if (errorRetryStatus != null)
          ElevatedButton(
            onPressed: () {
              ref
                  .read(setupWorkspaceScreenControllerProvider.notifier)
                  .transitionStatus(newStatus: errorRetryStatus!);
            },
            child: const Text('Retry'),
          ),
      ],
    );
  }
}

enum WorkspaceSetupStatus {
  loadingWorkspace,
  loadingWorkspaceError,
  createWorkspace,
  creatingWorkspace,
  creatingWorkspaceError,
  workspaceReady,
}

@Freezed(copyWith: false)
class WorkspaceSetupState with _$WorkspaceSetupState {
  const factory WorkspaceSetupState({
    required WorkspaceSetupStatus status,
    // required Workspace? workspace,
    required String? error,
    required WorkspaceSetupStatus? errorRetryStatus,
  }) = _WorkspaceSetupState;
}

@riverpod
class SetupWorkspaceScreenController extends _$SetupWorkspaceScreenController {
  final _log = Logger(context: 'SetupWorkspaceScreenController');

  @override
  WorkspaceSetupState build() {
    _log.debug('build: Initializing state with status loadingWorkspace');
    return const WorkspaceSetupState(
      status: WorkspaceSetupStatus.loadingWorkspace,
      // workspace: null,
      error: null,
      errorRetryStatus: null,
    );
  }

  // Transition to a new state status
  void transitionStatus({required WorkspaceSetupStatus newStatus}) {
    state = WorkspaceSetupState(
      status: newStatus,
      // workspace: state.workspace,
      error: null,
      errorRetryStatus: null,
    );
  }

  // Fetches workspace from backend and saves to this provider's state
  Future<void> loadOrRefreshWorkspace() async {
    _log.debug('loadOrRefreshWorkspace: Loading workspace');
    // TODO:
    // - Send request for existing workspace
    // - If it exists, import
    final request = WorkspaceImportRequest();
    await ref.read(requestHandlerProvider.notifier).submit(
        request: request,
        onSuccess: (numWorkspaces) {
          _log.debug('loadOrRefreshWorkspace: Success');
          if (numWorkspaces == 0) {
            _log.debug('loadOrRefreshWorkspace: No workspace found');
            state = const WorkspaceSetupState(
              status: WorkspaceSetupStatus.createWorkspace,
              error: null,
              errorRetryStatus: null,
            );
            return;
          }

          _log.debug('loadOrRefreshWorkspace: Workspace found');
          state = const WorkspaceSetupState(
            status: WorkspaceSetupStatus.workspaceReady,
            error: null,
            errorRetryStatus: null,
          );
        },
        onError: (err) {
          _log.error('loadOrRefreshWorkspace: Failed with error: $err');
          state = WorkspaceSetupState(
            status: WorkspaceSetupStatus.loadingWorkspaceError,
            error: err.toString(),
            errorRetryStatus: WorkspaceSetupStatus.loadingWorkspace,
          );
        });
  }

  Future<void> createWorkspace({required WorkspaceType type}) async {
    _log.debug('createWorkspace: Creating workspace of type $type');
    final activeUserId = ref.read(activeUserIdOrThrowSyncProvider);
    final request = CreateWorkspaceRequest(type: type, userId: activeUserId);
    await ref.read(requestHandlerProvider.notifier).submit(
        request: request,
        onSuccess: (_) {
          _log.debug('createWorkspace: Success');
          state = const WorkspaceSetupState(
            status: WorkspaceSetupStatus.workspaceReady,
            error: null,
            errorRetryStatus: null,
          );
        },
        onError: (err) {
          _log.error('createWorkspace: Failed with error: $err');
          state = WorkspaceSetupState(
            status: WorkspaceSetupStatus.creatingWorkspaceError,
            error: err.toString(),
            errorRetryStatus: WorkspaceSetupStatus.createWorkspace,
          );
        });
  }
}

class WorkspaceImportRequest extends HandledRequest<int> {
  final Logger _log = Logger(context: 'WorkspaceImportRequest');

  @override
  Future<int> request({required PocketBase pb, required Ref ref}) async {
    _log.debug('request: Importing workspace records');

    final records = await pb.collection(collectionWorkspace).getFullList();

    _log.debug('request: Importing ${records.length} workspace records');
    await ref.read(workspaceImporterProvider.notifier).importAll(records);

    return records.length;
  }
}

class CreateWorkspaceRequest extends HandledRequest<void> {
  final Logger _log = Logger(context: 'CreateWorkspaceRequest');

  final WorkspaceType type;
  final String userId;

  CreateWorkspaceRequest({required this.type, required this.userId});

  @override
  Future<void> request({required PocketBase pb, required Ref ref}) async {
    _log.debug('request: Creating workspace');
    final body =
        Workspace.createRequestBodyWithoutId(type: type, userId: userId);
    final response =
        await pb.collection(collectionWorkspace).create(body: body);
    _log.debug('request: Created workspace ${response.id}');

    // Import the newly created workspace
    await ref.read(workspaceImporterProvider.notifier).import(response);
  }
}
