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
            IntegrationSetupStatus.loadingIntegrationError =>
              Text('Error loading integration: ${setupState.error}'),
            IntegrationSetupStatus.verifyingIntegration =>
              const Text('Verifying integration'),
            IntegrationSetupStatus.verifyingIntegrationError =>
              Text('Error verifying integration: ${setupState.error}'),
            IntegrationSetupStatus.createNotionIntegration =>
              const Text('Create Notion integration'),
            IntegrationSetupStatus.notionAuthError =>
              Text('Notion auth error: ${setupState.error}'),
            IntegrationSetupStatus.creatingNotionIntegration =>
              const Text('Creating Notion integration'),
            IntegrationSetupStatus.updatingNotionIntegration =>
              const Text('Updating Notion integration'),
          },
        ),
      ),
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
}

@Freezed(copyWith: false)
class IntegrationSetupState with _$IntegrationSetupState {
  const factory IntegrationSetupState({
    required IntegrationSetupStatus status,
    required Integration? integration,
    required String? error,
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
        error: null);
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
          error: result.error);
      return;
    }

    if (result.integration == null) {
      _log.debug('loadIntegration: No integration found');
      state = const IntegrationSetupState(
          status: IntegrationSetupStatus.createNotionIntegration,
          integration: null,
          error: null);
      return;
    }

    _log.debug('loadIntegration: Integration found');
    state = IntegrationSetupState(
      status: IntegrationSetupStatus.verifyingIntegration,
      integration: result.integration,
      error: null,
    );
  }

  Future<void> verifyIntegration() async {
    _log.debug('testIntegration: Testing integration');
    final integration = state.integration;
    if (integration == null) {
      _log.error('testIntegration: No integration found');
      state = const IntegrationSetupState(
          status: IntegrationSetupStatus.verifyingIntegrationError,
          integration: null,
          error: 'No integration found');
      return;
    }
  }
}
