import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:exnota/src/block/repo/drift/destination_importer.dart';
import 'package:exnota/src/block/repo/drift/workspace_exporter.dart';
import 'package:exnota/src/block/repo/drift/workspace_importer.dart';
import 'package:exnota/src/block/service/block_lister.dart';
import 'package:exnota/src/block/service/destination_exporter.dart';
import 'package:exnota/src/block/service/destination_lister.dart';
import 'package:exnota/src/block/service/workspace_destination_suggestions.dart';
import 'package:exnota/src/block/service/workspace_lister.dart';
import 'package:exnota/src/block/workspace.dart';
import 'package:exnota/src/common/basic_response.dart';
import 'package:exnota/src/common/integration/error_codes.dart';
import 'package:exnota/src/common/integration/notion_destination.dart';
import 'package:exnota/src/context/app/router.dart';
import 'package:exnota/src/context/user/pocketbase.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/integration/screen/base_setup_screen.dart';
import 'package:exnota/src/integration/screen/setup_error_message.dart';
import 'package:exnota/src/lib/data/sync/service/sync_command_mutator.dart';
import 'package:exnota/src/lib/data/sync/set_block_destination_sync_command.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'setup_destination_screen.freezed.dart';
part 'setup_destination_screen.g.dart';

class SetupDestinationScreen extends ConsumerStatefulWidget {
  final String integrationID;

