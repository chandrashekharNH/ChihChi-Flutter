import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/localization/localized.dart';
import '../../core/ui/kid_text.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/ui_text.dart';
import '../../services/audio/audio_service.dart';
import '../../services/progress/progress_service.dart';

/// 🌐 button for game and level screens. Picking a language updates the app and saves it; a game
/// screen showing it restarts its level in the new language. The family's own language is listed
/// first, then the rest in order of how near they are spoken.
class LanguageSwitchButton extends StatelessWidget {
  const LanguageSwitchButton({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Semantics(
      button: true,
      label: UIText.changeLanguage.resolve(appState.language),
      child: GestureDetector(
        onTap: () => showLanguagePicker(context),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.language, size: 18, color: Colors.white),
            const SizedBox(width: 4),
            Text(appState.language.shortLabel, style: kid(15, color: Colors.white)),
          ]),
        ),
      ),
    );
  }
}

/// The language list as a sheet: suggested languages first, then the rest.
Future<void> showLanguagePicker(BuildContext context) {
  final appState = context.read<AppState>();
  final progress = context.read<ProgressService>();
  final order = appState.languageOrder;
  order.listShown();
  void select(AppLanguage language) {
    Navigator.of(context).pop();
    if (language == appState.language) return;
    appState.audioService.playEffect(SoundEffect.buttonTap);
    appState.setLanguage(language);
    progress.updateLanguage(language);
  }

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => ListenableBuilder(
      listenable: order,
      builder: (context, _) {
        final current = appState.language;
        Widget tile(AppLanguage language) => ListTile(
              leading: Text(language.flag, style: const TextStyle(fontSize: 22)),
              title: Text(language.displayName, style: kid(17, weight: FontWeight.w600)),
              trailing: language == current ? const Icon(Icons.check) : null,
              onTap: () => select(language),
            );
        Widget header(String text) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(text, style: kid(13, weight: FontWeight.w700, color: Colors.grey)),
            );
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          child: ListView(shrinkWrap: true, children: [
            header(L('Suggested for you').resolve(current)),
            ...order.suggested.map(tile),
            header(L('More languages').resolve(current)),
            ...order.others.map(tile),
            const SizedBox(height: 20),
          ]),
        );
      },
    ),
  );
}
