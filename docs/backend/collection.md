# Collection

## New collection checklist

### In Admin UI

- Each field
  - Set 'non empty' where appropriate
- If users can access, add authorization in API Rules tab, e.g.
  - `user.id = @request.auth.id`
  - `internalBlock.user.id = @request.auth.id`
  - Otherwise, leave set to 'Admin only'
- Add unique constraints

### In code

- Add relation rules in a `data_rules.go`, e.g.
  - Cannot change type
  - Relation must also belong to user
