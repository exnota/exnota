# Troubleshooting

## Common issues

* Symptom: Functionality not working; Debugger stepthrough breaks; Behavior inconsistent.
  * Solution: Ensure all DB/repo methods are awaited, including transactions.

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
