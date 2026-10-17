import 'package:flutter/material.dart';

import '../state/theme_controller.dart';
import '../theme/layout.dart';
import '../ui/widgets/app_icons.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';

const _tabs = [
  (title: 'Home', icon: AppIcons.homeOutline, iconFocused: AppIcons.home),
  (title: 'Search', icon: AppIcons.search, iconFocused: AppIcons.search),
  (title: 'Your Library', icon: AppIcons.libraryOutline, iconFocused: AppIcons.library),
];

/// The three tabs. Each keeps its state (scroll position, search text) while another is showing.
class TabsShell extends StatefulWidget {
  const TabsShell({super.key});

  @override
  State<TabsShell> createState() => _TabsShellState();
}

class _TabsShellState extends State<TabsShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: palette.base,
      child: Column(
        children: [
          Expanded(
            // The tab bar pays the bottom safe area, so the screens above it must not pay it too.
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: IndexedStack(
                index: _index,
                children: const [HomeScreen(), SearchScreen(), LibraryScreen()],
              ),
            ),
          ),
          Container(
            // Pinned to the exact height the mini player is positioned against.
            height: Layout.tabBarBaseHeight + bottomInset,
            padding: EdgeInsets.only(bottom: bottomInset, top: 6),
            decoration: BoxDecoration(
              color: palette.base,
              border: Border(top: BorderSide(color: palette.line, width: 0.5)),
            ),
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i += 1)
                  Expanded(
                    child: Semantics(
                      selected: i == _index,
                      button: true,
                      label: _tabs[i].title,
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _index = i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              i == _index ? _tabs[i].iconFocused : _tabs[i].icon,
                              size: 24,
                              color: i == _index ? palette.accent : palette.faint,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _tabs[i].title,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: i == _index ? palette.accent : palette.faint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
