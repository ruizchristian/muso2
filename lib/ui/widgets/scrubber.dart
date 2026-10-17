import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../state/theme_controller.dart';
import 'muso_text.dart';

const _trackHeight = 4.0;
const _knobSize = 12.0;
const _knobActiveScale = 1.6;

/// How close real playback must get to a committed seek before the bar follows live position
/// again. Without this the knob snaps back to the pre-seek spot while the player catches up.
const _settleEpsilon = 0.02;

/// Draggable, tappable playback position bar.
class Scrubber extends StatefulWidget {
  const Scrubber({
    super.key,
    required this.positionMs,
    required this.durationMs,
    required this.onSeek,
  });

  final int positionMs;
  final int durationMs;
  final ValueChanged<int> onSeek;

  @override
  State<Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<Scrubber> {
  bool _dragging = false;
  double _dragFraction = 0;

  /// Committed seek target, held until playback reaches it.
  double? _pending;

  double get _liveFraction =>
      widget.durationMs > 0 ? (widget.positionMs / widget.durationMs).clamp(0.0, 1.0) : 0.0;

  @override
  void didUpdateWidget(Scrubber oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Release the held position once real playback reaches it.
    if (_pending != null && (_liveFraction - _pending!).abs() < _settleEpsilon) {
      _pending = null;
    }
  }

  double _fractionAt(double dx, double width) => width <= 0 ? 0 : (dx / width).clamp(0.0, 1.0);

  void _commit(double fraction) {
    setState(() {
      _dragging = false;
      _pending = fraction;
    });
    widget.onSeek((fraction * widget.durationMs).round());
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fraction = _dragging ? _dragFraction : (_pending ?? _liveFraction);

    // While the user drives the bar the label follows the finger, not playback.
    final displayedMs = _dragging || _pending != null
        ? (fraction * widget.durationMs).round()
        : widget.positionMs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          slider: true,
          label: 'Playback position',
          value: '${formatDuration(displayedMs)} of ${formatDuration(widget.durationMs)}',
          // 10-second steps for screen-reader and switch-control users.
          onIncrease: () => widget.onSeek((widget.positionMs + 10000).clamp(0, widget.durationMs)),
          onDecrease: () => widget.onSeek((widget.positionMs - 10000).clamp(0, widget.durationMs)),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _commit(_fractionAt(details.localPosition.dx, width)),
                onHorizontalDragStart: (details) => setState(() {
                  _dragging = true;
                  _pending = null;
                  _dragFraction = _fractionAt(details.localPosition.dx, width);
                }),
                onHorizontalDragUpdate: (details) =>
                    setState(() => _dragFraction = _fractionAt(details.localPosition.dx, width)),
                onHorizontalDragEnd: (_) => _commit(_dragFraction),
                onHorizontalDragCancel: () => setState(() => _dragging = false),
                child: SizedBox(
                  height: _trackHeight + 24,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: _trackHeight,
                        decoration: BoxDecoration(
                          color: palette.line,
                          borderRadius: BorderRadius.circular(_trackHeight),
                        ),
                      ),
                      Container(
                        height: _trackHeight,
                        width: width * fraction,
                        decoration: BoxDecoration(
                          color: palette.content,
                          borderRadius: BorderRadius.circular(_trackHeight),
                        ),
                      ),
                      Positioned(
                        left: width * fraction - _knobSize / 2,
                        child: AnimatedScale(
                          scale: _dragging ? _knobActiveScale : 1,
                          duration: const Duration(milliseconds: 120),
                          child: Container(
                            width: _knobSize,
                            height: _knobSize,
                            decoration: BoxDecoration(
                              color: palette.content,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            MusoText(
              formatDuration(displayedMs),
              variant: TextVariant.caption,
              tone: TextTone.muted,
            ),
            MusoText(
              '-${formatDuration((widget.durationMs - displayedMs).clamp(0, widget.durationMs))}',
              variant: TextVariant.caption,
              tone: TextTone.muted,
            ),
          ],
        ),
      ],
    );
  }
}
