import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../domain/models/app_language.dart';
import 'parent_components.dart';
import 'parent_dashboard_view.dart';
import 'parent_statistics.dart';
import 'parent_text.dart';
import '../common/readable_width.dart';

/// The week in pictures: minutes per day by game, streak dots, time by game, screen time and
/// gentle insights shown as accuracy rings.
class WeeklyActivityView extends StatelessWidget {
  const WeeklyActivityView({super.key, required this.viewModel});
  final ParentDashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    final vm = viewModel;
    return Scaffold(
      backgroundColor: parentBackground(context),
      appBar: AppBar(
          title: Text(ParentText.weeklyActivity.resolve(language)),
          backgroundColor: parentBackground(context),
          scrolledUnderElevation: 0),
      body: ListView(padding: readablePadding(context), children: [
        ParentCard(
          title: ParentText.weeklyActivity.resolve(language),
          icon: Icons.bar_chart,
          tint: Colors.teal,
          footer: vm.week.isEmpty ? null : ParentText.weeklyChartCaption.resolve(language),
          child: vm.week.isEmpty
              ? ParentEmptyState(icon: Icons.event_busy, title: ParentText.noActivityThisWeek.resolve(language), tint: Colors.teal)
              : WeeklyMinutesChart(days: vm.weekDays, language: language),
        ),
        const SizedBox(height: 16),
        _streak(context, language),
        if (!vm.week.isEmpty) ...[
          const SizedBox(height: 16),
          ParentCard(
            title: ParentText.timeByGame.resolve(language),
            icon: Icons.pie_chart,
            tint: Colors.purple,
            child: TimeByGameChart(items: vm.weekByGame, language: language),
          ),
          const SizedBox(height: 16),
          ParentCard(
            title: ParentText.thisWeek.resolve(language),
            icon: Icons.calendar_today,
            tint: Colors.blue,
            child: ActivitySummaryGrid(summary: vm.week, language: language),
          ),
          const SizedBox(height: 16),
          ParentCard(
            title: ParentText.screenTime.resolve(language),
            icon: Icons.hourglass_bottom,
            tint: Colors.orange,
            footer: ParentText.screenTimeNote.resolve(language),
            child: ParentStatGrid(stats: [
              ParentStat(ParentFormat.duration(vm.today.learningTime, language), ParentText.today.resolve(language),
                  Icons.wb_sunny, Colors.orange),
              ParentStat(ParentFormat.duration(vm.week.learningTime, language), ParentText.thisWeek.resolve(language),
                  Icons.calendar_today, Colors.blue),
              if (vm.week.averageSession != null)
                ParentStat(ParentFormat.duration(vm.week.averageSession!, language),
                    ParentText.averageSession.resolve(language), Icons.timer, Colors.teal),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        ParentCard(
          title: ParentText.learningInsights.resolve(language),
          icon: Icons.lightbulb,
          tint: Colors.amber,
          footer: ParentText.insightsDisclaimer.resolve(language),
          child: vm.insights.isEmpty
              ? ParentEmptyState(icon: Icons.auto_awesome, title: ParentText.insightsEmpty.resolve(language), tint: Colors.amber)
              : Column(children: [
                  for (final insight in vm.insights)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: MergeSemantics(
                        child: Row(children: [
                          AccuracyRing(fraction: insight.rate, language: language, size: 56),
                          const SizedBox(width: 14),
                          Expanded(child: Text(insight.text(language))),
                        ]),
                      ),
                    ),
                ]),
        ),
        const SizedBox(height: 16),
        ParentCard(
          title: ParentText.overallStats.resolve(language),
          icon: Icons.emoji_events,
          tint: Colors.amber,
          child: ParentStatGrid(stats: [
            ParentStat('${vm.bestAnswerStreak}', ParentText.bestStreak.resolve(language), Icons.local_fire_department, Colors.red),
          ]),
        ),
      ]),
    );
  }

  /// One dot per day of this week; filled when something was played. No "don't break it" pressure.
  Widget _streak(BuildContext context, AppLanguage language) {
    final now = DateTime.now();
    return ParentCard(
      title: ParentText.learningStreak.resolve(language),
      icon: Icons.local_fire_department,
      tint: Colors.red,
      footer: viewModel.streakDays >= 2 ? ParentText.streakDays(viewModel.streakDays).resolve(language) : null,
      child: Row(children: [
        for (final day in viewModel.weekDays)
          Expanded(
            child: Semantics(
              label: ParentText.minutesOnDay(ParentFormat.wideWeekday(day.date, language), ParentFormat.minutes(day.learningTime))
                  .resolve(language),
              excludeSemantics: true,
              child: Column(children: [
                SizedBox(
                  height: 28,
                  child: day.gamesPlayed > 0
                      ? ShaderMask(
                          shaderCallback: (r) => const LinearGradient(
                            colors: [Colors.yellow, Colors.orange, Colors.red],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ).createShader(r),
                          child: const Icon(Icons.local_fire_department, color: Colors.white, size: 26),
                        )
                      : Icon(Icons.circle_outlined, color: secondaryText(context), size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  ParentFormat.narrowWeekday(day.date, language),
                  style: TextStyle(
                    fontSize: 11,
                    color: secondaryText(context),
                    fontWeight: DateUtils.isSameDay(day.date, now) ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}
