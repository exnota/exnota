import 'package:cached_network_image/cached_network_image.dart';
import 'package:exnota/src/block/repo/drift/destination_importer.dart';
import 'package:exnota/src/block/service/destination_lister.dart';
import 'package:exnota/src/block/service/workspace_destination_suggestions.dart';
import 'package:exnota/src/block/workspace.dart';
import 'package:exnota/src/common/basic_response.dart';
import 'package:exnota/src/common/block/workspace_service.dart';
import 'package:exnota/src/common/integration/integration_service.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'setup_destination_screen.freezed.dart';
part 'setup_destination_screen.g.dart';

class SetupDestinationScreen extends ConsumerStatefulWidget {
  const SetupDestinationScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _SetupDestinationScreenState();
}

class _SetupDestinationScreenState
    extends ConsumerState<SetupDestinationScreen> {
  @override
  void initState() {
    super.initState();
    // Need to wrap in Future to avoid provider throwing an error that its
    // state was modified during the widget's lifecycle.
    Future(() {
      ref
          .read(setupDestinationScreenControllerProvider.notifier)
          .syncExternalDestinations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final setupState = ref.watch(setupDestinationScreenControllerProvider);

    // On status change, trigger the appropriate action
    ref.listen(setupDestinationScreenControllerProvider,
        (prevState, nextState) {
      // Flows:
      // - Verify and load -> Database -> (found) -> Fix/change
      // - Verify and load -> Database -> (not found) -> Create
      // - Verify and load -> Custom -> (found, connected) -> Add/remove
      // - Verify and load -> Custom -> (found, disconnected) -> Fix
      // - Verify and load -> Custom -> (not found) -> Add
      switch (nextState.status) {
        case DestinationSetupStatus.loadingDestinations:
          ref
              .read(setupDestinationScreenControllerProvider.notifier)
              .loadDestinations();
          break;
        case DestinationSetupStatus.checkingDatabaseDestinationStatus:
          ref
              .read(setupDestinationScreenControllerProvider.notifier)
              .checkDatabaseDestinationStatus();
          break;
        case DestinationSetupStatus.checkingCustomDestinationsStatus:
          ref
              .read(setupDestinationScreenControllerProvider.notifier)
              .checkCustomDestinationsStatus();
          break;
        case DestinationSetupStatus.loadingSuggestedDestinations:
          ref
              .read(setupDestinationScreenControllerProvider.notifier)
              .loadSuggestedDestinations();
          break;
        default:
        // Do nothing
      }
    });

    return Scaffold(
      body: Center(
        child: Container(
          child: switch (setupState.status) {
            DestinationSetupStatus.syncingExternalDestinations =>
              const Text('Syncing external destinations...'),
            DestinationSetupStatus.syncingExternalDestinationsError =>
              SetupErrorMessage(
                error: setupState.error!,
                errorRetryStatus: setupState.errorRetryStatus,
              ),
            DestinationSetupStatus.loadingDestinations =>
              const Text('Loading destinations...'),
            DestinationSetupStatus.loadingDestinationsError =>
              SetupErrorMessage(
                error: setupState.error!,
                errorRetryStatus: setupState.errorRetryStatus,
              ),
            DestinationSetupStatus.checkingDatabaseDestinationStatus =>
              const Text('Checking database destination status...'),
            DestinationSetupStatus.promptCurrentDatabaseDestinationAction =>
              const Text('Prompting current database destination action...'),
            DestinationSetupStatus.checkingCustomDestinationsStatus =>
              const Text('Checking custom destinations status...'),
            DestinationSetupStatus.promptCurrentCustomDestinationAction =>
              const Text('Prompting current custom destination action...'),
            DestinationSetupStatus.loadingSuggestedDestinations =>
              const Text('Loading suggested destinations...'),
            DestinationSetupStatus.loadingSuggestedDestinationsError =>
              SetupErrorMessage(
                error: setupState.error!,
                errorRetryStatus: setupState.errorRetryStatus,
              ),
            DestinationSetupStatus.selectDatabaseDestination ||
            DestinationSetupStatus.selectCustomDestinations =>
              const SelectDestination(),
            DestinationSetupStatus.updatingDatabaseDestination =>
              const Text('Updating database destination...'),
            DestinationSetupStatus.updatingDatabaseDestinationError =>
              SetupErrorMessage(
                error: setupState.error!,
                errorRetryStatus: setupState.errorRetryStatus,
              ),
            DestinationSetupStatus.updatingCustomDestinations =>
              const Text('Updating custom destinations...'),
            DestinationSetupStatus.updatingCustomDestinationError =>
              SetupErrorMessage(
                error: setupState.error!,
                errorRetryStatus: setupState.errorRetryStatus,
              ),
            DestinationSetupStatus.destinationsReady =>
              const Text('Destinations ready'),
          },
        ),
      ),
    );
  }
}

class SetupErrorMessage extends ConsumerWidget {
  final String error;
  final DestinationSetupStatus? errorRetryStatus;

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
                  .read(setupDestinationScreenControllerProvider.notifier)
                  .transitionStatus(newStatus: errorRetryStatus!);
            },
            child: const Text('Retry'),
          ),
      ],
    );
  }
}

