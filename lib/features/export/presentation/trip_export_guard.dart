/// Prevents overlapping exports for the same trip and format.
class TripExportGuard {
  TripExportGuard._();

  static final Set<String> _inFlightKeys = <String>{};

  static bool tryAcquire({required String tripId, required String formatKey}) {
    final key = '$tripId|$formatKey';
    if (_inFlightKeys.contains(key)) {
      return false;
    }
    _inFlightKeys.add(key);
    return true;
  }

  static void release({required String tripId, required String formatKey}) {
    _inFlightKeys.remove('$tripId|$formatKey');
  }
}
