import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/play_session_record.dart';
import '../../domain/models/reward_type.dart';
import '../../domain/models/ui_text.dart';
import '../../services/update/app_update_service.dart';
import '../home/home_game_text.dart';
import 'game_progress_detail_view.dart';
import 'parent_components.dart';
import 'parent_settings_view.dart';
import 'parent_statistics.dart';
import 'parent_text.dart';
import 'weekly_activity_view.dart';
import '../common/readable_width.dart';

/// Parent Dashboard home: a picture-first overview (profile, today, progress rings, the week at a
/// glance, recent games and rewards). Deeper screens are pushed from here.
class ParentDashboardView extends StatefulWidget {
  const ParentDashboardView({super.key, required this.viewModel, required this.onExit});
  final ParentDashboardViewModel viewModel;
  final VoidCallback onExit;

  @override
  State<ParentDashboardView> createState() => _ParentDashboardViewState();
}

class _ParentDashboardViewState extends State<ParentDashboardView> {
  ParentDashboardViewModel get vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  void _refresh() {
    vm.firstWeekday = ParentFormat.firstWeekday(context.read<AppState>().language);
    vm.refresh();
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)).then((_) => mounted ? _refresh() : null);

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    final update = context.watch<AppUpdateService>().availableUpdate;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) => Scaffold(
        backgroundColor: parentBackground(context),
        appBar: AppBar(
          backgroundColor: parentBackground(context),
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ParentText.dashboardTitle.resolve(language)),
            Text(ParentText.journeySubtitle.resolve(language),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: secondaryText(context))),
          ]),
          actions: [TextButton(onPressed: widget.onExit, child: Text(ParentText.exitParentZone.resolve(language)))],
        ),
        body: switch (vm.loadState) {
          DashboardLoadState.loading => const Center(child: CircularProgressIndicator()),
          DashboardLoadState.unavailable => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.warning_amber_rounded, size: 44, color: Colors.orange),
                  const SizedBox(height: 16),
                  Text(ParentText.unavailable.resolve(language),
                      textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _refresh, child: Text(ParentText.tryAgain.resolve(language))),
                ]),
              ),
            ),
          DashboardLoadState.ready => ListView(padding: readablePadding(context), children: [
              if (update != null) ...[_updateBanner(update, language), const SizedBox(height: 16)],
              _hero(language),
              const SizedBox(height: 16),
              _today(language),
              const SizedBox(height: 16),
              _progress(language),
              const SizedBox(height: 16),
              _weekPreview(language),
              const SizedBox(height: 16),
              _recent(language),
              const SizedBox(height: 16),
              _rewards(language),
              const SizedBox(height: 16),
              _settingsLink(language),
            ]),
        },
      ),
    );
  }

  Widget _updateBanner(AvailableUpdate update, AppLanguage language) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          const ParentIconBadge(icon: Icons.system_update, tint: Colors.blue, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ParentText.updateAvailable.resolve(language), style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(ParentText.updateMessage(update.version).resolve(language),
                  style: TextStyle(fontSize: 12, color: secondaryText(context))),
            ]),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => launchUrl(update.storeURL, mode: LaunchMode.externalApplication),
            child: Text(ParentText.updateButton.resolve(language)),
          ),
        ]),
      );

  Widget _hero(AppLanguage language) {
    Widget pill(IconData icon, String value, String title) => Expanded(
          child: Semantics(
            label: '${ParentText.today.resolve(language)}, $title, $value',
            excludeSemantics: true,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(height: 4),
                FittedBox(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
                const SizedBox(height: 4),
                Opacity(
                  opacity: 0.9,
                  child: Text(title, maxLines: 2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
                ),
              ]),
            ),
          ),
        );
    return Semantics(
      button: true,
      hint: ParentText.editProfile.resolve(language),
      child: GestureDetector(
        onTap: () => _push(ChildProfileView(onSaved: _refresh)),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: ParentPalette.hero, borderRadius: BorderRadius.circular(24)),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                ChildAvatarView(avatar: vm.childAvatar, size: 60),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(vm.childName.isEmpty ? ParentText.nicknamePlaceholder.resolve(language) : vm.childName,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    if (vm.recordedSince != null)
                      Opacity(
                        opacity: 0.85,
                        child: Text(
                            ParentText.recordedSince(ParentFormat.date(vm.recordedSince!, language)).resolve(language),
                            style: const TextStyle(fontSize: 12)),
                      ),
                  ]),
                ),
                const Icon(Icons.edit, color: Colors.white70),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                pill(Icons.schedule, ParentFormat.duration(vm.today.learningTime, language),
                    ParentText.learningTime.resolve(language)),
                pill(Icons.sports_esports, '${vm.today.gamesPlayed}', ParentText.gamesPlayed.resolve(language)),
                pill(Icons.star, '${vm.today.starsEarned}', ParentText.starsEarned.resolve(language)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _today(AppLanguage language) => ParentCard(
        title: ParentText.today.resolve(language),
        icon: Icons.wb_sunny,
        tint: Colors.orange,
        child: vm.today.isEmpty
            ? ParentEmptyState(
                icon: Icons.eco,
                title: ParentText.noActivityToday.resolve(language),
                message: ParentText.startJourney.resolve(language),
                tint: Colors.green,
              )
            : Column(children: [
                TimeByGameChart(items: vm.todayByGame, language: language),
                const SizedBox(height: 14),
                ActivitySummaryGrid(summary: vm.today, language: language),
              ]),
      );

  Widget _progress(AppLanguage language) => ParentCard(
        title: ParentText.learningProgress.resolve(language),
        icon: Icons.pie_chart,
        tint: Colors.purple,
        child: Column(children: [
          for (final summary in vm.games)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => _push(GameProgressDetailView(summary: summary)),
                child: GameProgressRow(summary: summary, language: language),
              ),
            ),
        ]),
      );

  Widget _weekPreview(AppLanguage language) => GestureDetector(
        onTap: () => _push(WeeklyActivityView(viewModel: vm)),
        child: ParentCard(
          title: ParentText.thisWeek.resolve(language),
          icon: Icons.calendar_today,
          tint: Colors.teal,
          child: Column(children: [
            vm.week.isEmpty
                ? ParentEmptyState(
                    icon: Icons.event_busy, title: ParentText.noActivityThisWeek.resolve(language), tint: Colors.teal)
                : WeeklyMinutesChart(days: vm.weekDays, language: language, compact: true),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Text(ParentText.seeWeeklyActivity.resolve(language),
                    style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
              ),
              Icon(Icons.chevron_right, color: secondaryText(context)),
            ]),
          ]),
        ),
      );

  Widget _recent(AppLanguage language) => ParentCard(
        title: ParentText.recentActivity.resolve(language),
        icon: Icons.history,
        tint: Colors.indigo,
        child: vm.recentSessions.isEmpty
            ? ParentEmptyState(
                icon: Icons.sports_esports, title: ParentText.noRecentActivity.resolve(language), tint: Colors.indigo)
            : Column(children: [
                for (final s in vm.recentSessions)
                  Padding(padding: const EdgeInsets.only(bottom: 10), child: RecentSessionRow(session: s, language: language)),
              ]),
      );

  Widget _rewards(AppLanguage language) {
    Widget tile(RewardType type, int count, String name, Color tint) => Semantics(
          label: '$name, $count',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: tint.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              Text(type.emoji, style: const TextStyle(fontSize: 32)),
              Text('$count', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              FittedBox(child: Text(name, style: TextStyle(fontSize: 11, color: secondaryText(context)))),
            ]),
          ),
        );
    final r = vm.rewards;
    return ParentCard(
      title: ParentText.rewards.resolve(language),
      icon: Icons.card_giftcard,
      tint: Colors.pink,
      child: r.isEmpty
          ? ParentEmptyState(icon: Icons.redeem, title: ParentText.noRewards.resolve(language), tint: Colors.pink)
          : Row(children: [
              Expanded(child: tile(RewardType.star, r.stars, UIText.stars.resolve(language), Colors.amber)),
              const SizedBox(width: 10),
              Expanded(child: tile(RewardType.candy, r.candy, UIText.candy.resolve(language), Colors.pink)),
              const SizedBox(width: 10),
              Expanded(child: tile(RewardType.iceCream, r.iceCream, UIText.iceCream.resolve(language), Colors.teal)),
              const SizedBox(width: 10),
              Expanded(child: tile(RewardType.chocolate, r.chocolate, UIText.chocolate.resolve(language), Colors.brown)),
            ]),
    );
  }

  Widget _settingsLink(AppLanguage language) => GestureDetector(
        onTap: () => _push(ParentSettingsView(viewModel: vm)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: parentCardColor(context), borderRadius: BorderRadius.circular(22)),
          child: Row(children: [
            const ParentIconBadge(icon: Icons.settings, tint: Colors.grey, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Text(ParentText.parentSettings.resolve(language),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
            Icon(Icons.chevron_right, color: secondaryText(context)),
          ]),
        ),
      );
}