class SelectDestination extends ConsumerWidget {
  const SelectDestination({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectMultiple =
        ref.read(setupDestinationScreenControllerProvider).status ==
            DestinationSetupStatus.selectCustomDestinations;
    final destinations = ref
            .read(setupDestinationScreenControllerProvider)
            .notionSuggestedDestinations ??
        [];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final destination in destinations)
          ListTile(
            title: Text(destination.name),
            leading: DestinationIcon(destination: destination),
            onTap: () {
              // Do something
            },
          ),
      ],
    );
  }
}

class DestinationIcon extends StatelessWidget {
  final NotionDestination destination;

  const DestinationIcon({super.key, required this.destination});

  @override
  Widget build(BuildContext context) {
    final Icon placeholder;
    switch (destination.object.type) {
      case NotionObjectType.page:
        placeholder = const Icon(Icons.article);
        break;
      case NotionObjectType.database:
        placeholder = const Icon(Icons.table_chart_rounded);
        break;
    }

    final icon = destination.icon;
    if (icon == null) {
      return placeholder;
    }

    if (icon.emoji != null) {
      return Text(
        icon.emoji!,
        style: const TextStyle(fontSize: 19),
      );
    }

    final url = icon.url;
    if (url != null && url.endsWith('.svg')) {
      return SvgPicture.network(
        url,
        width: 24,
        height: 24,
        placeholderBuilder: (context) => placeholder,
      );
    } else if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        width: 24,
        height: 24,
        errorWidget: (context, url, error) => placeholder,
        placeholder: (context, url) => placeholder,
      );
    }

    return placeholder;
  }
}

enum DestinationSetupStatus {
  syncingExternalDestinations, // Sends request to update destination info from external service
  syncingExternalDestinationsError,
  loadingDestinations, // Updates destinations in local database
  loadingDestinationsError,
  checkingDatabaseDestinationStatus, // Determines what prompt to show the user
  promptCurrentDatabaseDestinationAction, // Ask to keep, fix or change
  checkingCustomDestinationsStatus, // Determines what prompt to show the user
  promptCurrentCustomDestinationAction, // Ask whether to fix connection issues
  loadingSuggestedDestinations,
  loadingSuggestedDestinationsError,
  selectDatabaseDestination, // Ask to select a database destination
  selectCustomDestinations, // Ask to add/remove custom destinations
  updatingDatabaseDestination, // Processes database destination changes
  updatingDatabaseDestinationError,
  updatingCustomDestinations, // Processes custom destination changes
  updatingCustomDestinationError,
  destinationsReady, // Completed.
}

@Freezed(copyWith: false)
class DestinationSetupState with _$DestinationSetupState {
  const factory DestinationSetupState({
    required DestinationSetupStatus status,
    required List<NotionDestination>? notionSuggestedDestinations,
    required String? error,
    required DestinationSetupStatus? errorRetryStatus,
  }) = _DestinationSetupState;
}

