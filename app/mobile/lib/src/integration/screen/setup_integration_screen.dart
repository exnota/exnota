import 'dart:async';

import 'package:exnota/src/common/basic_response.dart';
import 'package:exnota/src/context/app/router.dart';
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
  final bool forceReauth;

  const SetupIntegrationScreen({super.key, this.forceReauth = false});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _SetupIntegrationScreenState();
}

class _SetupIntegrationScreenState
    extends ConsumerState<SetupIntegrationScreen> {
  final _log = Logger(context: 'SetupIntegrationScreen');
  late final AppLifecycleListener _appLifecycleListener;
  Timer? abortCodeFlowTimer;

  @override
  void initState() {
    super.initState();
    _log.debug('Initializing');

    // Need to wrap in Future to avoid provider throwing an error that its
    // state was modified during the widget's lifecycle.
    Future(() {
      ref
          .read(setupIntegrationScreenControllerProvider.notifier)
          .loadIntegration(forceReauth: widget.forceReauth);
    });

    // Handle user aborting Notion auth code flow
    _appLifecycleListener = AppLifecycleListener(
      onResume: () {
        if (ref.read(setupIntegrationScreenControllerProvider).status !=
            IntegrationSetupStatus.runningNotionAuthCodeFlow) {
          return;
        }

        _log.debug('App resumed during Notion auth code flow');

        // Wait 3 seconds (arbitrary) for the code to be received, if the flow
        // was completed successfully.
        abortCodeFlowTimer?.cancel();
        abortCodeFlowTimer = Timer(const Duration(seconds: 3), () async {
          // Abort if code was received
          if (ref.read(setupIntegrationScreenControllerProvider).status !=
              IntegrationSetupStatus.runningNotionAuthCodeFlow) {
            return;
          }

          ref
              .read(setupIntegrationScreenControllerProvider.notifier)
              .transitionStatus(newStatus: IntegrationSetupStatus.instructions);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("That didn't work. Please try again."),
            ),
          );
        });
      },
    );
  }

  @override
  void dispose() {
    _log.debug('Disposing');
    _appLifecycleListener.dispose();
    abortCodeFlowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setupState = ref.watch(setupIntegrationScreenControllerProvider);

    // When code is received, close browser and transition to processing code
    ref.listen(notionAuthProvider, (prevAuth, nextAuth) async {
      final prevCode = prevAuth?.value?.code ?? '';
      final nextCode = nextAuth.value?.code ?? '';
      if (prevCode != nextCode && nextCode.isNotEmpty) {
        ref
            .read(setupIntegrationScreenControllerProvider.notifier)
            .transitionStatus(
                newStatus: IntegrationSetupStatus.upsertingIntegration);

        // Close manually, otherwise browser stays open in iOS
        await closeInAppWebView();
      }
    });

    // On status change, trigger the appropriate action
    ref.listen(setupIntegrationScreenControllerProvider,
        (prevState, nextState) {
      switch (nextState.status) {
        case IntegrationSetupStatus.loadingIntegration:
          ref
              .read(setupIntegrationScreenControllerProvider.notifier)
              .loadIntegration(forceReauth: false);
          break;
        case IntegrationSetupStatus.runningNotionAuthCodeFlow:
          ref
              .read(setupIntegrationScreenControllerProvider.notifier)
              .runNotionAuthCodeFlow();
          break;
        case IntegrationSetupStatus.upsertingIntegration:
          ref
              .read(setupIntegrationScreenControllerProvider.notifier)
              .upsertIntegration();
        case IntegrationSetupStatus.complete:
          // TODO: revert
          // ref
          //     .read(routerProvider.notifier)
          //     .pushReplacement(Screen.settingsSetupDestination);
          break;
        default:
        // Do nothing. User action expected.
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Notion Connection'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              ref.read(routerProvider.notifier).pop();
            },
          ),
        ],
      ),
      body: Center(
        child: Container(
          child: switch (setupState.status) {
            IntegrationSetupStatus.loadingIntegration =>
              const Text('Loading integration'),
            IntegrationSetupStatus.loadingIntegrationError => SetupErrorMessage(
                error: setupState.error!,
                errorRetryStatus: setupState.errorRetryStatus,
              ),
            IntegrationSetupStatus.instructions => Column(
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
            IntegrationSetupStatus.runningNotionAuthCodeFlow =>
              const Text('Running Notion auth code flow'),
            IntegrationSetupStatus.runningNotionAuthCodeFlowError =>
              SetupErrorMessage(
                error: setupState.error!,
                errorRetryStatus: setupState.errorRetryStatus,
              ),
            IntegrationSetupStatus.upsertingIntegration =>
              const Text('Upserting integration'),
            IntegrationSetupStatus.upsertingIntegrationError =>
              SetupErrorMessage(
                error: setupState.error!,
                errorRetryStatus: setupState.errorRetryStatus,
              ),
            IntegrationSetupStatus.complete =>
              const Text('Integration setup complete'),
          },
        ),
      ),
    );
  }
}

