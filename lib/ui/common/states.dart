import 'package:flutter/material.dart';

import '../../state/theme_controller.dart';
import '../widgets/app_icons.dart';
import '../widgets/buttons.dart';
import '../widgets/muso_text.dart';
import '../widgets/skeleton.dart';

/// Shared zero-data state. Do not hand-roll per-feature variants of this.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon = AppIcons.music,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: palette.elevated, shape: BoxShape.circle),
              child: Icon(icon, size: 30, color: palette.muted),
            ),
            const SizedBox(height: 20),
            MusoText(title, variant: TextVariant.heading, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 8),
              MusoText(message!, tone: TextTone.muted, textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              MusoButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

/// Failure state with a retry affordance. Never renders a raw error object.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: AppIcons.close,
    title: title,
    message: message,
    actionLabel: onRetry != null ? 'Try again' : null,
    onAction: onRetry,
  );
}

/// Row-shaped skeletons so the transition into real content does not jump.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  /// Shown under the placeholders, e.g. a live scan count.
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: message ?? 'Loading',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        children: [
          for (var i = 0; i < 8; i += 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Skeleton(width: 48, height: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Skeleton(width: constraints.maxWidth / 2, height: 14),
                          const SizedBox(height: 8),
                          Skeleton(width: constraints.maxWidth / 3, height: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: MusoText(message!, tone: TextTone.muted, textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.subtitle, this.rule = false});

  final String title;
  final String? subtitle;

  /// Draws a short neon rule above the title. Off by default — it is a deliberate accent, and a
  /// screen that puts one on every section has no accent at all.
  final bool rule;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rule)
            Container(
              width: 32,
              height: 2,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: context.palette.glow,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          MusoText(title, variant: TextVariant.heading, header: true),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            MusoText(subtitle!, variant: TextVariant.caption, tone: TextTone.muted),
          ],
        ],
      ),
    );
  }
}

class MusoSearchBar extends StatelessWidget {
  const MusoSearchBar({
    super.key,
    required this.controller,
    this.placeholder = 'What do you want to listen to?',
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String placeholder;

  /// The keyboard's search key.
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: palette.content, borderRadius: BorderRadius.circular(4)),
      child: Row(
        children: [
          Icon(AppIcons.search, size: 20, color: palette.base),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              label: 'Search your library',
              child: TextField(
                controller: controller,
                autocorrect: false,
                textInputAction: TextInputAction.search,
                onSubmitted: onSubmitted,
                // Keeps the caret and selection legible against the white field.
                cursorColor: palette.base,
                style: const TextStyle(color: Colors.black, fontSize: 16),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintText: placeholder,
                  hintStyle: const TextStyle(color: Color(0xFF585858), fontSize: 16),
                ),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => controller.text.isEmpty
                ? const SizedBox.shrink()
                : MusoIconButton(
                    icon: AppIcons.close,
                    size: ControlSize.sm,
                    semanticLabel: 'Clear search',
                    color: palette.base,
                    onPressed: controller.clear,
                  ),
          ),
        ],
      ),
    );
  }
}
