import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/ui/palette.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/home_game.dart';
import '../home/home_game_text.dart';
import 'parent_statistics.dart';
import 'parent_text.dart';

// Colourful, picture-first building blocks shared by the Parent Zone screens. Text uses the
// system's text sizes and the card colours follow the light or dark theme.

class ParentFormat {
  /// The intl locale for a language, falling back to English when intl has no data for it.
  static String locale(AppLanguage language) {
    final code = language.code;
    return DateFormat.localeExists(code) ? code : 'en';
  }

  static String duration(double seconds, AppLanguage language) {
    if (seconds < 60) return ParentText.lessThanMinute.resolve(language);
    final minutes = seconds ~/ 60;
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    final number = NumberFormat.decimalPattern(locale(language));
    if (hours == 0) return '${number.format(rest)} min';
    return rest == 0 ? '${number.format(hours)} h' : '${number.format(hours)} h ${number.format(rest)} min';
  }

  static int percent(double fraction) => (fraction * 100).round();

  static String accuracy(double? fraction, AppLanguage language) =>
      fraction == null ? ParentText.noDataYet.resolve(language) : '${percent(fraction)}%';

  static int minutes(double seconds) => (seconds / 60).round();

  static String date(DateTime date, AppLanguage language) => DateFormat.yMMMMd(locale(language)).format(date);
  static String shortWeekday(DateTime date, AppLanguage language) => DateFormat.E(locale(language)).format(date);
  static String narrowWeekday(DateTime date, AppLanguage language) => DateFormat.E(locale(language)).format(date).characters.first;
  static String wideWeekday(DateTime date, AppLanguage language) => DateFormat.EEEE(locale(language)).format(date);

  /// "Today 4:30 PM", "Yesterday", or a short date.
  static String relative(DateTime date, AppLanguage language, DateTime now) {
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final loc = locale(language);
    if (day == today) return '${ParentText.today.resolve(language)} ${DateFormat.jm(loc).format(date)}';
    if (today.difference(day).inDays < 7) return '${DateFormat.EEEE(loc).format(date)} ${DateFormat.jm(loc).format(date)}';
    return DateFormat.MMMd(loc).format(date);
  }

  /// 1 (Monday) … 7 (Sunday) for the language's calendar.
  static int firstWeekday(AppLanguage language) {
    final symbols = DateFormat.yMd(locale(language)).dateSymbols;
    return symbols.FIRSTDAYOFWEEK + 1;
  }
}

/// Each game keeps the colours of its Home tile, so parents recognise it in every chart.
extension HomeGameTint on HomeGame {
  Color get tint => colors.last;
  LinearGradient get gradient => LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight);
}

class ParentPalette {
  static const time = Colors.orange;
  static const games = Colors.blue;
  static const levels = Colors.green;
  static const questions = Colors.purple;
  static const accuracy = Colors.pink;
  static const stars = Colors.amber;
  static final hero = LinearGradient(
    colors: [rgb(0.45, 0.36, 0.95), rgb(0.2, 0.62, 0.95)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// The grey page behind the Parent Zone cards.
Color parentBackground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? Colors.black : const Color(0xFFF2F2F7);

Color parentCardColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white;

Color secondaryText(BuildContext context) => Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

/// Rounded card with a coloured icon title, used for every dashboard section.
class ParentCard extends StatelessWidget {
  const ParentCard({super.key, required this.title, required this.icon, required this.tint, this.footer, required this.child});
  final String title;
  final IconData icon;
  final Color tint;
  final String? footer;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: parentCardColor(context), borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(
          header: true,
          child: Row(children: [
            ParentIconBadge(icon: icon, tint: tint),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
          ]),
        ),
        const SizedBox(height: 14),
        child,
        if (footer != null) ...[
          const SizedBox(height: 14),
          Text(footer!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: secondaryText(context))),
        ],
      ]),
    );
  }
}

/// A white icon on a filled coloured circle.
class ParentIconBadge extends StatelessWidget {
  const ParentIconBadge({super.key, required this.icon, required this.tint, this.size = 30});
  final IconData icon;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
                colors: [Color.lerp(tint, Colors.white, 0.25)!, tint], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          ),
          child: Icon(icon, size: size * 0.5, color: Colors.white),
        ),
      );
}

/// A game's emoji on its own colourful gradient.
class GameBadge extends StatelessWidget {
  const GameBadge({super.key, required this.game, this.size = 44});
  final HomeGame game;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(gradient: game.gradient, borderRadius: BorderRadius.circular(size * 0.3)),
          child: Text(game.icon, style: TextStyle(fontSize: size * 0.5)),
        ),
      );
}

class ParentStat {
  const ParentStat(this.value, this.title, this.icon, this.tint);
  final String value;
  final String title;
  final IconData icon;
  final Color tint;
}

