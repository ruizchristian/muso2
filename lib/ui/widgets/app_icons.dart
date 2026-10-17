import 'package:flutter/material.dart';

/// App icon set.
///
/// Names are semantic (`play`, `repeatOne`) rather than glyph-specific, so a glyph can be swapped
/// for a better one without touching call sites.
abstract final class AppIcons {
  static const play = Icons.play_arrow_rounded;
  static const pause = Icons.pause_rounded;
  static const next = Icons.skip_next_rounded;
  static const previous = Icons.skip_previous_rounded;
  static const shuffle = Icons.shuffle_rounded;
  static const repeat = Icons.repeat_rounded;
  static const repeatOne = Icons.repeat_one_rounded;
  static const heart = Icons.favorite_border_rounded;
  static const heartFilled = Icons.favorite_rounded;
  static const chevronDown = Icons.keyboard_arrow_down_rounded;
  static const chevronRight = Icons.chevron_right_rounded;
  static const arrowLeft = Icons.arrow_back_rounded;
  static const search = Icons.search_rounded;
  static const music = Icons.music_note_rounded;

  /// Vinyl disc — reads as "album" at tile size far better than a note, which turns to mush.
  static const disc = Icons.album_rounded;
  static const person = Icons.person_rounded;

  /// Equaliser bars, used to mark the row that is currently playing.
  static const equalizer = Icons.graphic_eq_rounded;
  static const home = Icons.home_rounded;
  static const homeOutline = Icons.home_outlined;
  static const library = Icons.library_music_rounded;
  static const libraryOutline = Icons.library_music_outlined;
  static const queue = Icons.queue_music_rounded;
  static const more = Icons.more_horiz_rounded;
  static const sort = Icons.sort_rounded;
  static const check = Icons.check_rounded;
  static const settings = Icons.settings_outlined;
  static const close = Icons.close_rounded;
  static const edit = Icons.edit_rounded;
  static const delete = Icons.delete_outline_rounded;
}
