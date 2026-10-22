import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/ui/kid_text.dart';

/// The glassy bar pinned to the top of every route map page: back, title, then the page's own
/// buttons (language, stars…). The map scrolls underneath it.
class RouteMapTopBar extends StatelessWidget {
  const RouteMapTopBar({
    super.key,
    required this.title,
    this.subtitle,
    required this.onBack,
    this.trailing = const [],
    this.accessory,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final List<Widget> trailing;

  /// Extra controls under the title row, on the same glass (e.g. Build the Picture's pickers).
  final Widget? accessory;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, top + 8, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.25), width: 0.5)),
            boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 8, offset: Offset(0, 3))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              RoundIconButton(icon: Icons.arrow_back_ios_new, onTap: onBack),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(title, maxLines: 1, style: kid(20, color: Colors.white, shadows: softTextShadow)),
                  ),
                  if (subtitle != null)
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kid(13, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85))),
                ]),
              ),
              const SizedBox(width: 8),
              ...trailing,
            ]),
            if (accessory != null) ...[const SizedBox(height: 10), accessory!],
          ]),
        ),
      ),
    );
  }
}

/// A 44-point round button on a dark glass circle (back, close…).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.onTap, this.size = 44, this.semanticLabel});
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel ?? MaterialLocalizations.of(context).backButtonTooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
          child: Icon(icon, size: size * 0.45, color: Colors.white),
        ),
      ),
    );
  }
}
