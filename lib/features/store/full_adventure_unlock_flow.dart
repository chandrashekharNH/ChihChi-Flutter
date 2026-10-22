import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/store/entitlement_manager.dart';
import '../../core/store/free_uses.dart';
import '../../core/store/premium_access.dart';
import '../../core/store/store_manager.dart';
import '../../core/ui/kid_text.dart';
import '../../core/ui/palette.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/home_game.dart';
import '../../services/audio/audio_service.dart';
import '../../services/progress/progress_service.dart';
import '../parent/parent_components.dart';
import '../parent/parent_gate_view.dart';
import 'store_text.dart';

/// What a child sees on reaching Full Adventure content: a celebration and "ask a grown-up". No
/// price or payment button is shown until a grown-up passes the parent gate.
class FullAdventureUnlockFlow extends StatefulWidget {
  const FullAdventureUnlockFlow({
    super.key,
    required this.game,
    required this.freeLevelsDone,
    this.usedFreeUses = false,
    required this.onClose,
  });

  final HomeGame game;

  /// The child really finished the free levels; otherwise the card just says it's a Full Adventure part.
  final bool freeLevelsDone;

  /// Opened because the free uses of Free Play or My Photo Puzzle ran out.
  final bool usedFreeUses;
  final VoidCallback onClose;

  /// Shows the card full screen (then the gate and purchase screen).
  static Future<void> show(BuildContext context, HomeGame game, {required bool freeLevelsDone, bool usedFreeUses = false}) {
    return Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => FullAdventureUnlockFlow(
        game: game,
        freeLevelsDone: freeLevelsDone,
        usedFreeUses: usedFreeUses,
        onClose: () => Navigator.of(context).pop(),
      ),
    ));
  }

  /// Opens the card by itself once per game and child, after the last free level, and only when
  /// the store has said the family hasn't bought it (so a grown-up who bought is never asked).
  static Future<void> offerOnceIfDue(BuildContext context, HomeGame game, {required bool lastFreeLevelDone}) async {
    if (!lastFreeLevelDone) return;
    final entitlements = context.read<EntitlementManager>();
    if (entitlements.state != EntitlementState.free) return;
    final key = 'fullAdventureOffered.${context.read<ProgressService>().activeProfileID}.${game.rawValue}';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(key) ?? false) return;
    await prefs.setBool(key, true);
    if (context.mounted) await show(context, game, freeLevelsDone: true);
  }

  @override
  State<FullAdventureUnlockFlow> createState() => _FullAdventureUnlockFlowState();
}

enum _Step { card, gate, purchase }

