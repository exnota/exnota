import 'package:flutter/foundation.dart';

@immutable
sealed class EntityId {
  int get idOrThrow {
    if (this is EntityWithId) {
      return (this as EntityWithId).id;
    } else {
      throw Exception("Entity doesn't have an id");
    }
  }
}

@immutable
class EntityPendingId extends EntityId {
  EntityPendingId();
}

@immutable
class EntityWithId extends EntityId {
  final int id;

  EntityWithId(this.id);
}
