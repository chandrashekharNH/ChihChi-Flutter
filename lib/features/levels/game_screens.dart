import 'package:flutter/material.dart';

import '../../domain/models/catch_letter_level.dart';
import '../../domain/models/home_game.dart';
import '../catch_learn/catch_learn_view.dart';
import '../catch_learn/catch_letter_intro_view.dart';
import '../ar_explorer/ar_explorer_view.dart';
import '../learn_blaster/learn_blaster_view.dart';
import '../common/play_session_tracking.dart';
import '../puzzle/puzzle_home_view.dart';
import '../turbo_race/turbo_world_map_view.dart';
import '../word_hunt/word_hunt_view.dart';

/// Where each game's screens are opened from, so maps and Home don't need to know every game's
/// internals. Each entry is filled in as its game is ported.
class GameScreens {
  static Widget catchLetter(int level) =>
      PlaySessionTracking(game: HomeGame.catchLetter, child: CatchLearnView(level: level));

  static Widget catchWorld(int level) =>
      PlaySessionTracking(game: HomeGame.catchWorld, child: WordHuntView(level: level));

  static Widget learnBlaster(int level) =>
      PlaySessionTracking(game: HomeGame.learnBlaster, child: LearnBlasterView(level: level));

  static Widget buildPicture() => const PuzzleHomeView();

  static Widget arExplorer() => const ARExplorerView();

  static Widget turboRace() => const TurboWorldMapView();

  static Widget catchLetterIntro(CatchLetterBatch batch, VoidCallback onDone) =>
      CatchLetterIntroView(batch: batch, onFinish: onDone);
}
