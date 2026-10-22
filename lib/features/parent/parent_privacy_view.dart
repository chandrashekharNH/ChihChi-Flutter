import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../domain/models/home_game.dart';
import '../../domain/models/ui_text.dart';
import '../../services/progress/progress_service.dart';
import '../ar_explorer/ar_explorer_progress_store.dart';
import 'parent_components.dart';
import 'parent_text.dart';

/// What ChihChi stores and what it does not do. Every line reflects the current app: data lives
/// on the device; there is no analytics, advertising or account system.
class ParentPrivacyView extends StatelessWidget {
  const ParentPrivacyView({super.key});

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    Widget bullet(String text, IconData icon) => ListTile(leading: Icon(icon), title: Text(text));
    return ParentPage(title: ParentText.privacyTitle.resolve(language), children: [
      ParentSection(children: [Padding(padding: const EdgeInsets.all(16), child: Text(ParentText.privacyIntro.resolve(language)))]),
      ParentSection(header: ParentText.privacyStoredHeader.resolve(language), children: [
        bullet(ParentText.storesName.resolve(language), Icons.person_outline),
        bullet(ParentText.storesNameVoice.resolve(language), Icons.graphic_eq),
        bullet(ParentText.storesCharacter.resolve(language), Icons.face_retouching_natural),
        bullet(ParentText.storesProgress.resolve(language), Icons.star_border),
        bullet(ParentText.storesActivity.resolve(language), Icons.schedule),
        bullet(ParentText.storesSettings.resolve(language), Icons.settings_outlined),
      ]),
      ParentSection(header: ParentText.privacyNotHeader.resolve(language), children: [
        bullet(ParentText.noAccounts.resolve(language), Icons.no_accounts),
        bullet(ParentText.noAds.resolve(language), Icons.block),
        bullet(ParentText.noTracking.resolve(language), Icons.visibility_off),
        bullet(ParentPlatformText.noInternet.resolve(language), Icons.wifi_off),
      ]),
      ParentSection(children: [
        bullet(ParentText.cameraNote.resolve(language), Icons.photo_camera_outlined),
        bullet(ParentText.photosNote.resolve(language), Icons.photo_outlined),
        bullet(ParentText.characterPhotoNote.resolve(language), Icons.sentiment_satisfied_alt),
        bullet(ParentText.deletingNote.resolve(language), Icons.delete_outline),
      ]),
    ]);
  }
}

/// Clearly separated destructive action with a confirmation step.
class ResetProgressView extends StatefulWidget {
  const ResetProgressView({super.key, required this.onReset});
  final VoidCallback onReset;

  @override
  State<ResetProgressView> createState() => _ResetProgressViewState();
}

class _ResetProgressViewState extends State<ResetProgressView> {
  bool _didReset = false;

  Future<void> _confirm() async {
    final language = context.read<AppState>().language;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ParentText.resetQuestion.resolve(language)),
        content: Text(ParentText.resetMessage.resolve(language)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(ParentText.cancel.resolve(language))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(ParentText.resetButton.resolve(language)),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    context.read<ProgressService>().resetProgress();
    ARExplorerProgressStore().resetLearningProgress();
    setState(() => _didReset = true);
    widget.onReset();
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    return ParentPage(title: ParentText.resetTitle.resolve(language), children: [
      ParentSection(footer: ParentText.resetKeeps.resolve(language), children: [
        Padding(padding: const EdgeInsets.all(16), child: Text(ParentText.resetDescription.resolve(language))),
      ]),
      ParentSection(
        footer: _didReset ? '✓ ${ParentText.resetDone.resolve(language)}' : null,
        children: [
          ListTile(
            title: Text(ParentText.resetButton.resolve(language),
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            onTap: _confirm,
          ),
        ],
      ),
    ]);
  }
}

class AboutChihChiView extends StatelessWidget {
  const AboutChihChiView({super.key});

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    void push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    return ParentPage(title: ParentText.aboutTitle.resolve(language), children: [
      ParentSection(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: MergeSemantics(
            child: Column(children: [
              Text(UIText.appName.resolve(language),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text(ParentText.tagline.resolve(language),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: secondaryText(context))),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final info = snapshot.data;
                  final version = info == null ? '1.0' : '${info.version} (${info.buildNumber})';
                  return Text(ParentText.version(version).resolve(language),
                      style: TextStyle(fontSize: 12, color: secondaryText(context)));
                },
              ),
            ]),
          ),
        ),
      ]),
      ParentSection(header: ParentText.games.resolve(language), children: [
        for (final game in HomeGame.values)
          Padding(padding: const EdgeInsets.all(12), child: ParentGameLabel(game: game, language: language)),
      ]),
      ParentSection(children: [
        ListTile(
          leading: const Icon(Icons.back_hand),
          title: Text(ParentText.privacyTitle.resolve(language)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => push(const ParentPrivacyView()),
        ),
        ListTile(
          leading: const Icon(Icons.favorite_border),
          title: Text(ParentText.supportTitle.resolve(language)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => push(const SupportChihChiView()),
        ),
      ]),
    ]);
  }
}

/// Parent-only note about supporting ChihChi. The one purchase, Full Adventure, lives on its own
/// screen, always behind the parent gate.
class SupportChihChiView extends StatelessWidget {
  const SupportChihChiView({super.key});

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    return ParentPage(title: ParentText.supportTitle.resolve(language), children: [
      ParentSection(footer: ParentText.supportNoPurchase.resolve(language), children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.favorite, color: Colors.pink),
              const SizedBox(width: 8),
              Text(ParentText.supportTitle.resolve(language),
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.pink)),
            ]),
            const SizedBox(height: 12),
            Text(ParentText.supportBody.resolve(language)),
            const SizedBox(height: 12),
            Text(ParentText.supportOptional.resolve(language)),
            const SizedBox(height: 12),
            Text(ParentText.supportThanks.resolve(language), style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    ]);
  }
}
