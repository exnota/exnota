import 'package:exnota/src/integration/integration.dart';
import 'package:exnota/src/integration/service/integration_fetcher.dart';
import 'package:exnota/src/integration/service/notion_auth_service.dart';
import 'package:exnota/src/integration/widget/notion_listener.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

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

    // TODO: If there's a code, skip to validation/processing step
    // TODO: If there's no workspace ready, go back to workspace screen

    // Set state for consistency with above, even though at time of writing this
    // is the default state
    //
    // Need to wrap in Future to avoid provider throwing an error that its
    // state was modified during the widget's lifecycle.
    Future(() {
      ref
          .read(setupIntegrationScreenControllerProvider.notifier)
          .transitionStatus(
            newStatus: IntegrationSetupStatus.loadingIntegration,
          );
      ref
          .read(setupIntegrationScreenControllerProvider.notifier)
          .loadIntegration();
    });
  }

  @override
  Widget build(BuildContext context) {
    final setupState = ref.watch(setupIntegrationScreenControllerProvider);

    // When code is received, close browser and transition to processing code
    ref.listen(notionAuthProvider, (prevAuth, nextAuth) async {
      final prevCode = prevAuth?.code ?? '';
      final nextCode = nextAuth.code ?? '';
      if (prevCode != nextCode) {
        ref
            .read(setupIntegrationScreenControllerProvider.notifier)
            .transitionStatus(
                newStatus: IntegrationSetupStatus.exchangingNotionCodeForToken);

        // Close manually, otherwise browser stays open in iOS
        await closeInAppWebView();
      }
    });

    // On status change, trigger the appropriate action
    ref.listen(setupIntegrationScreenControllerProvider,
        (prevState, nextState) {
      // Flows:
      // Load -> (found) -> Verify -> (connected) -> Confirmed
      // Load -> (found) -> Verify -> (disconnected) -> Update -> Confirmed
      // Load -> (not found) -> Create
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
        case IntegrationSetupStatus.runningNotionAuthCodeFlow:
          ref
              .read(setupIntegrationScreenControllerProvider.notifier)
              .startNotionAuthFlow();
          break;
        case IntegrationSetupStatus.exchangingNotionCodeForToken:
          ref
              .read(setupIntegrationScreenControllerProvider.notifier)
              .handleNotionAuthResponse();
        case IntegrationSetupStatus.confirmedNotionIntegration:
          // TODO: Redirect to other screen
          break;
        default:
        // TODO:
      }
    });

    return Scaffold(
      body: Center(
        child: Container(
          child: switch (setupState.status) {
            IntegrationSetupStatus.exchangingNotionCodeForToken =>
              const Text('Handling notion auth response'),
            IntegrationSetupStatus.loadingIntegration =>
              const Text('Loading integration'),
            IntegrationSetupStatus.verifyingIntegration =>
              const Text('Verifying integration'),
            IntegrationSetupStatus.createNotionIntegration => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Create Notion integration'),
                  ElevatedButton(
                    onPressed: () {
                      ref
                          .read(
                              setupIntegrationScreenControllerProvider.notifier)
                          .transitionStatus(
                            newStatus: IntegrationSetupStatus
                                .runningNotionAuthCodeFlow,
                          );
                    },
                    child: const Text('Connect'),
                  ),
                ],
              ),
            IntegrationSetupStatus.updateNotionIntegration => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Notion disconnected'),
                  ElevatedButton(
                    onPressed: () {
                      ref
                          .read(
                              setupIntegrationScreenControllerProvider.notifier)
                          .transitionStatus(
                            newStatus: IntegrationSetupStatus
                                .runningNotionAuthCodeFlow,
                          );
                    },
                    child: const Text('Reconnect Notion'),
                  ),
                ],
              ),
            IntegrationSetupStatus.runningNotionAuthCodeFlow =>
              const Text('Running notion auth flow'),
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
            IntegrationSetupStatus.runningNotionAuthCodeFlowError =>
              SetupErrorMessage(
                error: setupState.error!,
                errorRetryStatus: setupState.errorRetryStatus,
              ),
            IntegrationSetupStatus.exchangingNotionCodeForTokenError =>
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
                  .transitionStatus(newStatus: errorRetryStatus!);
            },
            child: const Text('Retry'),
          ),
      ],
    );
  }
}

