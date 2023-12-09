# Drift

## Transactions

### Nesting

To support transactions across multiple service calls, wrap each in a
transaction.

E.g. wrap `noteMutationService.setCaptured` in a transaction, and
`syncCommandMutationService.create` in a transaction.

Then, if an exception is thrown in either (the parent or the nested), everything
will be rolled back.

To instead continue a parent transaction when a nested transaction fails,
catch the exception in the parent.

> - When a nested transaction completes successfully, the outer transaction sees the changes made by the nested transaction as an atomic write (stream queries created in the outer transaction are updated once).
>
> - When a nested transaction throws an exception, it is reverted (so in that sense, it behaves just like other transactions). The outer transaction can catch this exception, after it will be in the same state before the nested transaction was started. If it does not catch that exception, it will bubble up and revert that transaction as well.

Source: <https://drift.simonbinder.eu/docs/transactions/#nested-transactions>