class _FullAdventureUnlockFlowState extends State<FullAdventureUnlockFlow> {
  _Step _step = _Step.card;

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _Step.card:
        return _card(context);
      case _Step.gate:
        return ParentGateView(onSuccess: () => setState(() => _step = _Step.purchase), onClose: widget.onClose);
      case _Step.purchase:
        return FullAdventureView(onClose: widget.onClose);
    }
  }

  Widget _card(BuildContext context) {
    final appState = context.watch<AppState>();
    final language = appState.language;
    final headline = widget.usedFreeUses
        ? StoreText.usedFreeUses(FreeUses.limit)
        : widget.freeLevelsDone
            ? StoreText.completedFree(PremiumAccess.freeLevels(widget.game) ?? 10)
            : StoreText.partOfFullAdventure;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [appState.theme.gradientTop, appState.theme.gradientBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(children: [
              const Spacer(),
              ExcludeSemantics(
                child: Text(widget.usedFreeUses || widget.freeLevelsDone ? '🎉🏆🎉' : '👑', style: const TextStyle(fontSize: 64)),
              ),
              const SizedBox(height: 22),
              Text(headline.resolve(language), textAlign: TextAlign.center, style: kid(28, color: Colors.white)),
              const SizedBox(height: 22),
              Text(StoreText.askGrownUp.resolve(language),
                  textAlign: TextAlign.center,
                  style: kid(19, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9))),
              const Spacer(),
              Semantics(
                button: true,
                child: GestureDetector(
                  onTap: () {
                    appState.audioService.playEffect(SoundEffect.buttonTap);
                    setState(() => _step = _Step.gate);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(color: Colors.yellow, borderRadius: BorderRadius.circular(40)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.people, color: rgb(0.3, 0.2, 0)),
                      const SizedBox(width: 8),
                      Flexible(child: Text(StoreText.askGrownUpButton.resolve(language), style: kid(20, color: rgb(0.3, 0.2, 0)))),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              TextButton(
                onPressed: widget.onClose,
                child: Text(StoreText.keepPlaying.resolve(language), style: kid(18, weight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(height: 12),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The purchase screen. Only shown to grown-ups (after the parent gate, or inside the Parent Zone).
class FullAdventureView extends StatefulWidget {
  const FullAdventureView({super.key, this.onClose});
  final VoidCallback? onClose;

  @override
  State<FullAdventureView> createState() => _FullAdventureViewState();
}

class _FullAdventureViewState extends State<FullAdventureView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = context.read<StoreManager>();
      store.clearStatus();
      if (store.fullAdventure == null) store.loadProducts();
    });
  }

  bool _busy(StoreManager store) =>
      store.purchaseStatus.kind == PurchaseStatusKind.purchasing || store.purchaseStatus.kind == PurchaseStatusKind.restoring;

  String? _status(StoreManager store, EntitlementManager entitlements, AppLanguage language) {
    final s = store.purchaseStatus;
    switch (s.kind) {
      case PurchaseStatusKind.idle:
      case PurchaseStatusKind.purchasing:
        return entitlements.isSettled || entitlements.isPremium ? null : StoreText.checking.resolve(language);
      case PurchaseStatusKind.restoring:
        return StoreText.checking.resolve(language);
      case PurchaseStatusKind.pending:
        return StoreText.pending.resolve(language);
      case PurchaseStatusKind.purchased:
        return StoreText.purchased.resolve(language);
      case PurchaseStatusKind.cancelled:
        return StoreText.cancelled.resolve(language);
      case PurchaseStatusKind.restored:
        return StoreText.restored.resolve(language);
      case PurchaseStatusKind.nothingToRestore:
        return StoreText.nothingToRestore.resolve(language);
      case PurchaseStatusKind.failed:
        return s.failure == PurchaseFailure.network ? StoreText.offline.resolve(language) : StoreText.failed.resolve(language);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    final store = context.watch<StoreManager>();
    final entitlements = context.watch<EntitlementManager>();
    final status = _status(store, entitlements, language);
    final problem = store.purchaseStatus.kind == PurchaseStatusKind.failed;

    Widget buy() {
      switch (store.productStatus) {
        case ProductStatus.loading:
          return ListTile(
            leading: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            title: Text(StoreText.loadingPrice.resolve(language), style: TextStyle(color: secondaryText(context))),
          );
        case ProductStatus.unavailable:
          return ListTile(
            title: Text(StoreText.offline.resolve(language), style: TextStyle(color: secondaryText(context))),
            subtitle: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(onPressed: store.loadProducts, child: Text(StoreText.tryAgain.resolve(language))),
            ),
          );
        case ProductStatus.ready:
          return ListTile(
            enabled: !_busy(store),
            onTap: store.buyFullAdventure,
            title: Text(StoreText.unlockButton.resolve(language),
                style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
            trailing: store.purchaseStatus.kind == PurchaseStatusKind.purchasing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(store.displayPrice ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
          );
      }
    }

    return ParentPage(
      title: StoreText.title.resolve(language),
      leading: widget.onClose == null ? null : IconButton(icon: const Icon(Icons.close), onPressed: widget.onClose),
      children: [
        ParentSection(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const ExcludeSemantics(child: Text('👑', style: TextStyle(fontSize: 44))),
              const SizedBox(height: 10),
              Text(StoreText.title.resolve(language),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(StoreText.subtitle.resolve(language), style: TextStyle(color: secondaryText(context))),
            ]),
          ),
          for (final line in [
            StoreText.benefitLevels,
            StoreText.benefitWorlds,
            StoreText.benefitOffline,
            StoreText.benefitNoSubscription,
            StoreText.benefitNoRecurring,
          ])
            ListTile(leading: const Icon(Icons.check_circle, color: Colors.green), title: Text(line.resolve(language))),
        ]),
        ParentSection(footer: StoreText.paymentsFooter.resolve(language), children: [
          if (entitlements.isPremium)
            ListTile(
              leading: const Icon(Icons.verified, color: Colors.green),
              title: Text(StoreText.unlockedHere.resolve(language), style: const TextStyle(color: Colors.green)),
            )
          else
            buy(),
          if (status != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Text(status, style: TextStyle(fontSize: 13, color: problem ? Colors.red : secondaryText(context))),
            ),
          ListTile(
            enabled: !_busy(store),
            onTap: store.restore,
            title: Text(StoreText.restoreButton.resolve(language), style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
        ]),
        ParentSection(children: [
          ListTile(
            title: Text(StoreText.privacyPolicy.resolve(language), style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            onTap: () => launchUrl(StoreLinks.privacyPolicy),
          ),
          ListTile(
            title: Text(StoreText.termsOfUse.resolve(language), style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            onTap: () => launchUrl(StoreLinks.termsOfUse),
          ),
        ]),
        if (widget.onClose != null)
          ParentSection(children: [
            ListTile(
              onTap: widget.onClose,
              title: Text(
                (entitlements.isPremium ? StoreText.keepPlaying : StoreText.continueFree).resolve(language),
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ]),
      ],
    );
  }
}
