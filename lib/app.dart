import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'routes.dart';
import 'state/library_controller.dart';
import 'state/theme_controller.dart';
import 'ui/player/mini_player.dart';

class MusoApp extends StatelessWidget {
  const MusoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Outermost, so everything below can read the active palette.
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => LibraryController()),
      ],
      child: const _ThemedApp(),
    );
  }
}

/// Split out so it sits inside the theme provider and rebuilds the Material theme from the active
/// palette — a switch has to repaint dialogs, sheets and text selection too, not just the screens.
class _ThemedApp extends StatelessWidget {
  const _ThemedApp();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return MaterialApp(
      title: 'Muso',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      navigatorObservers: [routeTracker],
      initialRoute: AppRoutes.tabs,
      onGenerateRoute: onGenerateRoute,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: palette.base,
        canvasColor: palette.base,
        colorScheme: ColorScheme.dark(
          primary: palette.accent,
          onPrimary: palette.onAccent,
          secondary: palette.glow,
          surface: palette.base,
          onSurface: palette.content,
          error: palette.danger,
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: palette.accent,
          selectionColor: palette.accent.withValues(alpha: 0.35),
          selectionHandleColor: palette.accent,
        ),
      ),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        // Mounted above the navigator so the mini player persists across tab and stack changes.
        child: Material(
          type: MaterialType.transparency,
          child: Stack(children: [child!, const MiniPlayerOverlay()]),
        ),
      ),
    );
  }
}