/// Today / This Week numbers. Accuracy shows "No data yet" when nothing was answered.
class ActivitySummaryGrid extends StatelessWidget {
  const ActivitySummaryGrid({super.key, required this.summary, required this.language});
  final ActivitySummary summary;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => ParentStatGrid(stats: [
        ParentStat(ParentFormat.duration(summary.learningTime, language), ParentText.learningTime.resolve(language),
            Icons.schedule, ParentPalette.time),
        ParentStat('${summary.gamesPlayed}', ParentText.gamesPlayed.resolve(language), Icons.sports_esports,
            ParentPalette.games),
        ParentStat('${summary.levelsCompleted}', ParentText.levelsCompleted.resolve(language), Icons.flag,
            ParentPalette.levels),
        ParentStat('${summary.questionsAnswered}', ParentText.questionsAnswered.resolve(language), Icons.quiz,
            ParentPalette.questions),
        ParentStat(ParentFormat.accuracy(summary.accuracy, language), ParentText.accuracy.resolve(language),
            Icons.gps_fixed, ParentPalette.accuracy),
        ParentStat('${summary.starsEarned}', ParentText.starsEarned.resolve(language), Icons.star, ParentPalette.stars),
      ]);
}

/// One game: its badge, levels and stars, and a completion ring in the game's colours.
class GameProgressRow extends StatelessWidget {
  const GameProgressRow({super.key, required this.summary, required this.language});
  final GameProgressSummary summary;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final title = summary.game.title(language);
    final completion = summary.completion;
    final total = summary.totalLevels;
    final label = completion == null || total == null
        ? '$title, ${ParentText.notLevelBased.resolve(language)}'
        : '$title, ${ParentText.percentComplete(ParentFormat.percent(completion)).resolve(language)}, '
            '${ParentText.levelsOf(summary.completedCount, total).resolve(language)}';
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: summary.game.tint.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          GameBadge(game: summary.game, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (total != null) ...[
                Text(ParentText.levelsOf(summary.completedCount, total).resolve(language),
                    style: TextStyle(fontSize: 12, color: secondaryText(context))),
                if ((summary.totalStars ?? 0) > 0)
                  Row(children: [
                    const Icon(Icons.star, size: 13, color: Colors.orange),
                    Text(' ${summary.totalStars}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange)),
                  ]),
              ] else
                Text(
                  summary.activity.isEmpty
                      ? ParentText.notLevelBased.resolve(language)
                      : ParentText.playedFor(ParentFormat.duration(summary.activity.learningTime, language)).resolve(language),
                  style: TextStyle(fontSize: 12, color: secondaryText(context)),
                ),
            ]),
          ),
          SizedBox(
            width: 50,
            height: 50,
            child: completion != null
                ? ProgressRing(
                    progress: completion,
                    colors: summary.game.colors,
                    lineWidth: 6,
                    center: FittedBox(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text('${ParentFormat.percent(completion)}%',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  )
                : Icon(Icons.schedule, color: summary.game.tint),
          ),
          Icon(Icons.chevron_right, color: secondaryText(context)),
        ]),
      ),
    );
  }
}

