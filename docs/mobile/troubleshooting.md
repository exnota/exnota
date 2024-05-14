# Troubleshooting

- [Common issues](#common-issues)
- [`Error: Method not found` in Freezed file](#error-method-not-found-in-freezed-file)
- [Symptom: Bottom sheet/modal/dialog variables not updating](#symptom-bottom-sheetmodaldialog-variables-not-updating)
  - [Symptom: Platform-specific changes not working](#symptom-platform-specific-changes-not-working)
  - [Symptom: Code involving DB not working; Debugger stepthrough breaks; Behavior inconsistent](#symptom-code-involving-db-not-working-debugger-stepthrough-breaks-behavior-inconsistent)

## Common issues

## `Error: Method not found` in Freezed file

May need to add `part '<filename>.g.dart';`, e.g. due to generating JSON-related code.

## Symptom: Bottom sheet/modal/dialog variables not updating

I think the problem is related to modals/dialogs not being actual children of the widgets in which they are called. References to variables in the parent widget will not be updated.

I have encountered this with variables from providers.

Solution 1: Extract widget inside `builder` into separate consumer widget.

Solution 2: Wrap in Consumer/ProviderScope (not sure what is best).

References:

- [Riverpod issue](https://github.com/rrousselGit/riverpod/issues/2338#issuecomment-1500941508)
- [Riverpod docs](https://riverpod.dev/docs/concepts/scopes#showing-dialogs)

Other: If updating state, you may need a `StatefulBuilder` as per this [SO answer](https://stackoverflow.com/a/56972160).

### Symptom: Platform-specific changes not working

Solution 1: Run `flutter clean`.

### Symptom: Code involving DB not working; Debugger stepthrough breaks; Behavior inconsistent

Solution 1: Ensure all DB/repo methods are awaited, including transactions.

```dart
// ❌ No await will cause problems, even if the caller awaits.
return query.getSingleOrNull();

// ❌ No await will cause problems, even if the caller awaits.
db.transaction(() async { /* */ })


// ✅ Use await.
return await query.getSingleOrNull();

// ✅ Use await.
await db.transaction(() async { /* */ })
```

Solution 2: Separate query creation from execution.

```dart
  // ❌ This seems valid but is often problematic
  await (db.update(db.userAuthTable)
          ..where((tbl) => tbl.id.isNotIn([userAuth.id])))
        .write(const UserAuthTableCompanion(active: Value(false)));

  // ✅ This avoids the problem
  final query = db.update(db.userAuthTable)
          ..where((tbl) => tbl.id.isNotIn([userAuth.id]));
  await query.write(const UserAuthTableCompanion(active: Value(false)));
```
