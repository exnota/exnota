import 'package:exnota/src/common/basic_response.dart';
import 'package:exnota/src/common/block/workspace_service.dart';
import 'package:exnota/src/common/integration/integration_service.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
          .syncExistingDestinations();
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
        // case DestinationSetupStatus.verifyingDestinations:
        //   ref
        //       .read(setupDestinationScreenControllerProvider.notifier)
        //       .syncExistingDestinations();
        // break;
        default:
        // Do nothing
      }
    });

    return Scaffold(
      body: Center(
        child: Container(
          child: switch (setupState.status) {
            DestinationSetupStatus.verifyingDestinations =>
              const Text('Verifying destinations...'),
            DestinationSetupStatus.verifyingDestinationsError =>
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
            DestinationSetupStatus.selectDatabaseDestination =>
              const Text('Select database destination...'),
            DestinationSetupStatus.selectCustomDestinations =>
              const Text('Select custom destinations...'),
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

enum DestinationSetupStatus {
  verifyingDestinations, // Sends request to update connection status of destinations
  verifyingDestinationsError,
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
    // required Destination? destination,
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
      status: DestinationSetupStatus.verifyingDestinations,
      error: null,
      errorRetryStatus: null,
    );
  }

  // Transition to a new state status
  void transitionStatus({required DestinationSetupStatus newStatus}) {
    state = DestinationSetupState(
      status: newStatus,
      error: null,
      errorRetryStatus: null,
    );
  }

  Future<void> syncExistingDestinations() async {
    final workspace = await ref.read(activeWorkspaceProvider.future);
    if (workspace == null) {
      _log.error('syncExistingDestinations: No workspace found');
      state = const DestinationSetupState(
        status: DestinationSetupStatus.verifyingDestinationsError,
        error: 'No active workspace',
        errorRetryStatus: DestinationSetupStatus.verifyingDestinations,
      );
      return;
    }

    final integrationId = workspace.integrationId;
    if (integrationId == null) {
      _log.error('syncExistingDestinations: No integration found');
      state = const DestinationSetupState(
        status: DestinationSetupStatus.verifyingDestinationsError,
        error: 'Workspace not integrated',
        errorRetryStatus: DestinationSetupStatus.verifyingDestinations,
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
          error: null,
          errorRetryStatus: null,
        );
        break;
      case BasicResponseError(:final error):
        _log.error('syncExistingDestinations: Error');
        state = DestinationSetupState(
          status: DestinationSetupStatus.verifyingDestinationsError,
          error: error,
          errorRetryStatus: DestinationSetupStatus.verifyingDestinations,
        );
        break;
    }
  }
}