class Instructions extends ConsumerWidget {
  const Instructions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Create Notion integration'),
        ElevatedButton(
          onPressed: () {
            ref
                .read(setupIntegrationScreenControllerProvider.notifier)
                .transitionStatus(
                  newStatus: IntegrationSetupStatus.runningNotionAuthCodeFlow,
                );
          },
          child: const Text('Connect'),
        ),
      ],
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
          Row(
            children: [
              ElevatedButton(
                onPressed: () {
                  ref.read(routerProvider.notifier).pop();
                },
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  // Clear token. This is a bit of a hack to ensure the flow truly
                  // starts from the beginning. It shouldn't go in the loading
                  // integration method because we may load this screen with a valid
                  // code ready to go.
                  // TODO: Uncomment if we need this at this point
                  // ref.read(notionAuthProvider.notifier).clearCode();

                  ref
                      .read(setupIntegrationScreenControllerProvider.notifier)
                      .transitionStatus(newStatus: errorRetryStatus!);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
      ],
    );
  }
}

enum IntegrationSetupStatus {
  loadingIntegration, // Fetch integration from backend
  loadingIntegrationError,
  instructions,

  runningNotionAuthCodeFlow, // Start Notion auth flow
  runningNotionAuthCodeFlowError,

  upsertingIntegration, // Create/update integration from auth response
  upsertingIntegrationError,
  complete,
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
  Future<void> loadIntegration({required bool forceReauth}) async {
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

    final notionAuth = await ref.read(notionAuthProvider.future);
    if (notionAuth.code != null) {
      _log.debug('loadIntegration: Code found');
      state = IntegrationSetupState(
        status: IntegrationSetupStatus.upsertingIntegration,
        integration: result.integration,
        error: null,
        errorRetryStatus: null,
      );
      return;
    }

    if (result.integration == null) {
      _log.debug('loadIntegration: No integration found');
      state = const IntegrationSetupState(
        status: IntegrationSetupStatus.instructions,
        integration: null,
        error: null,
        errorRetryStatus: null,
      );
      return;
    }

    if (forceReauth) {
      _log.debug('loadIntegration: Forcing reauth');
      state = IntegrationSetupState(
        status: IntegrationSetupStatus.instructions,
        integration: result.integration,
        error: null,
        errorRetryStatus: null,
      );
      return;
    }

    _log.debug('loadIntegration: Integration found');
    state = IntegrationSetupState(
      status: IntegrationSetupStatus.complete,
      integration: result.integration,
      error: null,
      errorRetryStatus: null,
    );
  }

  Future<void> upsertIntegration() async {
    final code = (await ref.read(notionAuthProvider.future)).code;

    // If there's an integration, update it
    if (state.integration != null) {
      _log.debug('upsertIntegration: Updating integration');
      switch (state.integration!.type) {
        case IntegrationType.notion:
          // TODO: If code is invalid, backend should return a code for that and
          // we should clear it from the provider.
          final updateResult = await ref
              .read(notionAuthServiceProvider.notifier)
              .updateIntegration(
                integrationId: state.integration!.id,
                code: code!,
              );
          switch (updateResult) {
            case BasicResponseSuccess():
              break;
            case BasicResponseError(
                error: final error,
                errorCode: final errorCode
              ):
              if (errorCode == 'invalid_notion_code') {
                _log.warn('upsertIntegration: Invalid Notion code');
                await ref.read(notionAuthProvider.notifier).clearCode();
              } else {
                _log.error(
                    'upsertIntegration: Error creating integration: ${updateResult.error}');
              }
              state = IntegrationSetupState(
                status: IntegrationSetupStatus.upsertingIntegrationError,
                integration: state.integration,
                error: error,
                errorRetryStatus: IntegrationSetupStatus.loadingIntegration,
              );
              return;
          }

          await ref.read(notionAuthProvider.notifier).clearCode();

          _log.debug('upsertIntegration: Integration updated');
          state = IntegrationSetupState(
            status: IntegrationSetupStatus.complete,
            integration: state.integration,
            error: null,
            errorRetryStatus: null,
          );
          break;
        default:
          _log.error('upsertIntegration: Unsupported integration type');
          state = IntegrationSetupState(
            status: IntegrationSetupStatus.upsertingIntegrationError,
            integration: state.integration,
            error: 'Unsupported integration type',
            errorRetryStatus: IntegrationSetupStatus.loadingIntegration,
          );
          return;
      }
      return;
    }

    // Create integration
    //
    // TODO: If code is invalid, backend should return a code for that and
    // we should clear it from the provider.
    final createResult = await ref
        .read(notionAuthServiceProvider.notifier)
        .createIntegration(code: code!);
    switch (createResult) {
      case BasicResponseSuccess():
        break;
      case BasicResponseError(error: final error, errorCode: final errorCode):
        if (errorCode == 'invalid_notion_code') {
          _log.warn('upsertIntegration: Invalid Notion code');
          await ref.read(notionAuthProvider.notifier).clearCode();
        } else {
          _log.error(
              'upsertIntegration: Error creating integration: ${createResult.error}');
        }

        state = IntegrationSetupState(
          status: IntegrationSetupStatus.upsertingIntegrationError,
          integration: null,
          error: error,
          errorRetryStatus: IntegrationSetupStatus.loadingIntegration,
        );
        return;
    }

    await ref.read(notionAuthProvider.notifier).clearCode();

    _log.debug('upsertIntegration: Integration created');
    state = IntegrationSetupState(
      status: IntegrationSetupStatus.complete,
      integration: createResult.result,
      error: null,
      errorRetryStatus: null,
    );
  }

