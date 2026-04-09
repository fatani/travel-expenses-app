import 'package:flutter/material.dart';

import '../features/trips/presentation/trips_list_screen.dart';

class AppRouter {
  const AppRouter._();

  static const String home = '/';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute<void>(
          builder: (_) => const TripsListScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const TripsListScreen(),
          settings: const RouteSettings(name: home),
        );
    }
  }
}