@riverpod
class SetupDestinationScreenController
    extends _$SetupDestinationScreenController {
  final _log = Logger(context: 'SetupDestinationScreenController');

  @override
  DestinationSetupState build() {
    _log.debug('build: Initializing state with status verifyingDestinations');
    return const DestinationSetupState(
      status: DestinationSetupStatus.syncingExternalDestinations,
      notionSuggestedDestinations: null,
      error: null,
      errorRetryStatus: null,
    );
  }

  // Transition to a new state status
  void transitionStatus({required DestinationSetupStatus newStatus}) {
    state = DestinationSetupState(
      status: newStatus,
      notionSuggestedDestinations: state.notionSuggestedDestinations,
      error: null,
      errorRetryStatus: null,
    );
  }

  Future<void> syncExternalDestinations() async {
    final workspace = (await ref.read(activeWorkspaceProvider.future))!;
    final integrationId = workspace.integrationId;
    if (integrationId == null) {
      _log.error('syncExistingDestinations: No integration found');
      state = const DestinationSetupState(
        status: DestinationSetupStatus.syncingExternalDestinationsError,
        notionSuggestedDestinations: null,
        error: 'Workspace not integrated',
        errorRetryStatus: DestinationSetupStatus.syncingExternalDestinations,
      );
      return;
    }

    final response = await ref
        .read(integrationServiceProvider.notifier)
        .syncIntegrationDestinations(integrationId: integrationId);
    switch (response) {
      case BasicResponseSuccess():
        _log.debug('syncExistingDestinations: Success');
        state = const DestinationSetupState(
          status: DestinationSetupStatus.loadingDestinations,
          notionSuggestedDestinations: null,
          error: null,
          errorRetryStatus: null,
        );
        break;
      case BasicResponseError(:final error):
        _log.error('syncExistingDestinations: Error');
        state = DestinationSetupState(
          status: DestinationSetupStatus.syncingExternalDestinationsError,
          notionSuggestedDestinations: null,
          error: error,
          errorRetryStatus: DestinationSetupStatus.syncingExternalDestinations,
        );
        break;
    }
  }

  Future<void> loadDestinations() async {
    final workspace = (await ref.read(activeWorkspaceProvider.future))!;

    final result =
        await ref.read(destinationImporterProvider.notifier).importForWorkspace(
              workspaceId: workspace.id,
            );
    switch (result) {
      case BasicResponseSuccess():
        _log.debug('loadDestinations: Success');
        if (workspace.type == WorkspaceType.database) {
          state = const DestinationSetupState(
            status: DestinationSetupStatus.checkingDatabaseDestinationStatus,
            notionSuggestedDestinations: null,
            error: null,
            errorRetryStatus: null,
          );
        } else {
          state = const DestinationSetupState(
            status: DestinationSetupStatus.checkingCustomDestinationsStatus,
            notionSuggestedDestinations: null,
            error: null,
            errorRetryStatus: null,
          );
        }
        return;
      case BasicResponseError(:final error):
        _log.error('loadDestinations: Error');
        state = DestinationSetupState(
          status: DestinationSetupStatus.loadingDestinationsError,
          notionSuggestedDestinations: null,
          error: error,
          errorRetryStatus: DestinationSetupStatus.loadingDestinations,
        );
        return;
    }
  }

  Future<void> checkDatabaseDestinationStatus() async {
    final destinations = await ref.read(destinationListerProvider.future);
    if (destinations.isEmpty) {
      _log.debug('checkDatabaseDestinationStatus: No destinations found');
      state = const DestinationSetupState(
        status: DestinationSetupStatus.loadingSuggestedDestinations,
        notionSuggestedDestinations: null,
        error: null,
        errorRetryStatus: null,
      );
      return;
    }

    state = const DestinationSetupState(
      status: DestinationSetupStatus.promptCurrentDatabaseDestinationAction,
      notionSuggestedDestinations: null,
      error: null,
      errorRetryStatus: null,
    );
  }

  Future<void> checkCustomDestinationsStatus() async {
    final destinations = await ref.read(destinationListerProvider.future);
    if (destinations.isEmpty) {
      _log.debug('checkCustomDestinationsStatus: No destinations found');
      state = const DestinationSetupState(
        status: DestinationSetupStatus.loadingSuggestedDestinations,
        notionSuggestedDestinations: null,
        error: null,
        errorRetryStatus: null,
      );
      return;
    }

    state = const DestinationSetupState(
      status: DestinationSetupStatus.promptCurrentCustomDestinationAction,
      notionSuggestedDestinations: null,
      error: null,
      errorRetryStatus: null,
    );
  }

  Future<void> loadSuggestedDestinations() async {
    final suggestionResponse =
        await ref.read(workspaceDestinationSuggestionsProvider.notifier).get();
    switch (suggestionResponse) {
      case BasicResponseSuccess(:final result):
        _log.debug('loadSuggestedDestinations: Success');

        state = DestinationSetupState(
          status: DestinationSetupStatus.selectDatabaseDestination,
          notionSuggestedDestinations: result.notionDestinations,
          error: null,
          errorRetryStatus: null,
        );
        return;
      case BasicResponseError(:final error):
        _log.error('loadSuggestedDestinations: Error');
        state = DestinationSetupState(
          status: DestinationSetupStatus.loadingSuggestedDestinationsError,
          notionSuggestedDestinations: null,
          error: error,
          errorRetryStatus: DestinationSetupStatus.loadingSuggestedDestinations,
        );
        return;
    }
  }
}
