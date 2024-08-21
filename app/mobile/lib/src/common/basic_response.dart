import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'basic_response.freezed.dart';

@freezed
sealed class BasicResponse<T> with _$BasicResponse<T> {
  const factory BasicResponse.success({required T result}) =
      BasicResponseSuccess<T>;
  const factory BasicResponse.error({
    required String? error,
    required String? errorCode,
  }) = BasicResponseError;
}

class ResponseWrapper<T> {
  Future<BasicResponse<T>> wrapResponse(Future<T> Function() function) async {
    final completer = Completer<BasicResponse<T>>();
    unawaited(function().then((result) {
      completer.complete(
        BasicResponse.success(result: result),
      );
    }).catchError((error) {
      completer.complete(
        BasicResponse.error(error: error.toString(), errorCode: null),
      );
    }));
    return completer.future;
  }
}
