import 'package:flutter/material.dart';

import 'home_entry_screen.dart';

class AppRouter {
  const AppRouter._();

  static const String home = '/';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute<void>(
          builder: (_) => const HomeEntryScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const HomeEntryScreen(),
          settings: const RouteSettings(name: home),
        );
    }
  }
}