  // // Calls backend to check if auth token is still valid
  // Future<void> verifyIntegration() async {
  //   _log.debug('verifyIntegration: Verifying integration');
  //   final integration = state.integration;
  //   if (integration == null) {
  //     _log.error('verifyIntegration: No integration found');
  //     state = const IntegrationSetupState(
  //       status: IntegrationSetupStatus.verifyingIntegrationError,
  //       integration: null,
  //       error: 'No integration found',
  //       errorRetryStatus: IntegrationSetupStatus.loadingIntegration,
  //     );
  //     return;
  //   }

  //   final verifyResult = await ref
  //       .read(integrationFetcherProvider.notifier)
  //       .verify(integration.id);
  //   if (verifyResult.error != null) {
  //     _log.error(
  //         'verifyIntegration: Error verifying integration: ${verifyResult.error}');
  //     state = IntegrationSetupState(
  //       status: IntegrationSetupStatus.verifyingIntegrationError,
  //       integration: integration,
  //       error: verifyResult.error,
  //       errorRetryStatus: IntegrationSetupStatus.verifyingIntegration,
  //     );
  //     return;
  //   }

  //   if (!verifyResult.success) {
  //     _log.debug('verifyIntegration: Integration verification unsuccessful');
  //     state = IntegrationSetupState(
  //       status: IntegrationSetupStatus.updateNotionIntegration,
  //       integration: integration,
  //       error: null,
  //       errorRetryStatus: null,
  //     );
  //     return;
  //   }

  //   _log.debug('verifyIntegration: Integration verified');
  //   state = IntegrationSetupState(
  //     status: IntegrationSetupStatus.connectingToWorkspace,
  //     integration: integration,
  //     error: null,
  //     errorRetryStatus: null,
  //   );
  // }

  Future<void> runNotionAuthCodeFlow() async {
    final authUrlResponse =
        await ref.read(notionAuthServiceProvider.notifier).getAuthUrl();
    switch (authUrlResponse) {
      case BasicResponseSuccess():
        break;
      case BasicResponseError(error: final error):
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

  // Future<void> connectToWorkspace() async {
  //   if (state.integration == null) {
  //     _log.error('connectToWorkspace: No integration found');
  //     state = const IntegrationSetupState(
  //       status: IntegrationSetupStatus.connectingToWorkspaceError,
  //       integration: null,
  //       error: 'No integration found',
  //       errorRetryStatus: IntegrationSetupStatus.loadingIntegration,
  //     );
  //     return;
  //   }

  //   final integrationId = state.integration!.id;
  //   final workspace = await ref.read(activeWorkspaceProvider.future);
  //   if (workspace == null) {
  //     _log.error('connectToWorkspace: No workspace found');
  //     state = IntegrationSetupState(
  //       status: IntegrationSetupStatus.connectingToWorkspaceError,
  //       integration: state.integration,
  //       error: 'No workspace found',
  //       errorRetryStatus: IntegrationSetupStatus.loadingIntegration,
  //     );
  //     return;
  //   }

  //   if (workspace.integrationId == integrationId) {
  //     _log.debug('connectToWorkspace: Already connected to workspace');
  //     state = IntegrationSetupState(
  //       status: IntegrationSetupStatus.confirmedNotionIntegration,
  //       integration: state.integration,
  //       error: null,
  //       errorRetryStatus: null,
  //     );
  //     return;
  //   }

  //   final response =
  //       await ref.read(workspaceServiceProvider.notifier).setIntegration(
  //             workspaceId: workspace.id,
  //             integrationId: integrationId,
  //           );

  //   switch (response) {
  //     case BasicResponseSuccess():
  //       _log.debug('connectToWorkspace: Integration connected');
  //       state = IntegrationSetupState(
  //         status: IntegrationSetupStatus.confirmedNotionIntegration,
  //         integration: state.integration,
  //         error: null,
  //         errorRetryStatus: null,
  //       );
  //       break;
  //     case BasicResponseError(:final error):
  //       _log.error('connectToWorkspace: Error connecting integration');
  //       state = IntegrationSetupState(
  //         status: IntegrationSetupStatus.connectingToWorkspaceError,
  //         integration: state.integration,
  //         error: error,
  //         errorRetryStatus: IntegrationSetupStatus.loadingIntegration,
  //       );
  //       break;
  //   }
  // }
}