enum IntegrationSetupStatus {
  loadingIntegration, // Fetch integration from backend
  loadingIntegrationError,
  verifyingIntegration, // Verify that existing integration is connected
  verifyingIntegrationError,
  createNotionIntegration, // Prompt user to create a Notion integration
  updateNotionIntegration, // Prompt user to update a Notion integration
  runningNotionAuthCodeFlow, // Start Notion auth flow
  runningNotionAuthCodeFlowError,
  exchangingNotionCodeForToken, // Create/update integration from auth response
  exchangingNotionCodeForTokenError,
  confirmedNotionIntegration, // Integration successfully created/updated
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
    _log.debug('build: Initializing state with status loadingIntegration');
    return const IntegrationSetupState(
      status: IntegrationSetupStatus.loadingIntegration,
      integration: null,
      error: null,
      errorRetryStatus: null,
    );
  }

  // Transition to a new state status
  void transitionStatus({required IntegrationSetupStatus newStatus}) {
    state = IntegrationSetupState(
      status: newStatus,
      integration: state.integration,
      error: null,
      errorRetryStatus: null,
    );
  }

  // Fetches integration from backend and saves to this provider's state
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

    final notionAuth = ref.read(notionAuthProvider);
    if (notionAuth.code != null) {
      _log.debug('loadIntegration: Code found');
      state = IntegrationSetupState(
        status: IntegrationSetupStatus.exchangingNotionCodeForToken,
        integration: result.integration,
        error: null,
        errorRetryStatus: null,
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

  Future<void> handleNotionAuthResponse() async {
    final code = ref.read(notionAuthProvider).code;

    // If there's an integration, update it
    if (state.integration != null) {
      _log.debug('handleNotionCode: Updating integration');
      switch (state.integration!.type) {
        case IntegrationType.notion:
          final updateResult = await ref
              .read(notionAuthServiceProvider.notifier)
              .updateIntegration(
                integrationId: state.integration!.id,
                code: code!,
              );
          if (updateResult.error != null) {
            _log.error(
                'handleNotionCode: Error creating integration: ${updateResult.error}');
            state = IntegrationSetupState(
              status: IntegrationSetupStatus.exchangingNotionCodeForTokenError,
              integration: state.integration,
              error: updateResult.error,
              errorRetryStatus: IntegrationSetupStatus.loadingIntegration,
            );
            return;
          }

          // TODO: Move on to next step?
          _log.debug('handleNotionCode: Integration updated');
          state = IntegrationSetupState(
            status: IntegrationSetupStatus.confirmedNotionIntegration,
            integration: state.integration,
            error: null,
            errorRetryStatus: null,
          );
          break;
        default:
          _log.error('handleNotionCode: Unsupported integration type');
          state = IntegrationSetupState(
            status: IntegrationSetupStatus.exchangingNotionCodeForTokenError,
            integration: state.integration,
            error: 'Unsupported integration type',
            errorRetryStatus: IntegrationSetupStatus.loadingIntegration,
          );
          return;
      }
      return;
    }

    // If there's no integration, create it
    _log.debug('handleNotionCode: Creating integration');
    final createResult = await ref
        .read(notionAuthServiceProvider.notifier)
        .createIntegration(code: code!);
    if (createResult.error != null) {
      _log.error(
          'handleNotionCode: Error creating integration: ${createResult.error}');
      state = IntegrationSetupState(
        status: IntegrationSetupStatus.exchangingNotionCodeForTokenError,
        integration: null,
        error: createResult.error,
        errorRetryStatus: IntegrationSetupStatus.loadingIntegration,
      );
      return;
    }

    _log.debug('handleNotionCode: Integration created');
    state = IntegrationSetupState(
      status: IntegrationSetupStatus.confirmedNotionIntegration,
      integration: createResult.result,
      error: null,
      errorRetryStatus: null,
    );
  }

  // Calls backend to check if auth token is still valid
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
      _log.debug('verifyIntegration: Integration verification unsuccessful');
      state = IntegrationSetupState(
        status: IntegrationSetupStatus.updateNotionIntegration,
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

  Future<void> startNotionAuthFlow() async {
    final authUrlResponse =
        await ref.read(notionAuthServiceProvider.notifier).getAuthUrl();

    if (authUrlResponse.error != null) {
      _log.error('updateIntegration: Error getting auth url');
      state = IntegrationSetupState(
        status: IntegrationSetupStatus.runningNotionAuthCodeFlowError,
        integration: state.integration,
        error: authUrlResponse.error,
        errorRetryStatus: IntegrationSetupStatus.loadingIntegration,
      );
      return;
    }

    final url = authUrlResponse.result;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      _log.debug('updateIntegration: Opening browser for uri $uri');
      // Defaults to web view. If `mode: LaunchMode.externalApplication` is used
      // instead it would avoid requiring Notion login for users already logged
      // in in their default browser. However after finishing auth, it will ask
      // "Open this page in "Exnota"" before going back to the app. Might be
      // able to avoid this if we used universal links instead of deep links.
      await launchUrl(uri);
    } else {
      _log.error('updateIntegration: Error opening browser');
      state = IntegrationSetupState(
        status: IntegrationSetupStatus.runningNotionAuthCodeFlowError,
        integration: state.integration,
        error: 'Error opening browser',
        errorRetryStatus: IntegrationSetupStatus.loadingIntegration,
      );
    }
  }
}
