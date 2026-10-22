import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/ui/kid_text.dart';
import '../../game/engine/game_scene.dart';
import '../../services/audio/fun_sound_player.dart';
import '../../services/audio/fun_sound_synth.dart';
import '../../services/audio/kids_speech_service.dart';
import '../../services/progress/progress_service.dart';
import 'ar_explorer_engine.dart';
import 'ar_explorer_play_view.dart' show ARExplorerCameraFill;
import 'ar_explorer_progress_store.dart';
import 'ar_explorer_text.dart';
import 'ar_explorer_world_content.dart';

const _ink = Color(0xFF403380);

/// "My AR World": everything the child has collected by finishing Explorer Levels, with the ones
/// still to earn shown as locked pictures. Purely a reward: nothing here can be bought.
/// Pops with true when the child wants to place them in the room.
class ARExplorerCollectionView extends StatelessWidget {
  const ARExplorerCollectionView({super.key, required this.store});
  final ARExplorerProgressStore store;

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    final collected = store.progress.collection;
    final levels = ARExplorerWorldCatalog.levelRewards.keys.toList()..sort();
    return Scaffold(
      appBar: AppBar(
        title: Text('🏡 ${ARExplorerText.myARWorld.resolve(language)}', style: kid(18, color: _ink)),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(ARExplorerText.done.resolve(language)))],
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(ARExplorerText.itemsCollected(collected.length, ARExplorerWorldCatalog.collectibleIDs.length).resolve(language),
            textAlign: TextAlign.center, style: kid(16, weight: FontWeight.w700, color: Colors.black54)),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, box) {
          final columns = (box.maxWidth / 108).floor().clamp(2, 6);
          final width = (box.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final level in levels)
              () {
                final id = ARExplorerWorldCatalog.levelRewards[level]!;
                final owned = collected.contains(id);
                final name = ARExplorerWorldCatalog.names(id)[language] ?? id;
                return Semantics(
                  label: owned ? name : ARExplorerText.lockedItem(level).resolve(language),
                  child: Container(
                    width: width,
                    height: 100,
                    decoration: BoxDecoration(color: const Color(0xFFF1F0F6), borderRadius: BorderRadius.circular(18)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Stack(clipBehavior: Clip.none, children: [
                        Opacity(
                          opacity: owned ? 1 : 0.3,
                          child: ColorFiltered(
                            colorFilter: owned
                                ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                                : const ColorFilter.matrix([0.33, 0.33, 0.33, 0, 0, 0.33, 0.33, 0.33, 0, 0, 0.33, 0.33, 0.33, 0, 0, 0, 0, 0, 1, 0]),
                            child: Text(ARExplorerWorldCatalog.emoji(id) ?? '❓', style: const TextStyle(fontSize: 46)),
                          ),
                        ),
                        if (!owned) const Positioned(right: -6, bottom: 0, child: Icon(Icons.lock, size: 14, color: Colors.black45)),
                      ]),
                      const SizedBox(height: 6),
                      Text(owned ? name : '$level', maxLines: 1, overflow: TextOverflow.ellipsis, style: kid(13, weight: FontWeight.w700, color: _ink)),
                    ]),
                  ),
                );
              }(),
          ]);
        }),
        const SizedBox(height: 18),
        if (collected.isEmpty)
          Text(ARExplorerText.collectionEmpty.resolve(language),
              textAlign: TextAlign.center, style: kid(17, weight: FontWeight.w600, color: Colors.black54))
        else
          GestureDetector(
            onTap: () => Navigator.of(context).pop(true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(color: const Color(0xFF664DE6), borderRadius: BorderRadius.circular(40)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.view_in_ar, color: Colors.white),
                const SizedBox(width: 8),
                Text(ARExplorerText.placeInRoom.resolve(language), style: kid(20, color: Colors.white)),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Places the child's collected items around their room. Separate from the learning missions: no
/// recognition runs here, only ChihChi and the chosen pictures.
class ARExplorerWorldPlaceView extends StatefulWidget {
  const ARExplorerWorldPlaceView({super.key, required this.store});
  final ARExplorerProgressStore store;

  @override
  State<ARExplorerWorldPlaceView> createState() => _ARExplorerWorldPlaceViewState();
}

class _ARExplorerWorldPlaceViewState extends State<ARExplorerWorldPlaceView> {
  final _engine = ARExplorerEngine(showsVirtualContent: true);
  final _sounds = FunSoundPlayer();
  late final KidsSpeechService _speech;
  String? _selected;
  late final AppState _appState = context.read<AppState>();

  List<String> get _items => ARExplorerWorldCatalog.collectibleIDs.where(widget.store.progress.collection.contains).toList();

  @override
  void initState() {
    super.initState();
    _selected = _items.firstOrNull;
    _speech = KidsSpeechService(isEnabled: () => _appState.audioService.voiceEnabled && widget.store.progress.voiceGuidance);
    _engine.reduceMotion = context.read<ProgressService>().progress.reducedMotion;
    _engine.state.addListener(_changed);
    _engine.start();
    _speech.speakLine(ARExplorerText.tapFloorToPlace.resolve(_appState.language), _appState.language);
  }

  @override
  void dispose() {
    _engine.state.removeListener(_changed);
    _speech.dispose();
    _sounds.stop();
    _engine.stop();
    _engine.disposeScene();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _tap(Offset point) {
    final language = _appState.language;
    if (!_engine.hasStage) {
      if (_engine.placeStage(point, _appState.theme.characterEmoji)) {
        _pop();
        _speech.speakLine(ARExplorerText.tapToPlaceItem.resolve(language), language);
      } else {
        _speech.speakLine(ARExplorerText.placeCloser.resolve(language), language);
      }
      setState(() {});
      return;
    }
    final emoji = _selected == null ? null : ARExplorerWorldCatalog.emoji(_selected!);
    if (emoji == null) return;
    if (_engine.placeItem(emoji, point)) {
      _pop();
    } else {
      _speech.speakLine(ARExplorerText.placeCloser.resolve(language), language);
    }
  }

  void _pop() {
    if (_appState.audioService.soundEnabled) _sounds.play(FunSound.pop);
  }

  @override
  Widget build(BuildContext context) {
    final language = _appState.language;
    final controller = _engine.controller;
    final running = _engine.state.value == CameraState.running && controller != null && controller.value.isInitialized;
    Widget round(IconData icon, String label, Color tint, VoidCallback onTap) => Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white),
            ),
          ),
        );
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _tap(d.localPosition),
            child: Semantics(
              label: ARExplorerText.tapToPlaceItem.resolve(language),
              child: Stack(fit: StackFit.expand, children: [
                if (running) ARExplorerCameraFill(controller: controller),
                IgnorePointer(child: GameView(scene: _engine)),
              ]),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              Row(children: [
                round(Icons.close, ARExplorerText.explorerHome.resolve(language), Colors.black.withValues(alpha: 0.35), () => Navigator.of(context).pop()),
                const Spacer(),
                round(Icons.delete, ARExplorerText.clear.resolve(language), Colors.orange, () {
                  _engine.clearStagePieces();
                  setState(() {});
                }),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(30)),
                child: Text(_engine.hasStage ? '👆 ${_selected == null ? '' : ARExplorerWorldCatalog.emoji(_selected!) ?? ''}' : '👇📱',
                    style: const TextStyle(fontSize: 34)),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: Container(
                  height: 90,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(24)),
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final id in _items)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 10),
                        child: Semantics(
                          button: true,
                          selected: _selected == id,
                          label: ARExplorerWorldCatalog.names(id)[language] ?? id,
                          child: GestureDetector(
                            onTap: () => setState(() => _selected = id),
                            child: Container(
                              width: 70,
                              height: 70,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _selected == id ? Colors.yellow : Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(ARExplorerWorldCatalog.emoji(id) ?? '❓', style: const TextStyle(fontSize: 40)),
                            ),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
