import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../storage/persist.dart';
import '../theme/themes.dart';

class ThemeController extends ChangeNotifier {
  ThemeController() {
    unawaited(_load());
  }

  ThemeId _themeId = defaultThemeId;

  MusoTheme get theme => themes[_themeId]!;

  Future<void> _load() async {
    // Theme ids are checked against the enum rather than trusted, so the persisted value can never
    // name a theme that does not exist.
    final saved = await readPersisted(
      StorageKeys.theme,
      (json) => ThemeId.values.asNameMap()[json['themeId']],
    );

    if (saved != null && saved != _themeId) {
      _themeId = saved;
      notifyListeners();
    }
  }

  void setTheme(ThemeId id) {
    if (id == _themeId) return;

    _themeId = id;
    notifyListeners();
    unawaited(writePersisted(StorageKeys.theme, {'themeId': id.name}));
  }
}

extension ThemeContext on BuildContext {
  /// The active theme. Rebuilds the caller when the theme changes.
  MusoTheme get musoTheme => watch<ThemeController>().theme;

  /// Shorthand for `musoTheme.palette` — by far the most common thing callers want.
  Palette get palette => musoTheme.palette;
}
