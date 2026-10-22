import 'package:flutter/material.dart';

import '../../core/ui/kid_text.dart';

/// Back button, a centred title, and room for one button on the other side.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, required this.onBack, this.trailing});
  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 10, 20, 16),
      child: Row(children: [
        Semantics(
          button: true,
          label: MaterialLocalizations.of(context).backButtonTooltip,
          child: GestureDetector(
            onTap: onBack,
            child: const Icon(Icons.arrow_circle_left, size: 32, color: Colors.white),
          ),
        ),
        Expanded(
          child: Text(title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kid(20, color: Colors.white, shadows: softTextShadow)),
        ),
        SizedBox(width: 32, child: trailing),
      ]),
    );
  }
}

/// A white rounded card with a coloured title.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.title, required this.color, required this.cardColor, required this.child});
  final String title;
  final Color color;
  final Color cardColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: kid(16, weight: FontWeight.w700, color: color)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}
