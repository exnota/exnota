import 'package:cached_network_image/cached_network_image.dart';
import 'package:exnota/src/block/destination.dart';
import 'package:exnota/src/block/repo/drift/destination_importer.dart';
import 'package:exnota/src/block/service/destination_exporter.dart';
import 'package:exnota/src/block/service/destination_lister.dart';
import 'package:exnota/src/block/service/workspace_destination_suggestions.dart';
import 'package:exnota/src/block/workspace.dart';
import 'package:exnota/src/common/basic_response.dart';
import 'package:exnota/src/common/block/workspace_service.dart';
import 'package:exnota/src/common/integration/integration_service.dart';
import 'package:exnota/src/common/integration/notion_destination.dart';
import 'package:exnota/src/context/user/pocketbase.dart';
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
        case DestinationSetupStatus.updatingDatabaseDestination:
          ref
              .read(setupDestinationScreenControllerProvider.notifier)
              .updateDestination();
        case DestinationSetupStatus.loadingUpdatedDestinations:
          ref
              .read(setupDestinationScreenControllerProvider.notifier)
              .loadUpdatedDestinations();
        default:
        // Do nothing
      }
    });

    final destinations = ref.watch(destinationListerProvider).valueOrNull;

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
              DisplayDestinations(destinations: destinations),
            DestinationSetupStatus.checkingCustomDestinationsStatus =>
              const Text('Checking custom destinations status...'),
            DestinationSetupStatus.promptCurrentCustomDestinationAction =>
              DisplayDestinations(destinations: destinations),
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
            DestinationSetupStatus.loadingUpdatedDestinations =>
              const Text('Loading updated destinations...'),
            DestinationSetupStatus.loadingUpdatedDestinationsError =>
              SetupErrorMessage(
                error: setupState.error!,
                errorRetryStatus: setupState.errorRetryStatus,
              ),
            DestinationSetupStatus.destinationsUpdated =>
              DisplayDestinations(destinations: destinations),
          },
        ),
      ),
    );
  }
}

class DisplayDestinations extends ConsumerWidget {
  const DisplayDestinations({
    super.key,
    required this.destinations,
  });

  final List<Destination>? destinations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = destinations;
    if (d == null) {
      return const Text('No destinations found');
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Destinations'),
        if (destinations != null) ...[
          for (final destination in d)
            ListTile(
              title: Text(destination.name ?? ''),
              subtitle: Text(destination.id),
            ),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                ref
                    .read(setupDestinationScreenControllerProvider.notifier)
                    .transitionStatus(
                        newStatus: DestinationSetupStatus
                            .loadingSuggestedDestinations);
              },
              child: const Text('Change'),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ],
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

class SelectDestination extends ConsumerStatefulWidget {
  const SelectDestination({super.key});

  @override
  ConsumerState<SelectDestination> createState() => _SelectDestinationState();
}

class _SelectDestinationState extends ConsumerState<SelectDestination> {
  final _log = Logger(context: '_SelectDestinationState');

