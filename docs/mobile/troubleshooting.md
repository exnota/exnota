# Troubleshooting

## Common issues

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
