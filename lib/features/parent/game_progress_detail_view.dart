import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/home_game.dart';
import '../../domain/models/ui_text.dart';
import '../ar_explorer/ar_explorer_progress_store.dart';
import '../ar_explorer/ar_explorer_text.dart';
import '../home/home_game_text.dart';
import 'parent_components.dart';
import 'parent_statistics.dart';
import 'parent_text.dart';

/// One game in pictures: a completion ring, the last seven days, performance and a level map.
class GameProgressDetailView extends StatelessWidget {
  const GameProgressDetailView({super.key, required this.summary});
  final GameProgressSummary summary;

  HomeGame get game => summary.game;

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    return Scaffold(
      backgroundColor: parentBackground(context),
      appBar: AppBar(title: Text(game.title(language)), backgroundColor: parentBackground(context), scrolledUnderElevation: 0),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _header(language),
        const SizedBox(height: 16),
        _recentDays(context, language),
        const SizedBox(height: 16),
        _performance(context, language),
        if (summary.totalLevels != null) ...[const SizedBox(height: 16), _levelMap(context, language, summary.totalLevels!)],
        if (game == HomeGame.arHunt) ...[const SizedBox(height: 16), _arExplorer(language)],
      ]),
    );
  }

  Widget _header(AppLanguage language) {
    final completion = summary.completion;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: game.gradient, borderRadius: BorderRadius.circular(24)),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ExcludeSemantics(child: Text(game.icon, style: const TextStyle(fontSize: 44))),
              const SizedBox(height: 8),
              Text(game.title(language), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              if (summary.totalLevels != null)
                Text(ParentText.levelsOf(summary.completedCount, summary.totalLevels!).resolve(language),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              if (summary.totalStars != null)
                Semantics(
                  label: ParentText.starCount(summary.totalStars!).resolve(language),
                  excludeSemantics: true,
                  child: Row(children: [
                    const Icon(Icons.star, size: 16, color: Colors.white),
                    Text(' ${summary.totalStars}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                ),
            ]),
          ),
          if (completion != null)
            Semantics(
              label: ParentText.overallProgress.resolve(language),
              value: ParentText.percentComplete(ParentFormat.percent(completion)).resolve(language),
              excludeSemantics: true,
              child: SizedBox(
                width: 120,
                height: 120,
                child: ProgressRing(
                  progress: completion,
                  colors: [Colors.white, Colors.white.withValues(alpha: 0.7)],
                  lineWidth: 12,
                  center: Padding(
                    padding: const EdgeInsets.all(18),
                    child: FittedBox(
                      child: Column(children: [
                        Text('${ParentFormat.percent(completion)}%',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                        Text(ParentText.overallProgress.resolve(language),
                            textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.white)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _recentDays(BuildContext context, AppLanguage language) => ParentCard(
        title: ParentText.lastSevenDays.resolve(language),
        icon: Icons.bar_chart,
        tint: game.tint,
        footer: ParentText.weeklyChartCaption.resolve(language),
        child: summary.recentDays.every((d) => d.learningTime == 0)
            ? ParentEmptyState(icon: Icons.event_busy, title: ParentText.noRecentActivity.resolve(language), tint: game.tint)
            : WeeklyMinutesChart(days: summary.recentDays, language: language, singleColor: game.gradient),
      );

  Widget _performance(BuildContext context, AppLanguage language) {
    final activity = summary.activity;
    final accuracy = activity.accuracy ?? summary.placementAccuracy;
    final stats = [
      ParentStat(ParentFormat.duration(activity.learningTime, language), ParentText.timePlayed.resolve(language),
          Icons.schedule, ParentPalette.time),
      ParentStat('${activity.gamesPlayed}', ParentText.gamesPlayed.resolve(language), Icons.sports_esports,
          ParentPalette.games),
      if (activity.questionsAnswered > 0)
        ParentStat('${activity.questionsAnswered}', ParentText.questionsAnswered.resolve(language), Icons.quiz,
            ParentPalette.questions),
      if (summary.totalStars != null)
        ParentStat('${summary.totalStars}', UIText.stars.resolve(language), Icons.star, ParentPalette.stars),
    ];
    return ParentCard(
      title: ParentText.performance.resolve(language),
      icon: Icons.speed,
      tint: Colors.pink,
      footer: !activity.isEmpty && !game.recordsAnswers ? ParentText.noAnswerData.resolve(language) : null,
      child: activity.isEmpty && summary.levels.isEmpty
          ? ParentEmptyState(icon: Icons.sports_esports, title: ParentText.noRecentActivity.resolve(language), tint: Colors.pink)
          : Column(children: [
              if (accuracy != null) ...[
                Row(children: [
                  AccuracyRing(fraction: accuracy, language: language, size: 84),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        summary.placementAccuracy != null && activity.accuracy == null
                            ? ParentText.placementAccuracy.resolve(language)
                            : ParentText.accuracy.resolve(language),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (activity.questionsAnswered > 0)
                        Text(
                          '${activity.correctAnswers} / ${activity.questionsAnswered} · ${ParentText.correctAnswers.resolve(language)}',
                          style: TextStyle(color: secondaryText(context)),
                        ),
                    ]),
                  ),
                ]),
                const SizedBox(height: 14),
              ],
              ParentStatGrid(stats: stats),
            ]),
    );
  }

  /// AR Explorer keeps its own progress file; this reads a snapshot of it.
  Widget _arExplorer(AppLanguage language) {
    final p = ARExplorerProgressStore.snapshot();
    final favorite = p.favoriteMode;
    return ParentCard(
      title: ParentText.arExplorer.resolve(language),
      icon: Icons.public,
      tint: Colors.teal,
      child: ParentStatGrid(stats: [
        ParentStat('${p.explorerLevel}', ParentText.explorerLevelStat.resolve(language), Icons.flag, Colors.purple),
        ParentStat('${p.missionsCompleted}', ParentText.missionsCompleted.resolve(language), Icons.verified, Colors.green),
        ParentStat('${p.discoveredObjectIDs.length}', ParentText.objectsDiscovered.resolve(language), Icons.travel_explore,
            Colors.blue),
        ParentStat('${p.starsEarned}', ParentText.starsEarned.resolve(language), Icons.star, ParentPalette.stars),
        ParentStat('${p.collection.length}', ParentText.arWorldItems.resolve(language), Icons.card_giftcard, Colors.orange),
        if (favorite != null)
          ParentStat('${favorite.icon} ${ARExplorerText.modeName(favorite).resolve(language)}',
              ParentText.favoriteMode.resolve(language), Icons.favorite, Colors.pink),
      ]),
    );
  }

  Widget _levelMap(BuildContext context, AppLanguage language, int total) {
    final finished = {for (final l in summary.levels) l.level: l.stars};
    final idle = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
    return ParentCard(
      title: ParentText.levelMap.resolve(language),
      icon: Icons.map,
      tint: Colors.green,
      footer: summary.countedFromHistory ? ParentText.trackedLevelsNote.resolve(language) : null,
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (var level = 1; level <= total; level++)
          () {
            final done = finished.containsKey(level);
            final stars = finished[level];
            return Semantics(
              label: ParentText.level(level).resolve(language),
              value: done
                  ? (stars != null
                      ? ParentText.starCount(stars).resolve(language)
                      : ParentText.levelsCompleted.resolve(language))
                  : '',
              excludeSemantics: true,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: done ? game.gradient : null, color: done ? null : idle),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$level',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold, color: done ? Colors.white : secondaryText(context))),
                  if (done && stars != null) Text('★' * stars, style: const TextStyle(fontSize: 8, color: Colors.yellow)),
                ]),
              ),
            );
          }(),
      ]),
    );
  }
}
