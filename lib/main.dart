import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/randomizer_screen.dart';
import 'screens/restaurant_detail_screen.dart';
import 'screens/entry_detail_screen.dart';
import 'screens/add_entry_screen.dart';
import 'screens/new_restaurant_screen.dart';
import 'screens/choice_screen.dart';
import 'screens/main_shell.dart';
import 'data/journibites_repository.dart';
import 'screens/edit_restaurant_screen.dart';
import 'screens/edit_entry_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JourniBitesApp());
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/randomizer',
            builder: (context, state) => const RandomizerScreen(),
          ),
        ]),
      ],
    ),
    GoRoute(
      path: '/choice',
      builder: (context, state) => const ChoiceScreen(),
    ),
    GoRoute(
      path: '/new-restaurant',
      builder: (context, state) => const NewRestaurantScreen(),
    ),
    GoRoute(
      path: '/add-entry',
      builder: (context, state) {
        final restaurantId = state.uri.queryParameters['restaurantId'];
        final restaurantName = state.uri.queryParameters['restaurantName'];
        return AddEntryScreen(
          restaurantId: restaurantId,
          restaurantName: restaurantName != null
              ? Uri.decodeComponent(restaurantName)
              : null,
        );
      },
    ),
    GoRoute(
      path: '/restaurant/:id',
      builder: (context, state) => RestaurantDetailScreen(
        restaurantId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/entry/:id',
      builder: (context, state) => EntryDetailScreen(
        entryId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
  path: '/edit-restaurant/:id',
  builder: (context, state) => EditRestaurantScreen(
    restaurantId: state.pathParameters['id']!,
  ),
),
GoRoute(
  path: '/edit-entry/:id',
  builder: (context, state) => EditEntryScreen(
    entryId: state.pathParameters['id']!,
  ),
),
  ],
);

class JourniBitesApp extends StatelessWidget {
  const JourniBitesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'JourniBites',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepOrange,
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}