class ParentStatTile extends StatelessWidget {
  const ParentStatTile({super.key, required this.stat});
  final ParentStat stat;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${stat.title}, ${stat.value}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: stat.tint.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          ParentIconBadge(icon: stat.icon, tint: stat.tint, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(stat.value,
                    maxLines: 1, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ),
              Text(stat.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: secondaryText(context))),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Two-column grid of tiles that becomes one column at large text sizes.
class ParentStatGrid extends StatelessWidget {
  const ParentStatGrid({super.key, required this.stats});
  final List<ParentStat> stats;

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    final columns = large ? 1 : 2;
    final rows = <Widget>[];
    for (var i = 0; i < stats.length; i += columns) {
      rows.add(Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var c = 0; c < columns; c++) ...[
              if (c > 0) const SizedBox(width: 10),
              Expanded(child: i + c < stats.length ? ParentStatTile(stat: stats[i + c]) : const SizedBox()),
            ],
          ]),
        ),
      ));
    }
    return Column(children: rows);
  }
}

/// Circular progress in a game's colours with any content in the middle.
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.progress, required this.colors, this.lineWidth = 8, required this.center});
  final double progress;
  final List<Color> colors;
  final double lineWidth;
  final Widget center;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1);
    return CustomPaint(
      painter: _RingPainter(progress.clamp(0.001, 1).toDouble(), colors, lineWidth, track),
      child: Center(child: center),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.colors, this.lineWidth, this.track);
  final double progress;
  final List<Color> colors;
  final double lineWidth;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(lineWidth / 2, lineWidth / 2, size.width - lineWidth, size.height - lineWidth);
    canvas.drawArc(rect, 0, 2 * math.pi, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = lineWidth
          ..color = track);
    canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = lineWidth
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            colors: [...colors, colors.first],
            transform: const GradientRotation(-math.pi / 2),
          ).createShader(rect));
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.colors != colors;
}

/// Accuracy as a coloured ring: green when strong, orange in the middle, pink when lower.
class AccuracyRing extends StatelessWidget {
  const AccuracyRing({super.key, required this.fraction, required this.language, this.size = 64});
  final double? fraction;
  final AppLanguage language;
  final double size;

  List<Color> get _colors {
    final f = fraction;
    if (f == null) return [Colors.grey, Colors.grey];
    if (f >= 0.8) return [Colors.tealAccent.shade400, Colors.green];
    if (f >= 0.6) return [Colors.amber, Colors.orange];
    return [Colors.orange, Colors.pink];
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: ParentText.accuracy.resolve(language),
      value: ParentFormat.accuracy(fraction, language),
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: ProgressRing(
          progress: fraction ?? 0,
          colors: _colors,
          lineWidth: size * 0.12,
          center: FittedBox(
            child: Text(fraction == null ? '–' : '${ParentFormat.percent(fraction!)}%',
                style: TextStyle(fontSize: size * 0.24, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}

/// Donut chart of play time per game, with a colour legend.
class TimeByGameChart extends StatelessWidget {
  const TimeByGameChart({super.key, required this.items, required this.language});
  final List<GameTime> items;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (a, i) => a + i.time);
    final chart = SizedBox(
      width: 150,
      height: 150,
      child: Stack(alignment: Alignment.center, children: [
        PieChart(PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 46,
          startDegreeOffset: -90,
          sections: [
            for (final item in items)
              PieChartSectionData(value: item.time, color: item.game.tint, radius: 26, showTitle: false),
          ],
        )),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FittedBox(
                child: Text(ParentFormat.duration(total, language),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold))),
            Text(ParentText.learningTime.resolve(language),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: secondaryText(context))),
          ]),
        ),
      ]),
    );
    final legend = Column(children: [
      for (final item in items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Semantics(
            label: '${item.game.title(language)}, ${ParentFormat.duration(item.time, language)}',
            excludeSemantics: true,
            child: Row(children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, gradient: item.game.gradient)),
              const SizedBox(width: 8),
              Expanded(child: Text(item.game.title(language), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text(ParentFormat.duration(item.time, language),
                  style: TextStyle(fontWeight: FontWeight.w600, color: secondaryText(context))),
            ]),
          ),
        ),
    ]);
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth > 360
          ? Row(children: [chart, const SizedBox(width: 18), Expanded(child: legend)])
          : Column(children: [chart, const SizedBox(height: 14), legend]),
    );
  }
}

/// Minutes per day, each bar split into the games played, in the games' colours.
class WeeklyMinutesChart extends StatelessWidget {
  const WeeklyMinutesChart({super.key, required this.days, required this.language, this.compact = false, this.singleColor});
  final List<DayActivity> days;
  final AppLanguage language;
  final bool compact;

