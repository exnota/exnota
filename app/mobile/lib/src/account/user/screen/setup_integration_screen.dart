import 'package:exnota/src/account/user/integration.dart';
import 'package:exnota/src/account/user/service/integration_fetcher.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'setup_integration_screen.freezed.dart';
part 'setup_integration_screen.g.dart';

class SetupIntegrationScreen extends ConsumerStatefulWidget {
  const SetupIntegrationScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _SetupIntegrationScreenState();
}

class _SetupIntegrationScreenState
    extends ConsumerState<SetupIntegrationScreen> {
  @override
  void initState() {
    super.initState();
    ref
        .read(setupIntegrationScreenControllerProvider.notifier)
        .loadIntegration();
  }

  @override
  Widget build(BuildContext context) {
    final setupState = ref.watch(setupIntegrationScreenControllerProvider);
    ref.listen(setupIntegrationScreenControllerProvider,
        (prevState, nextState) {
      switch (nextState.status) {
        case IntegrationSetupStatus.loadingIntegration:
          ref
              .read(setupIntegrationScreenControllerProvider.notifier)
              .loadIntegration();
          break;
        case IntegrationSetupStatus.verifyingIntegration:
          ref
              .read(setupIntegrationScreenControllerProvider.notifier)
              .verifyIntegration();
          break;
        case IntegrationSetupStatus.confirmedNotionIntegration:
        // TODO: Redirect to other screen
        default:
        // TODO:
      }
    });

    // TODO: Do a basic switch here showing the state it can be tested
    return Scaffold(
      body: Center(
        child: Container(
          child: switch (setupState.status) {
            IntegrationSetupStatus.loadingIntegration =>
              const Text('Loading integration'),
            IntegrationSetupStatus.verifyingIntegration =>
              const Text('Verifying integration'),
            IntegrationSetupStatus.createNotionIntegration =>
              const Text('Create Notion integration'),
            IntegrationSetupStatus.notionAuthError =>
              const Text('Notion disconnected'),
            IntegrationSetupStatus.creatingNotionIntegration =>
              const Text('Creating Notion integration'),
            IntegrationSetupStatus.updatingNotionIntegration =>
              const Text('Updating Notion integration'),
            IntegrationSetupStatus.confirmedNotionIntegration =>
              const Text('Confirmed Notion integration'),
            IntegrationSetupStatus.loadingIntegrationError => SetupErrorMessage(
                error: setupState.error!,
                errorRetryStatus: setupState.errorRetryStatus,
              ),
            IntegrationSetupStatus.verifyingIntegrationError =>
              SetupErrorMessage(
                error: setupState.error!,
                errorRetryStatus: setupState.errorRetryStatus,
              ),
          },
        ),
      ),
    );
  }
}

class SetupErrorMessage extends ConsumerWidget {
  final String error;
  final IntegrationSetupStatus? errorRetryStatus;

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
                  .read(setupIntegrationScreenControllerProvider.notifier)
                  .setStateStatus(newState: errorRetryStatus!);
            },
            child: const Text('Retry'),
          ),
      ],
    );
  }
}

//generate controller that exposes and manages state for the screen that includes: loadingIntegration, createNotionIntegration,notionAuthError,creatingNotionIntegration,updatingNotionIntegration

enum IntegrationSetupStatus {
  loadingIntegration,
  loadingIntegrationError,
  verifyingIntegration,
  verifyingIntegrationError,
  createNotionIntegration,
  notionAuthError,
  creatingNotionIntegration,
  updatingNotionIntegration,
  confirmedNotionIntegration,
}

@Freezed(copyWith: false)
class IntegrationSetupState with _$IntegrationSetupState {
  const factory IntegrationSetupState({
    required IntegrationSetupStatus status,
    required Integration? integration,
    required String? error,
    required IntegrationSetupStatus? errorRetryStatus,
  }) = _IntegrationSetupState;
}

@riverpod
class SetupIntegrationScreenController
    extends _$SetupIntegrationScreenController {
  final _log = Logger(context: 'SetupIntegrationScreenController');

  @override
  IntegrationSetupState build() {
    return const IntegrationSetupState(
      status: IntegrationSetupStatus.loadingIntegration,
      integration: null,
      error: null,
      errorRetryStatus: null,
    );
  }

  void setStateStatus({required IntegrationSetupStatus newState}) {
    state = IntegrationSetupState(
      status: newState,
      integration: state.integration,
      error: null,
      errorRetryStatus: null,
    );
  }

  Future<void> loadIntegration() async {
    _log.debug('loadIntegration: Loading integration');
    final result = await ref.read(integrationFetcherProvider.notifier).fetch(
          type: IntegrationType.notion,
        );

    if (result.error != null) {
      _log.error('loadIntegration: Error loading integration: ${result.error}');
      state = IntegrationSetupState(
        status: IntegrationSetupStatus.loadingIntegrationError,
        integration: null,
        error: result.error,
        errorRetryStatus: IntegrationSetupStatus.loadingIntegration,
      );
      return;
    }

    if (result.integration == null) {
      _log.debug('loadIntegration: No integration found');
      state = const IntegrationSetupState(
        status: IntegrationSetupStatus.createNotionIntegration,
        integration: null,
        error: null,
        errorRetryStatus: null,
      );
      return;
    }

    _log.debug('loadIntegration: Integration found');
    state = IntegrationSetupState(
      status: IntegrationSetupStatus.verifyingIntegration,
      integration: result.integration,
      error: null,
      errorRetryStatus: null,
    );
  }

  Future<void> verifyIntegration() async {
    _log.debug('verifyIntegration: Verifying integration');
    final integration = state.integration;
    if (integration == null) {
      _log.error('verifyIntegration: No integration found');
      state = const IntegrationSetupState(
        status: IntegrationSetupStatus.verifyingIntegrationError,
        integration: null,
        error: 'No integration found',
        errorRetryStatus: IntegrationSetupStatus.loadingIntegration,
      );
      return;
    }

    // TODO: Verify
    final verifyResult = await ref
        .read(integrationFetcherProvider.notifier)
        .verify(integration.id);
    if (verifyResult.error != null) {
      _log.error(
          'verifyIntegration: Error verifying integration: ${verifyResult.error}');
      state = IntegrationSetupState(
        status: IntegrationSetupStatus.verifyingIntegrationError,
        integration: integration,
        error: verifyResult.error,
        errorRetryStatus: IntegrationSetupStatus.verifyingIntegration,
      );
      return;
    }

    if (!verifyResult.success) {
      _log.error('verifyIntegration: Integration verification unsuccessful');
      state = IntegrationSetupState(
        status: IntegrationSetupStatus.notionAuthError,
        integration: integration,
        error: null,
        errorRetryStatus: null,
      );
      return;
    }

    _log.debug('verifyIntegration: Integration verified');
    state = IntegrationSetupState(
      status: IntegrationSetupStatus.confirmedNotionIntegration,
      integration: integration,
      error: null,
      errorRetryStatus: null,
    );
  }
}
