import 'package:flutter/widgets.dart';

import '../../theme/layout.dart';

/// Caps line length on tablets while staying full-bleed on phones.
class ContentContainer extends StatelessWidget {
  const ContentContainer({super.key, required this.child, this.top = 0, this.bottom = 0});

  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Layout.maxContentWidth),
        // Full available width, so children lay out from the leading edge instead of shrinking
        // to their content and being centred.
        child: SizedBox(
          width: double.infinity,
          child: Padding(padding: EdgeInsets.fromLTRB(16, top, 16, bottom), child: child),
        ),
      ),
    );
  }
}

/// Scroll `paddingBottom` so the last row clears the floating mini player.
///
/// Inside the tab shell the bottom safe area is already paid by the tab bar (the shell removes it
/// from `MediaQuery`), so this one formula is right on every screen.
double scrollPaddingOf(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom + Layout.miniPlayerHeight + Layout.scrollTailSpace;
