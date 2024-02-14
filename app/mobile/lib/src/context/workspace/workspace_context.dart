import 'package:flutter/widgets.dart';

class WorkspaceContext extends StatelessWidget {
  final Widget child;

  const WorkspaceContext({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Soon this will load the relevant workspaces that will be used to things
    // like:
    // - Determine which blocks will be fetched.
    // - Determines which destinations will be available for sending new blocks
    //   to.
    //
    // It will depend on userContextProvider. When there is no user, there will
    // be no workspace.
    //
    // When a user logs in workspaceProvider (or some importer) fetch workspaces
    // from the backend (even if there are some locally, they might be
    // outdated).
    //
    // Once loaded, they are pulled from the local database and made available
    // via workspaceProvider, synchronously.
    //
    // In the future, the user may be able to choose which workspace they are
    // working from. This will be done by setting a local_active_workspace
    // entry in the database. This will be used to determine which workspace to
    // pull entries from.
    return child;
  }
}