  /// Draw every bar in one gradient (one game's detail page) instead of stacking games.
  final LinearGradient? singleColor;

  @override
  Widget build(BuildContext context) {
    final longest = days.map((d) => d.learningTime / 60).fold<double>(0, math.max);
    final maxY = math.max(5, longest.ceilToDouble()).toDouble();
    final played = HomeGame.values.where((g) => days.any((d) => d.timeByGame.containsKey(g))).toList();
    final secondary = secondaryText(context);
    final chart = SizedBox(
      height: compact ? 130 : 210,
      child: BarChart(BarChartData(
        maxY: maxY,
        minY: 0,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(drawVerticalLine: false, horizontalInterval: math.max(1, (maxY / 4).ceilToDouble())),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: math.max(1, (maxY / 4).ceilToDouble()),
              getTitlesWidget: (value, meta) =>
                  Text('${value.toInt()}m', style: TextStyle(fontSize: 10, color: secondary)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= days.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(ParentFormat.shortWeekday(days[i].date, language),
                      style: TextStyle(fontSize: 10, color: secondary)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(x: i, barRods: [
              () {
                final total = days[i].learningTime / 60;
                if (singleColor != null) {
                  return BarChartRodData(
                    toY: total,
                    width: compact ? 14 : 20,
                    gradient: singleColor,
                    borderRadius: BorderRadius.circular(5),
                  );
                }
                var from = 0.0;
                final stack = <BarChartRodStackItem>[];
                for (final game in played) {
                  final minutes = (days[i].timeByGame[game] ?? 0) / 60;
                  if (minutes <= 0) continue;
                  stack.add(BarChartRodStackItem(from, from + minutes, game.tint));
                  from += minutes;
                }
                return BarChartRodData(
                  toY: from,
                  width: compact ? 14 : 20,
                  rodStackItems: stack,
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                );
              }(),
            ]),
        ],
      )),
    );
    final semantics = [
      for (final d in days)
        ParentText.minutesOnDay(ParentFormat.wideWeekday(d.date, language), ParentFormat.minutes(d.learningTime))
            .resolve(language),
    ].join('. ');
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        chart,
        if (!compact && singleColor == null && played.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 6, children: [
            for (final g in played)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: g.tint, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(g.title(language), style: Theme.of(context).textTheme.bodySmall),
              ]),
          ]),
        ],
      ]),
    );
  }
}

/// Filled and empty stars, e.g. ★★☆ for 2 of 3.
class ParentStarsView extends StatelessWidget {
  const ParentStarsView({super.key, required this.stars, this.maximum = 3, required this.language});
  final int stars;
  final int maximum;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Semantics(
        label: ParentText.starCount(stars).resolve(language),
        excludeSemantics: true,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < maximum; i++)
            Icon(i < stars ? Icons.star : Icons.star_border, size: 14, color: i < stars ? Colors.amber : secondaryText(context)),
        ]),
      );
}

class ParentEmptyState extends StatelessWidget {
  const ParentEmptyState({super.key, required this.icon, required this.title, this.message, this.tint = Colors.grey});
  final IconData icon;
  final String title;
  final String? message;
  final Color tint;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 36, color: tint),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: secondaryText(context))),
            ],
          ]),
        ),
      );
}

/// Game name with its icon, for lists.
class ParentGameLabel extends StatelessWidget {
  const ParentGameLabel({super.key, required this.game, required this.language});
  final HomeGame game;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Row(children: [
        GameBadge(game: game, size: 28),
        const SizedBox(width: 12),
        Expanded(child: Text(game.title(language))),
      ]);
}

/// A grouped list section in the iOS "inset grouped" style: optional header, rows, footer.
class ParentSection extends StatelessWidget {
  const ParentSection({super.key, this.header, this.footer, required this.children});
  final String? header;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final secondary = secondaryText(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(header!.toUpperCase(), style: TextStyle(fontSize: 13, color: secondary)),
          ),
        Container(
          decoration: BoxDecoration(color: parentCardColor(context), borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 16),
              children[i],
            ],
          ]),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(footer!, style: TextStyle(fontSize: 13, color: secondary)),
          ),
      ]),
    );
  }
}

/// A standard Parent Zone page: grey background and an app bar.
class ParentPage extends StatelessWidget {
  const ParentPage({super.key, required this.title, required this.children, this.actions, this.leading});
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: parentBackground(context),
        appBar: AppBar(
          title: Text(title),
          backgroundColor: parentBackground(context),
          scrolledUnderElevation: 0,
          actions: actions,
          leading: leading,
        ),
        body: ListView(padding: const EdgeInsets.only(top: 12, bottom: 30), children: children),
      );
}