  @override
  Widget build(BuildContext context) {
    final destination = ref.watch(activeDestinationLazyProvider);
    final selected = ref.watch(_selectedDestinationProvider);
    final suggestions = ref
            .watch(setupDestinationScreenControllerProvider)
            .notionSuggestedDestinations ??
        [];
    final searchResults = ref.watch(_searchResultsProvider);
    if (searchResults is AsyncData) {
      _log.debug('build: num results: ${searchResults.value?.length}');
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (destination != null) ...[
          const Text('Current destination'),
          ListTile(
            title: Text(destination.name ?? ''),
            subtitle: Text(destination.id),
          ),
          const SizedBox(height: 16),
        ],
        const Text('Suggested'),
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
        const SizedBox(height: 16),
        if (selected != null && !suggestions.contains(selected)) ...[
          const Text('Selected'),
          DestinationRadioTile(
            destination: selected,
            selected: selected,
            onChanged: (value) {
              ref
                  .read(setupDestinationScreenControllerProvider.notifier)
                  .setSelectedDestination(value);
            },
          ),
          const SizedBox(height: 16),
        ],
        const Text('Search'),
        SearchAnchor(
          viewOnChanged: (query) {
            _log.debug('SearchAnchor: viewOnChanged search query: $query');
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
                final selected = ref.watch(_selectedDestinationProvider);
                final results = ref.watch(_searchResultsProvider);
                _log.debug(
                    'SearchAnchor: rebuilding viewBuilder with selected: $selected');

                return switch (results) {
                  AsyncData(:final value) => Column(
                      children: [
                        for (final destination in value)
                          DestinationRadioTile(
                            destination: destination,
                            selected: selected,
                            onChanged: (value) {
                              ref
                                  .read(setupDestinationScreenControllerProvider
                                      .notifier)
                                  .setSelectedDestination(value);
                            },
                          )
                      ],
                    ),
                  AsyncLoading() => const Text('Loading...'),
                  AsyncError(:final error) => Text('Error: $error'),
                  AsyncValue() => const Text('No results'),
                };
              },
            );
          },
          builder: (context, controller) {
            return SearchBar(
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
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: selected == null
                  ? null
                  : () {
                      ref
                          .read(
                              setupDestinationScreenControllerProvider.notifier)
                          .transitionStatus(
                              newStatus: DestinationSetupStatus
                                  .updatingDatabaseDestination);
                    },
              child: const Text('Select destination'),
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
          Text(destination.name),
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
  loadingDestinations, // Updates destinations in local database, after sync
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
  loadingUpdatedDestinations, // Updates destinations in local database, after changes
  loadingUpdatedDestinationsError,
  destinationsUpdated, // Destinations updated
}

@Freezed(copyWith: false)
class DestinationSetupState with _$DestinationSetupState {
  const factory DestinationSetupState({
    required DestinationSetupStatus status,
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
    _log.debug('build: Initializing state with status verifyingDestinations');
    return const DestinationSetupState(
      status: DestinationSetupStatus.syncingExternalDestinations,
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
      notionSuggestedDestinations: state.notionSuggestedDestinations,
      selected: state.selected,
      error: null,
      errorRetryStatus: null,
    );
  }

  void setSelectedDestination(NotionDestination? destination) {
    state = DestinationSetupState(
      status: state.status,
      notionSuggestedDestinations: state.notionSuggestedDestinations,
      selected: destination,
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
        selected: null,
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
          selected: null,
          error: null,
          errorRetryStatus: null,
        );
        break;
      case BasicResponseError(:final error):
        _log.error('syncExistingDestinations: Error');
        state = DestinationSetupState(
          status: DestinationSetupStatus.syncingExternalDestinationsError,
          notionSuggestedDestinations: null,
          selected: null,
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
            selected: null,
            error: null,
            errorRetryStatus: null,
          );
        } else {
          state = const DestinationSetupState(
            status: DestinationSetupStatus.checkingCustomDestinationsStatus,
            notionSuggestedDestinations: null,
            selected: null,
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
          selected: null,
          error: error,
          errorRetryStatus: DestinationSetupStatus.loadingDestinations,
        );
        return;
    }
  }

  Future<void> loadUpdatedDestinations() async {
    final workspace = (await ref.read(activeWorkspaceProvider.future))!;

    final result =
        await ref.read(destinationImporterProvider.notifier).importForWorkspace(
              workspaceId: workspace.id,
            );
    switch (result) {
      case BasicResponseSuccess():
        _log.debug('loadUpdatedDestinations: Success');
        state = const DestinationSetupState(
          status: DestinationSetupStatus.destinationsUpdated,
          notionSuggestedDestinations: null,
          selected: null,
          error: null,
          errorRetryStatus: null,
        );
        return;
      case BasicResponseError(:final error):
        _log.error('loadUpdatedDestinations: Error');
        state = DestinationSetupState(
          status: DestinationSetupStatus.loadingUpdatedDestinationsError,
          notionSuggestedDestinations: null,
          selected: null,
          error: error,
          errorRetryStatus: DestinationSetupStatus.loadingUpdatedDestinations,
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
        selected: null,
        error: null,
        errorRetryStatus: null,
      );
      return;
    }

    state = const DestinationSetupState(
      status: DestinationSetupStatus.promptCurrentDatabaseDestinationAction,
      notionSuggestedDestinations: null,
      selected: null,
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
        selected: null,
        error: null,
        errorRetryStatus: null,
      );
      return;
    }

    state = const DestinationSetupState(
      status: DestinationSetupStatus.promptCurrentCustomDestinationAction,
      notionSuggestedDestinations: null,
      selected: null,
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
          notionSuggestedDestinations: result.destinations.notion,
          selected: null,
          error: null,
          errorRetryStatus: null,
        );
        return;
      case BasicResponseError(:final error):
        _log.error('loadSuggestedDestinations: Error');
        state = DestinationSetupState(
          status: DestinationSetupStatus.loadingSuggestedDestinationsError,
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

    final workspace = (await ref.read(activeWorkspaceProvider.future))!;

    final result =
        await ref.read(destinationExporterProvider.notifier).replaceDestination(
              workspaceId: workspace.id,
              notionObject: selected.object,
            );

    switch (result) {
      case BasicResponseSuccess():
        _log.debug('updateDestination: Success');
        state = DestinationSetupState(
          status: DestinationSetupStatus.loadingUpdatedDestinations,
          notionSuggestedDestinations: null,
          selected: state.selected,
          error: null,
          errorRetryStatus: null,
        );
        return;
      case BasicResponseError(:final error):
        _log.error('updateDestination: Error');
        state = DestinationSetupState(
          status: DestinationSetupStatus.updatingDatabaseDestinationError,
          notionSuggestedDestinations: null,
          selected: state.selected,
          error: error,
          errorRetryStatus: DestinationSetupStatus.updatingDatabaseDestination,
        );
        return;
    }
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
Future<List<NotionDestination>> _searchResults(_SearchResultsRef ref) async {
  final query = ref.watch(_searchQueryProvider);
  final pb = ref.watch(pocketBaseSyncProvider);
  final workspace = await ref.watch(activeWorkspaceProvider.future);
  final workspaceId = workspace?.id;
  if (workspaceId == null) {
    return [];
  }

  final rawResult = await pb.send(
    '/api/exnota/workspace/search-destinations',
    method: 'GET',
    body: {
      'query': query,
      'workspace_id': workspaceId,
    },
  );

  final result = GetSuggestedDestinationsResponse.fromJson(rawResult);
  return result.destinations.notion ?? [];
}

@freezed
class SearchWorkspaceDestinations with _$SearchWorkspaceDestinations {
  const factory SearchWorkspaceDestinations({
    // ignore: invalid_annotation_target
    @JsonKey(name: 'destinations') required Destinations destinations,
  }) = _SearchWorkspaceDestinations;

  const SearchWorkspaceDestinations._();

  factory SearchWorkspaceDestinations.fromJson(Map<String, dynamic> json) =>
      _$SearchWorkspaceDestinationsFromJson(json);
}