  const SetupDestinationScreen({super.key, required this.integrationID});

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
          .loadDestinations(integrationID: widget.integrationID);
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
              .loadDestinations(integrationID: widget.integrationID);
          break;
        case DestinationSetupStatus.loadingSuggestedDestinations:
          ref
              .read(setupDestinationScreenControllerProvider.notifier)
              .loadSuggestedDestinations();
          break;
        case DestinationSetupStatus.updatingDestination:
          ref
              .read(setupDestinationScreenControllerProvider.notifier)
              .updateDestination();
          break;
        case DestinationSetupStatus.updatingBlocks:
          ref
              .read(setupDestinationScreenControllerProvider.notifier)
              .checkBlocksWithoutDestination();
          break;
        default:
        // Do nothing
      }
    });

    return BaseWidgetScaffold(
      child: switch (setupState.status) {
        DestinationSetupStatus.loadingDestinationsError => SetupErrorMessage(
            error: setupState.error!,
            errorRetryStatus: setupState.errorRetryStatus,
            onRetry: () {
              ref
                  .read(setupDestinationScreenControllerProvider.notifier)
                  .transitionStatus(newStatus: setupState.errorRetryStatus!);
            },
          ),
        DestinationSetupStatus.loadingSuggestedDestinationsError =>
          SetupErrorMessage(
            error: setupState.error!,
            errorRetryStatus: setupState.errorRetryStatus,
            onRetry: () {
              ref
                  .read(setupDestinationScreenControllerProvider.notifier)
                  .transitionStatus(newStatus: setupState.errorRetryStatus!);
            },
          ),
        DestinationSetupStatus.selectSuggestedDestination =>
          SelectSuggestedDestination(integrationID: widget.integrationID),
        DestinationSetupStatus.searchDestinations =>
          SearchDestination(integrationID: widget.integrationID),
        DestinationSetupStatus.updatingDestinationError => SetupErrorMessage(
            error: setupState.error!,
            errorRetryStatus: setupState.errorRetryStatus,
            onRetry: () {
              ref
                  .read(setupDestinationScreenControllerProvider.notifier)
                  .transitionStatus(newStatus: setupState.errorRetryStatus!);
            },
          ),
        DestinationSetupStatus.loadingUpdatedDestinationsError =>
          SetupErrorMessage(
            error: setupState.error!,
            errorRetryStatus: setupState.errorRetryStatus,
            onRetry: () {
              ref
                  .read(setupDestinationScreenControllerProvider.notifier)
                  .transitionStatus(newStatus: setupState.errorRetryStatus!);
            },
          ),
        DestinationSetupStatus.reauthRequired => const ReauthRequired(),
        DestinationSetupStatus.completed => const Completed(),
        // Loading
        DestinationSetupStatus.loadingDestinations ||
        DestinationSetupStatus.loadingSuggestedDestinations ||
        DestinationSetupStatus.updatingDestination ||
        DestinationSetupStatus.updatingBlocks =>
          const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class Completed extends ConsumerWidget {
  const Completed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinationAsync = ref.watch(activeDestinationProvider);

    switch (destinationAsync) {
      case AsyncLoading():
        return const Center(child: CircularProgressIndicator());
      case AsyncError(:final error):
        return SetupErrorMessage(
          error: error.toString(),
          errorRetryStatus: null,
          onRetry: () {},
        );
      case AsyncData(:final value):
        return BaseSetupView(
          header: 'You\'re connected!',
          contentChildren: [
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Notes will be saved to: '),
                  TextSpan(
                    text: value!.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
          buttonChildren: [
            FilledButton(
              onPressed: () {
                ref.read(routerProvider.notifier).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      default:
        return Container();
    }
  }
}

class ReauthRequired extends ConsumerWidget {
  const ReauthRequired({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BaseSetupView(
      header: 'Reconnection required',
      contentChildren: const [
        Text('Notion is asking you to reconnect Exnota.')
      ],
      buttonChildren: [
        FilledButton(
          onPressed: () {
            ref
                .read(routerProvider.notifier)
                .pushReplacement(Screen.settingsSetupIntegrationForceReauth);
          },
          child: const Text('Reconnect'),
        ),
      ],
    );
  }
}

const NotionDestination noneOfTheAbove = NotionDestination(
    name: 'None of the above',
    object:
        NotionObject(object: NotionObjectType.page, id: 'none-of-the-above'),
    icon: null);

class SelectSuggestedDestination extends ConsumerStatefulWidget {
  final String integrationID;

  const SelectSuggestedDestination({super.key, required this.integrationID});

  @override
  ConsumerState<SelectSuggestedDestination> createState() =>
      _SelectSuggestedDestinationState();
}

class _SelectSuggestedDestinationState
    extends ConsumerState<SelectSuggestedDestination> {
  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(_selectedDestinationProvider);
    final selectedNoneOfTheAbove = selected == noneOfTheAbove;
    final suggestions = ref
            .watch(setupDestinationScreenControllerProvider)
            .notionSuggestedDestinations ??
        [];

    return BaseSetupView(
      header: 'Last, confirm where notes should be sent.',
      contentChildren: [
        const Text(
            'Looks like Exnota has access to a few pages. Some might be inside the one you gave access to.'),
        const SizedBox(height: 16),
        const Text('Please confirm where notes should be sent:'),
        const SizedBox(height: 16),
        for (final destination in suggestions)
          DestinationRadioTile(
            destination: destination,
            selected: selected,
            onChanged: (value) {
              ref
                  .read(setupDestinationScreenControllerProvider.notifier)
                  .setSelectedDestination(value);
            },
          ),
        RadioListTile(
          title: Row(
            children: [
              Text(noneOfTheAbove.name),
            ],
          ),
          value: noneOfTheAbove,
          groupValue: selected,
          onChanged: (value) {
            ref
                .read(setupDestinationScreenControllerProvider.notifier)
                .setSelectedDestination(value);
          },
        ),
      ],
      buttonChildren: [
        if (selectedNoneOfTheAbove) ...[
          FilledButton(
            onPressed: () {
              ref
                  .read(setupDestinationScreenControllerProvider.notifier)
                  .transitionStatus(
                      newStatus: DestinationSetupStatus.searchDestinations);
            },
            child: const Text('Next'),
          ),
        ] else ...[
          FilledButton(
            onPressed: selected == null
                ? null
                : () {
                    ref
                        .read(setupDestinationScreenControllerProvider.notifier)
                        .transitionStatus(
                            newStatus:
                                DestinationSetupStatus.updatingDestination);
                  },
            child: const Text('Confirm'),
          ),
        ]
      ],
    );
  }
}

class Debouncer {
  final int milliseconds;
  VoidCallback? action;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    if (_timer != null) {
      _timer!.cancel();
    }
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}

final searchDebouncer = Debouncer(milliseconds: 800);

class SearchDestination extends ConsumerStatefulWidget {
  final String integrationID;

  const SearchDestination({super.key, required this.integrationID});

  @override
  ConsumerState<SearchDestination> createState() => _SearchDestinationState();
}

class _SearchDestinationState extends ConsumerState<SearchDestination> {
  final _log = Logger(context: '_SelectDestinationState');
  final SearchController controller = SearchController();

  @override
  Widget build(BuildContext context) {
    final searchResults =
        ref.watch(_searchResultsProvider(widget.integrationID));
    if (searchResults is AsyncData) {
      _log.debug('build: num results: ${searchResults.value?.length}');
    }

    return BaseSetupView(
      header: 'Where should notes be sent?',
      contentChildren: [
        const Text(
            'Search for the database or page in Notion you want Exnota to send notes to:'),
        const SizedBox(height: 32),
        SearchAnchor(
          searchController: controller,
          viewOnChanged: (query) {
            _log.debug('SearchAnchor: viewOnChanged search query: $query');
            searchDebouncer.run(() {
              _log.debug('SearchAnchor: debounced search query: $query');
              ref.read(_searchQueryProvider.notifier).setQuery(query);
            });
          },
          viewOnSubmitted: (query) {
            _log.debug('SearchAnchor: viewOnSubmitted search query: $query');
            ref.read(_searchQueryProvider.notifier).setQuery(query);
          },
          // Couldn't figure out how to have the suggestionsBuilder re-build
          // when the search results change. So I'm using the provider
          // directly in the viewBuilder instead.
          suggestionsBuilder: (context, controller) => [],

          viewBuilder: (suggestions) {
            // Ignore the suggestions argument and use from the provider
            // instead. Because I can't figure out how to have
            // suggestionsBuilder re-build when the search results change,
            // although I'm sure it mustn't be difficult.
            return Consumer(
              builder: (context, ref, child) {
                final results =
                    ref.watch(_searchResultsProvider(widget.integrationID));
                _log.debug('SearchAnchor: rebuilding viewBuilder');

                return switch (results) {
                  AsyncData(:final value) => value.isEmpty
                      ? const Center(child: Text('No results'))
                      : SingleChildScrollView(
                          child: Column(
                            children: [
                              for (final destination in value)
                                DestinationListTile(
                                  destination: destination,
                                  onChanged: (value) {
                                    ref
                                        .read(
                                            setupDestinationScreenControllerProvider
                                                .notifier)
                                        .setSelectedDestination(value);
                                    ref
                                        .read(
                                            setupDestinationScreenControllerProvider
                                                .notifier)
                                        .transitionStatus(
                                            newStatus: DestinationSetupStatus
                                                .updatingDestination);
                                    if (controller.isAttached) {
                                      controller.closeView('');
                                    }
                                  },
                                )
                            ],
                          ),
                        ),
                  AsyncLoading() =>
                    const Center(child: CircularProgressIndicator()),
                  AsyncError(:final error) => Text('Error: $error'),
                  AsyncValue() => const Text('No results'),
                };
              },
            );
          },
          builder: (context, controller) {
            return SearchBar(
              hintText: 'Search',
              elevation: const MaterialStatePropertyAll<double>(0),
              backgroundColor: MaterialStateProperty.resolveWith(
                  (states) => Colors.grey[200]),
              controller: controller,
              onTap: () {
                _log.debug('SearchAnchor: onTap search bar');
                controller.openView();
              },
              onSubmitted: (query) {
                _log.debug('SearchAnchor: onSubmitted search query: $query');
                controller.openView();
              },
              onChanged: (query) {
                _log.debug('SearchAnchor: onChanged search query: $query');
                ref.read(_searchQueryProvider.notifier).setQuery(query);
                controller.openView();
              },
            );
          },
        ),
      ],
      buttonChildren: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Let\'s try again'),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                                'We\'ll repeat the steps that give Exnota access to your Notion.'),
                            const SizedBox(height: 16),
                            const Text(
                                'Ensure your notes database or page is checked:'),
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey[400]!,
                                  width: 2.0,
                                ),
                              ),
                              child: const Image(
                                image: AssetImage(
                                    'assets/images/notion-auth-checked.png'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                                'And ensure you scroll down and press \'Allow access\':'),
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey[400]!,
                                  width: 2.0,
                                ),
                              ),
                              child: const Image(
                                image: AssetImage(
                                    'assets/images/notion-auth-allow-access.png'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          child: const Text('Try again'),
                          onPressed: () {
                            ref.read(routerProvider.notifier).pushReplacement(
                                Screen.settingsSetupIntegrationForceReauth);
                          },
                        ),
                      ],
                    );
                  },
                );
              },
              child: const Text("I can't find it"),
            ),
          ],
        ),
      ],
    );
  }
}

