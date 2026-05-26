import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Helpers for local-first reload/mutation: keep last good data when refresh fails.
class AsyncNotifierReload {
  const AsyncNotifierReload._();

  static AsyncValue<T> loadingPreserving<T>(AsyncValue<T> current) {
    final previous = current.valueOrNull;
    if (previous == null) {
      return const AsyncValue.loading();
    }
    return AsyncValue<T>.loading().copyWithPrevious(AsyncData(previous));
  }

  static AsyncValue<T> errorPreserving<T>(
    Object error,
    StackTrace stackTrace,
    AsyncValue<T> current,
  ) {
    final previous = current.valueOrNull;
    if (previous == null) {
      return AsyncValue.error(error, stackTrace);
    }
    return AsyncValue<T>.error(error, stackTrace)
        .copyWithPrevious(AsyncData(previous));
  }
}
