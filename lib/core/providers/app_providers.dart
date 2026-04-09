import 'package:flutter_riverpod/flutter_riverpod.dart';

final appStatusProvider = Provider<String>((ref) {
  return 'Riverpod is connected';
});