class DestinationRadioTile extends StatelessWidget {
  final NotionDestination destination;
  final NotionDestination? selected;
  final void Function(NotionDestination?) onChanged;

  const DestinationRadioTile({
    super.key,
    required this.destination,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile(
      title: Row(
        children: [
          DestinationIcon(destination: destination),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              destination.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      value: destination,
      groupValue: selected,
      onChanged: (value) {
        onChanged(value);
      },
    );
  }
}

class DestinationListTile extends StatelessWidget {
  final NotionDestination destination;
  final void Function(NotionDestination?) onChanged;

  const DestinationListTile({
    super.key,
    required this.destination,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Row(
        children: [
          DestinationIcon(destination: destination),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              destination.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      onTap: () {
        onChanged(destination);
      },
    );
  }
}

class DestinationIcon extends StatelessWidget {
  final NotionDestination destination;

  const DestinationIcon({super.key, required this.destination});

  @override
  Widget build(BuildContext context) {
    final Icon placeholder;
    switch (destination.object.object) {
      case NotionObjectType.page:
        placeholder = const Icon(Icons.article);
        break;
      case NotionObjectType.database:
        placeholder = const Icon(Icons.table_chart_rounded);
        break;
    }

    if (destination.name == noneOfTheAbove.name) {
      return const SizedBox(width: 0, height: 0);
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

// 1h load destinations from backend and import
// if exists, go to screen 2
// 1h fetch suggested destinations
// 2h user searches destinations
// 1h create destination + workspace (in transaction in backend?!)
// import both locally
// go to screen 2

enum DestinationSetupStatus {
  loadingDestinations, // Updates destinations in local database, after sync
  loadingDestinationsError,
  loadingSuggestedDestinations,
  loadingSuggestedDestinationsError,
  selectSuggestedDestination,
  searchDestinations,
  updatingDestination, // Processes database destination changes
  updatingDestinationError,
  loadingUpdatedDestinationsError,
  reauthRequired,
  updatingBlocks,
  completed,
}

@Freezed(copyWith: false)
class DestinationSetupState with _$DestinationSetupState {
  const factory DestinationSetupState({
    required DestinationSetupStatus status,
    // Integration ID is initially null until the widget can populate it.
    required String? integrationID,
    required List<NotionDestination>? notionSuggestedDestinations,
    required NotionDestination? selected,
    required String? error,
    required DestinationSetupStatus? errorRetryStatus,
  }) = _DestinationSetupState;
}

@riverpod
NotionDestination? _selectedDestination(_SelectedDestinationRef ref) {
  return ref.watch(setupDestinationScreenControllerProvider).selected;
}

@riverpod
class SetupDestinationScreenController
    extends _$SetupDestinationScreenController {
  final _log = Logger(context: 'SetupDestinationScreenController');

  @override
  DestinationSetupState build() {
    _log.debug('build: Initializing state with status loadingDestinations');
    return const DestinationSetupState(
      status: DestinationSetupStatus.loadingDestinations,
      integrationID: null,
      notionSuggestedDestinations: null,
      selected: null,
      error: null,
      errorRetryStatus: null,
    );
  }

  // Transition to a new state status
  void transitionStatus({required DestinationSetupStatus newStatus}) {
    state = DestinationSetupState(
      status: newStatus,
      integrationID: state.integrationID,
      notionSuggestedDestinations: state.notionSuggestedDestinations,
      selected: state.selected,
      error: null,
      errorRetryStatus: null,
    );
  }

  void setSelectedDestination(NotionDestination? destination) {
    state = DestinationSetupState(
      status: state.status,
      integrationID: state.integrationID,
      notionSuggestedDestinations: state.notionSuggestedDestinations,
      selected: destination,
      error: null,
      errorRetryStatus: null,
    );
  }

  Future<void> loadDestinations({required String integrationID}) async {
    // Import latest workspaces
    final workspaceImportResult =
        await ref.read(workspaceImporterProvider.notifier).import();
    switch (workspaceImportResult) {
      case BasicResponseSuccess():
        _log.debug('loadDestinations: Workspace import success');
        break;
      case BasicResponseError(:final error):
        _log.error('loadDestinations: Workspace import error');
        state = DestinationSetupState(
          status: DestinationSetupStatus.loadingDestinationsError,
          integrationID: integrationID,
          notionSuggestedDestinations: null,
          selected: null,
          error: error,
          errorRetryStatus: DestinationSetupStatus.loadingDestinations,
        );
        return;
    }

    final workspace = (await ref.read(activeWorkspaceProvider.future));

    // If no workspace, load suggested destinations. The selected destination
    // type will be used to create the workspace type, even though the workspace
    // must be created before the destination.
    if (workspace == null) {
      _log.debug('loadDestinations: No workspace found');
      state = DestinationSetupState(
        status: DestinationSetupStatus.loadingSuggestedDestinations,
        integrationID: integrationID,
        notionSuggestedDestinations: null,
        selected: null,
        error: null,
        errorRetryStatus: null,
      );
      return;
    }
    _log.debug('loadDestinations: Workspace found');

    // Import latest destinations
    final destinationImportResult =
        await ref.read(destinationImporterProvider.notifier).importForWorkspace(
              workspaceId: workspace.id,
            );
    switch (destinationImportResult) {
      case BasicResponseSuccess():
        _log.debug('loadDestinations: Destination import success');
        final activeDestination =
            await ref.read(activeDestinationProvider.future);

        if (activeDestination == null) {
          _log.debug('loadDestinations: No destination found');
          state = DestinationSetupState(
            status: DestinationSetupStatus.loadingSuggestedDestinations,
            integrationID: integrationID,
            notionSuggestedDestinations: null,
            selected: null,
            error: null,
            errorRetryStatus: null,
          );
          return;
        }

        _log.debug('loadDestinations: Destination found');
        state = DestinationSetupState(
          status: DestinationSetupStatus.updatingBlocks,
          integrationID: integrationID,
          notionSuggestedDestinations: null,
          selected: null,
          error: null,
          errorRetryStatus: null,
        );
        return;
      case BasicResponseError(:final error):
        _log.error('loadDestinations: Destination import error');
        state = DestinationSetupState(
          status: DestinationSetupStatus.loadingDestinationsError,
          integrationID: integrationID,
          notionSuggestedDestinations: null,
          selected: null,
          error: error,
          errorRetryStatus: DestinationSetupStatus.loadingDestinations,
        );
        return;
    }
  }

  Future<void> loadSuggestedDestinations() async {
    final suggestionResponse = await ref
        .read(workspaceDestinationSuggestionsProvider.notifier)
        .get(integrationID: state.integrationID!);
    switch (suggestionResponse) {
      case BasicResponseSuccess(:final result):
        _log.debug('loadSuggestedDestinations: Success');

        state = DestinationSetupState(
          status: DestinationSetupStatus.selectSuggestedDestination,
          integrationID: state.integrationID,
          notionSuggestedDestinations: result.destinations.notion,
          selected: result.destinations.notion?.first,
          error: null,
          errorRetryStatus: null,
        );
        return;
      case BasicResponseError(:final error, :final errorCode):
        _log.error('loadSuggestedDestinations: Error. Code: $errorCode');
        if (errorCode == invalidToken) {
          _log.error('loadSuggestedDestinations: Reauth required');
          state = DestinationSetupState(
            status: DestinationSetupStatus.reauthRequired,
            integrationID: state.integrationID,
            notionSuggestedDestinations: null,
            selected: null,
            error: error,
            errorRetryStatus: null,
          );
          return;
        }
        state = DestinationSetupState(
          status: DestinationSetupStatus.loadingSuggestedDestinationsError,
          integrationID: state.integrationID,
          notionSuggestedDestinations: null,
          selected: null,
          error: error,
          errorRetryStatus: DestinationSetupStatus.loadingSuggestedDestinations,
        );
        return;
    }
  }

  Future<void> updateDestination() async {
    final selected = state.selected;
    if (selected == null) {
      _log.error('updateDestination: No destination selected');
      return;
    }

    // Import latest workspace
    final importResult =
        await ref.read(workspaceImporterProvider.notifier).import();
    switch (importResult) {
      case BasicResponseSuccess():
        _log.debug('updateDestination: Workspace import success');
        break;
      case BasicResponseError(:final error):
        _log.error('updateDestination: Workspace import error');
        state = DestinationSetupState(
          status: DestinationSetupStatus.updatingDestinationError,
          integrationID: state.integrationID,
          notionSuggestedDestinations: null,
          selected: state.selected,
          error: error,
          errorRetryStatus: DestinationSetupStatus.updatingDestination,
        );
        return;
    }

    // If no workspace, create.
    var workspace = await ref.read(activeWorkspaceProvider.future);
    if (workspace == null) {
      final WorkspaceType type;
      switch (selected.object.object) {
        case NotionObjectType.page:
          type = WorkspaceType.custom;
          break;
        case NotionObjectType.database:
          type = WorkspaceType.database;
          break;
        default:
          _log.error('updateDestination: Unknown object type');
          return;
      }
      final result = await ref
          .read(workspaceExporterProvider.notifier)
          .create(type: type, integrationId: state.integrationID!);
      switch (result) {
        case BasicResponseSuccess(:final result):
          _log.debug('updateDestination: Workspace created');
          workspace = result;
          break;
        case BasicResponseError(:final error):
          _log.error('updateDestination: Workspace creation error');
          state = DestinationSetupState(
            status: DestinationSetupStatus.updatingDestinationError,
            integrationID: state.integrationID,
            notionSuggestedDestinations: null,
            selected: state.selected,
            error: error,
            errorRetryStatus: DestinationSetupStatus.updatingDestination,
          );
          return;
      }
    }

    // Archive any existing destinations and create a new one
    final result =
        await ref.read(destinationExporterProvider.notifier).replaceDestination(
              workspaceId: workspace.id,
              notionObject: selected.object,
            );

    switch (result) {
      case BasicResponseSuccess():
        _log.debug('updateDestination: Success');
        state = DestinationSetupState(
          status: DestinationSetupStatus.updatingBlocks,
          integrationID: state.integrationID,
          notionSuggestedDestinations: null,
          selected: state.selected,
          error: null,
          errorRetryStatus: null,
        );
        return;
      case BasicResponseError(:final error):
        _log.error('updateDestination: Error');
        state = DestinationSetupState(
          status: DestinationSetupStatus.updatingDestinationError,
          integrationID: state.integrationID,
          notionSuggestedDestinations: null,
          selected: state.selected,
          error: error,
          errorRetryStatus: DestinationSetupStatus.updatingDestination,
        );
        return;
    }
  }

  Future<void> checkBlocksWithoutDestination() async {
    final blocks = await ref.read(blocksWithoutDestinationProvider.future);

    _log.debug('checkBlocksWithoutDestination: Success');
    if (blocks.isEmpty) {
      _log.debug(
          'checkBlocksWithoutDestination: No blocks without destination');
      state = DestinationSetupState(
        status: DestinationSetupStatus.completed,
        integrationID: state.integrationID,
        notionSuggestedDestinations: null,
        selected: null,
        error: null,
        errorRetryStatus: null,
      );
      return;
    }

    final activeDestination = await ref.read(activeDestinationProvider.future);
    if (activeDestination == null) {
      _log.error('checkBlocksWithoutDestination: No active destination');
      state = DestinationSetupState(
        status: DestinationSetupStatus.completed,
        integrationID: state.integrationID,
        notionSuggestedDestinations: null,
        selected: null,
        error: null,
        errorRetryStatus: null,
      );
      return;
    }

    // Add commands for each block
    final commandMutator = SyncCommandMutator(container: ref.container);
    _log.debug('checkBlocksWithoutDestination: Add commands for each block');
    for (final block in blocks) {
      final command = SetBlockDestinationSyncCommand.createWaiting(
        userId: ref.read(activeUserIdOrThrowSyncProvider),
        data: SetBlockDestinationData(
          blockId: block.id,
          destinationId: activeDestination.id,
        ),
      );
      await commandMutator.createCommand(command: command);
    }

    _log.debug('checkBlocksWithoutDestination: Success');
    state = DestinationSetupState(
      status: DestinationSetupStatus.completed,
      integrationID: state.integrationID,
      notionSuggestedDestinations: null,
      selected: null,
      error: null,
      errorRetryStatus: null,
    );
    return;
  }
}

@riverpod
class _SearchQuery extends _$SearchQuery {
  @override
  String build() {
    return '';
  }

  void setQuery(String query) {
    state = query;
  }
}

@riverpod
Future<List<NotionDestination>> _searchResults(
    _SearchResultsRef ref, String integrationId) async {
  final log = Logger(context: '_searchResultsProvider');
  final query = ref.watch(_searchQueryProvider);
  if (query.isEmpty) {
    log.info('searchResults: No query');
    return [];
  }

  final pb = ref.watch(pocketBaseSyncProvider);

  log.info('Sending query: $query');
  final rawResult = await pb.send(
    '/api/exnota/integration/notion/search-destinations',
    method: 'GET',
    body: {
      'query': query,
      'integration_id': integrationId,
    },
  );
  log.info('Got results');

  final result = GetSuggestedDestinationsResponse.fromJson(rawResult);
  return result.destinations.notion ?? [];
}

@freezed
class SearchIntegrationDestinations with _$SearchIntegrationDestinations {
  const factory SearchIntegrationDestinations({
    // ignore: invalid_annotation_target
    @JsonKey(name: 'destinations') required Destinations destinations,
  }) = _SearchIntegrationDestinations;

  const SearchIntegrationDestinations._();

  factory SearchIntegrationDestinations.fromJson(Map<String, dynamic> json) =>
      _$SearchIntegrationDestinationsFromJson(json);
}