class RecentSessionRow extends StatelessWidget {
  const RecentSessionRow({super.key, required this.session, required this.language});
  final PlaySessionRecord session;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final last = session.completedLevels.isEmpty ? null : session.completedLevels.last;
    return MergeSemantics(
      child: Row(children: [
        GameBadge(game: session.game, size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(session.game.title(language), style: const TextStyle(fontWeight: FontWeight.w600)),
            if (last != null)
              Row(children: [
                Text(ParentText.level(last.level).resolve(language),
                    style: TextStyle(fontSize: 12, color: secondaryText(context))),
                if (last.stars != null) ...[
                  const SizedBox(width: 6),
                  ParentStarsView(stars: last.stars!, language: language),
                ],
              ]),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(ParentFormat.duration(session.duration, language),
              style: TextStyle(fontWeight: FontWeight.w600, color: session.game.tint)),
          Text(ParentFormat.relative(session.startedAt, language, DateTime.now()),
              style: TextStyle(fontSize: 12, color: secondaryText(context))),
        ]),
      ]),
    );
  }
}

class ChildAvatarView extends StatelessWidget {
  const ChildAvatarView({super.key, required this.avatar, this.size = 48});
  final String avatar;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.25),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
          ),
          child: avatar.isEmpty
              ? Icon(Icons.person, size: size * 0.45, color: Colors.white)
              : Text(avatar, style: TextStyle(fontSize: size * 0.6)),
        ),
      );
}
