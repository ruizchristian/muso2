import 'package:flutter/material.dart';

import '../state/theme_controller.dart';
import '../theme/layout.dart';
import '../ui/widgets/app_icons.dart';
import 'library_screen.dart';
import 'search_screen.dart';

const _tabs = [
  // Home is hidden for now; HomeScreen (home_screen.dart) is kept so it can come back as a tab.
  (title: 'Your Library', icon: AppIcons.libraryOutline, iconFocused: AppIcons.library),
  (title: 'Search', icon: AppIcons.search, iconFocused: AppIcons.search),
];

/// The tabs. Each keeps its state (scroll position, search text) while another is showing.
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
              child: IndexedStack(index: _index, children: const [LibraryScreen(), SearchScreen()]),
            ),
          ),
          Container(
            // Pinned to the exact height the mini player is positioned against.
            height: Layout.tabBarBaseHeight + bottomInset,
            padding: EdgeInsets.only(bottom: bottomInset),
            decoration: BoxDecoration(
              color: palette.base,
              border: Border(
                top: BorderSide(color: palette.line, width: Layout.tabBarBorder),
              ),
            ),
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i += 1)
                  Expanded(
                    // Icons only, so the name is what a screen reader announces.
                    child: Semantics(
                      selected: i == _index,
                      button: true,
                      label: _tabs[i].title,
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _index = i),
                        child: Center(
                          child: Icon(
                            i == _index ? _tabs[i].iconFocused : _tabs[i].icon,
                            size: 26,
                            color: i == _index ? palette.accent : palette.faint,
                          ),
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
