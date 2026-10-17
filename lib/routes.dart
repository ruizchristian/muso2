import 'package:flutter/material.dart';

import 'screens/group_detail_screen.dart';
import 'screens/player_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/tabs_shell.dart';
import 'screens/track_edit_screen.dart';

abstract final class AppRoutes {
  static const tabs = '/';
  static const player = '/player';
  static const settings = '/settings';
  static const album = '/album';
  static const artist = '/artist';
  static const trackEdit = '/track/edit';
}

/// The root navigator. The mini player lives above it (so it survives every route change) and
/// navigates through this key.
final navigatorKey = GlobalKey<NavigatorState>();

/// Tracks the top-most *page* route, so the overlays above the navigator know whether a tab bar
/// is showing and whether the full player is open — and, separately, whether a sheet or dialog
/// is on top. Those overlays are painted above every route, so without the second flag they cover
/// the bottom of any sheet.
class RouteTracker extends NavigatorObserver {
  final topRoute = ValueNotifier<String?>(AppRoutes.tabs);
  final popupOpen = ValueNotifier(false);
  final _stack = <Route<dynamic>>[];

  void _sync() {
    final pages = _stack.whereType<PageRoute<dynamic>>();
    topRoute.value = pages.isEmpty ? null : pages.last.settings.name;
    popupOpen.value = _stack.isNotEmpty && _stack.last is PopupRoute<dynamic>;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route);
    _sync();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _sync();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _sync();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (index >= 0 && newRoute != null) {
      _stack[index] = newRoute;
    } else if (newRoute != null) {
      _stack.add(newRoute);
    }
    _sync();
  }
}

final routeTracker = RouteTracker();

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  final argument = settings.arguments;
  final id = argument is String && argument.isNotEmpty && argument.length <= 512 ? argument : null;

  return switch (settings.name) {
    AppRoutes.player => _SlideUpRoute(settings: settings, child: const PlayerScreen()),
    AppRoutes.settings => MaterialPageRoute(
      settings: settings,
      fullscreenDialog: true,
      builder: (_) => const SettingsScreen(),
    ),
    AppRoutes.album => MaterialPageRoute(
      settings: settings,
      builder: (_) => GroupDetailScreen(id: id, kind: GroupKind.album),
    ),
    AppRoutes.artist => MaterialPageRoute(
      settings: settings,
      builder: (_) => GroupDetailScreen(id: id, kind: GroupKind.artist),
    ),
    AppRoutes.trackEdit => MaterialPageRoute(
      settings: settings,
      fullscreenDialog: true,
      builder: (_) => TrackEditScreen(id: id),
    ),
    _ => MaterialPageRoute(
      settings: const RouteSettings(name: AppRoutes.tabs),
      builder: (_) => const TabsShell(),
    ),
  };
}

/// The full player slides up from the bottom, like a sheet. Opaque, so the screen underneath
/// never shows through.
class _SlideUpRoute extends PageRouteBuilder<void> {
  _SlideUpRoute({required super.settings, required Widget child})
    : super(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, _, _) => child,
        transitionsBuilder: (context, animation, _, child) {
          if (MediaQuery.disableAnimationsOf(context)) return child;

          return SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ),
            ),
            child: child,
          );
        },
      );
}

void openPlayer() => navigatorKey.currentState?.pushNamed(AppRoutes.player);
