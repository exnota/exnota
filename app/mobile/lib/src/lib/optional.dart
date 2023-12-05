import 'package:flutter/material.dart';

@immutable
class Optional<T> {
  final T? value;
  const Optional(this.value);
  factory Optional.empty() => const Optional(null);
}
