import 'dart:math' as math;

import 'turbo_race_content.dart';
import 'turbo_track.dart';

class TurboCar {
  TurboCar(this.progress, this.lateral);

  /// Metres driven from the start line (all laps); negative on the starting grid.
  double progress;

  /// Metres right of the road's centre.
  double lateral;
  double speed = 0;
  double lateralVelocity = 0;
  double boostTime = 0;

  /// A gentle slowdown after a wrong gate or a bump.
  double slowTime = 0;
  double? finishTime;

  // Rivals only: lane plan, cruising pace, how often they get a gate right, next gate.
  int targetLane = 1;
  double laneTimer = 0;
  double pace = 1;
  double gateSkill = 0.5;
  int nextGate = 0;
}

class TurboGate {
  TurboGate(this.progress, this.optionCount);
  final double progress;
  final int optionCount;
  bool isAnnounced = false;
  bool isPassed = false;
}

class TurboPickup {
  TurboPickup(this.progress, this.lateral);
  final double progress;
  final double lateral;
  bool isCollected = false;
}

class TurboBoostPad {
  const TurboBoostPad(this.distance, this.lateral);

  /// Distance within a lap; pads work on every lap.
  final double distance;
  final double lateral;
}

sealed class TurboEvent {
  const TurboEvent();
}

class GateAhead extends TurboEvent {
  const GateAhead(this.index);
  final int index;
}

class GatePassed extends TurboEvent {
  const GatePassed(this.index, this.choice);
  final int index, choice;
}

class StarCollected extends TurboEvent {
  const StarCollected(this.index);
  final int index;
}

class BoostPadHit extends TurboEvent {
  const BoostPadHit();
}

class LapStarted extends TurboEvent {
  const LapStarted(this.lap);
  final int lap;
}

class Bump extends TurboEvent {
  const Bump();
}

class RivalOops extends TurboEvent {
  const RivalOops(this.car);
  final int car;
}

/// The player got past this rival.
class Overtook extends TurboEvent {
  const Overtook(this.car);
  final int car;
}

/// This rival got past the player.
class OvertakenBy extends TurboEvent {
  const OvertakenBy(this.car);
  final int car;
}

/// A rival crossed the finish line, in this place.
class RivalFinished extends TurboEvent {
  const RivalFinished(this.car, this.place);
  final int car, place;
}

class RaceFinished extends TurboEvent {
  const RaceFinished(this.position);
  final int position;
}

/// The race itself: every car's distance, lane and speed, learning gates, star pickups, boost pads,
/// laps and finishing order. No drawing here; the scene only draws what this computes.
/// Car 0 is always the player.
class TurboRaceSimulation {
  TurboRaceSimulation(TurboRaceDefinition race, [math.Random? random])
      : track = TurboTrack(race.controlPoints),
        laps = race.laps,
        topSpeed = race.topSpeed,
        _random = random ?? math.Random() {
    final length = track.length;
    // Starting grid: two columns behind the line. The player starts at the back and races
    // through the field; the champion (car 1) starts on pole.
    final playerSlot = race.rivals;
    final grid = [
      for (var slot = 0; slot <= race.rivals; slot++) TurboCar(-6 - (slot ~/ 2) * 8.0, slot.isEven ? -2.8 : 2.8),
    ];
    cars = [grid[playerSlot], for (var i = 0; i < grid.length; i++) if (i != playerSlot) grid[i]];
    // The champion drives at the race's pace; the others a little slower, so they spread out.
    for (var i = 1; i < cars.length; i++) {
      final spread = (i - 1) / math.max(1, race.rivals - 1);
      cars[i].pace = race.rivalPace * (i == 1 ? 1 : rivalPaceUpper - spread * rivalPaceWidth);
      cars[i].gateSkill = i == 1 ? championGateSkill : rivalGateSkill;
      cars[i].targetLane = cars[i].lateral < 0 ? 0 : 2;
      cars[i].laneTimer = 2 + _random.nextDouble() * 3;
    }
    _rivalAhead = [for (var i = 0; i < cars.length; i++) i > 0];

    // Gates evenly through each lap, clear of the start line.
    for (var lap = 0; lap < race.laps; lap++) {
      for (var g = 0; g < race.gatesPerLap; g++) {
        final fraction = (g + 1) / (race.gatesPerLap + 1);
        gates.add(TurboGate(lap * length + fraction * length, race.gateChoices));
      }
    }
    // Stars sit between gates, in varied lanes, on every lap.
    for (var lap = 0; lap < race.laps; lap++) {
      for (var s = 0; s < race.starPickups; s++) {
        final fraction = (s + 0.55) / race.starPickups;
        pickups.add(TurboPickup(lap * length + fraction * length * 0.96, TurboTrack.laneOffsets[(s + lap) % 3]));
      }
    }
    boostPads = [
      for (var p = 0; p < race.boostPads; p++)
        TurboBoostPad((p + 0.3) / race.boostPads * length * 0.97, TurboTrack.laneOffsets[(p * 2) % 3]),
    ];
  }

  final TurboTrack track;
  final int laps;
  final double topSpeed;
  final math.Random _random;
  late final List<TurboCar> cars;
  final List<TurboGate> gates = [];
  final List<TurboPickup> pickups = [];
  late final List<TurboBoostPad> boostPads;

  bool isRunning = false;
  double elapsed = 0;
  double boostMeter = 0;
  int boostsUsed = 0;
  final List<double> lapTimes = [];
  int? finishPosition;
  double _lapStartTime = 0;
  int _currentLap = 1;
  double _bumpCooldown = 0;
  late List<bool> _rivalAhead;
  int _finishedRivals = 0;

  /// Distance before a gate at which ChihChi asks the question.
  static const announceDistance = 120.0;
  static const fullBoost = 3.0;
  static const miniBoost = 1.3;

  /// A correct learning gate is worth a little more to the player: learning is how you win.
  static const gateBoost = 1.8;
  static const wrongGateSlowdown = 1.8;

  /// Cars must be this far apart along the road before a pass counts.
  static const overtakeMargin = 1.5;
  static const rivalPaceUpper = 0.985, rivalPaceWidth = 0.06;
  static const championGateSkill = 0.6, rivalGateSkill = 0.45;
  static const maxCornerSlowdown = 0.12;
  static const acceleration = 7.0, coastDeceleration = 5.0;
  static const slipstreamBonus = 1.06;

  void start() => isRunning = true;
  void pause() => isRunning = false;

  TurboCar get player => cars[0];
  double get raceLength => laps * track.length;

  /// 1-based race position of the player right now.
  int get playerPosition => finishPosition ?? 1 + cars.skip(1).where((c) => c.progress > cars[0].progress).length;

  int get playerLap => math.min(laps, math.max(1, _currentLap));
  double? get bestLap => lapTimes.isEmpty ? null : lapTimes.reduce(math.min);
  int get collectedStars => pickups.where((p) => p.isCollected).length;

  /// Lateral positions of a gate's choices, left to right.
  static List<double> optionOffsets(int count) => count >= 3 ? TurboTrack.laneOffsets : const [-3.2, 3.2];

  /// A correct gate gives a short boost and fills a third of the meter; a wrong one a gentle slowdown.
  void applyGateResult(bool correct) {
    if (correct) {
      cars[0].boostTime = math.max(cars[0].boostTime, gateBoost);
      boostMeter = math.min(1, boostMeter + 0.34);
    } else {
      cars[0].slowTime = math.max(cars[0].slowTime, wrongGateSlowdown);
    }
  }

  /// Every car in race order: finished cars by finishing time, then the rest by distance.
  List<int> get standings {
    final order = [for (var i = 0; i < cars.length; i++) i];
    order.sort((a, b) {
      final ta = cars[a].finishTime, tb = cars[b].finishTime;
      if (ta != null && tb != null) return ta.compareTo(tb);
      if (ta != null) return -1;
      if (tb != null) return 1;
      return cars[b].progress.compareTo(cars[a].progress);
    });
    return order;
  }

  /// The car just ahead in the same lane, within `range` metres, if any.
  int? carAhead(int index, double range) {
    final car = cars[index];
    int? best;
    for (var o = 0; o < cars.length; o++) {
      if (o == index) continue;
      final gap = cars[o].progress - car.progress;
      if (gap > 0 && gap < range && (cars[o].lateral - car.lateral).abs() < 2.2) {
        if (best == null || cars[o].progress < cars[best].progress) best = o;
      }
    }
    return best;
  }

  /// Corner speed factor: every car slows a little on tight bends.
  double cornerFactor(double progress) => 1 - math.min(maxCornerSlowdown, track.curvature(progress).abs() * 7);

  /// Uses a full boost meter. Returns false if it is not full yet.
  bool fireBoost() {
    if (!isRunning || boostMeter < 0.99) return false;
    boostMeter = 0;
    boostsUsed += 1;
    cars[0].boostTime = math.max(cars[0].boostTime, fullBoost);
    return true;
  }

  /// Advances the race by `dt` seconds. `steer` is −1 (left) … 1 (right); `throttle` is true while
  /// the child holds the screen (the car only drives while held).
  List<TurboEvent> step(double dt, double steer, bool throttle) {
    if (!isRunning || dt <= 0) return const [];
    dt = math.min(dt, 1 / 20);
    elapsed += dt;
    _bumpCooldown = math.max(0, _bumpCooldown - dt);
    final events = <TurboEvent>[];
    final previous = [for (final c in cars) track.wrap(c.progress)];
    _stepPlayer(dt, steer, throttle);
    for (var i = 1; i < cars.length; i++) {
      _stepRival(i, dt, events);
    }
    _resolveContacts(events);
    _checkGates(events);
    _checkPickups(events);
    _checkBoostPads(previous, events);
    _checkOvertakes(events);
    _checkLapsAndFinish(events);
    return events;
  }

  void _stepPlayer(double dt, double steer, bool throttle) {
    final car = cars[0];
    const limit = TurboTrack.halfWidth + 1.0;
    final offRoad = car.lateral.abs() > TurboTrack.halfWidth - 0.6;
    var top = topSpeed * cornerFactor(car.progress);
    if (car.boostTime > 0) top *= 1.4;
    if (car.slowTime > 0) top *= 0.7;
    final ahead = carAhead(0, 12);
    if (ahead != null) top *= slipstreamBonus;
    if (offRoad) top *= 0.65;
    if (throttle || car.boostTime > 0) {
      final accel = car.boostTime > 0 ? 14.0 : acceleration;
      car.speed = car.speed < top ? math.min(top, car.speed + accel * dt) : math.max(top, car.speed - 10 * dt);
    } else {
      // Finger lifted: roll to a stop.
      car.speed = math.max(0, math.min(car.speed, top) - coastDeceleration * dt);
    }

    // Steering with a little momentum.
    final desired = steer.clamp(-1.0, 1.0) * 11;
    car.lateralVelocity += (desired - car.lateralVelocity) * math.min(1, dt * 9);
    car.lateral += car.lateralVelocity * dt;

    // Holding without steering near a gate: ease into the nearest choice so small children still
    // get through one. Never while idle.
    final gate = gates.where((g) => !g.isPassed).firstOrNull;
    if (throttle && steer.abs() < 0.1 && gate != null && gate.progress - car.progress < 30 && gate.progress > car.progress) {
      final slots = optionOffsets(gate.optionCount);
      final nearest = slots.reduce((a, b) => (a - car.lateral).abs() < (b - car.lateral).abs() ? a : b);
      car.lateral += (nearest - car.lateral) * math.min(1, dt * 1.5);
    }

    // Holding without steering hard right behind a car: ease into the open lane beside it.
    if (throttle && steer.abs() < 0.5 && ahead != null && cars[ahead].progress - car.progress < 9) {
      final blocker = cars[ahead].lateral;
      final open = TurboTrack.laneOffsets.where((lane) {
        if ((lane - blocker).abs() <= 2.5) return false;
        for (var o = 1; o < cars.length; o++) {
          if ((cars[o].progress - car.progress).abs() < 9 && (cars[o].lateral - lane).abs() < 2) return false;
        }
        return true;
      }).toList();
      if (open.isNotEmpty) {
        final target = open.reduce((a, b) => (a - car.lateral).abs() < (b - car.lateral).abs() ? a : b);
        car.lateral += (target - car.lateral) * math.min(1, dt * 2.2);
      }
    }

    // Soft walls at the road's edges.
    if (car.lateral.abs() > limit) {
      car.lateral = car.lateral > 0 ? limit : -limit;
      car.lateralVelocity = 0;
      car.speed *= 1 - 0.3 * dt;
    }
    car.progress += car.speed * dt;
    car.boostTime = math.max(0, car.boostTime - dt);
    car.slowTime = math.max(0, car.slowTime - dt);
  }

  void _stepRival(int index, double dt, List<TurboEvent> events) {
    final car = cars[index];
    final player = cars[0];

    // Pick a new lane now and then, or to get round a car just ahead.
    car.laneTimer -= dt;
    var blocked = false;
    for (var o = 0; o < cars.length; o++) {
      if (o == index) continue;
      final gap = cars[o].progress - car.progress;
      if (gap > 0 && gap < 10 && (cars[o].lateral - TurboTrack.laneOffsets[car.targetLane]).abs() < 2) {
        blocked = true;
        break;
      }
    }
    if (car.laneTimer <= 0 || blocked) {
      car.targetLane = blocked ? (car.targetLane == 1 ? (_random.nextDouble() < 0.5 ? 0 : 2) : 1) : _random.nextInt(3);
      car.laneTimer = 2 + _random.nextDouble() * 3;
    }
    final targetLateral = TurboTrack.laneOffsets[car.targetLane];
    car.lateral += (targetLateral - car.lateral) * math.min(1, dt * 1.2);

    // A small, even-handed pull towards the player keeps the pack in sight.
    final gap = car.progress - player.progress;
    final band = gap > 60 ? 0.94 : gap > 30 ? 0.97 : gap < -50 ? 1.12 : gap < -30 ? 1.06 : 1.0;
    var cruise = topSpeed * car.pace * band * cornerFactor(car.progress);
    if (car.boostTime > 0) cruise *= 1.4;
    if (carAhead(index, 12) != null) cruise *= slipstreamBonus;
    if (car.slowTime > 0) cruise *= 0.7;
    final accel = car.boostTime > 0 ? 14.0 : 6.0;
    car.speed = car.speed < cruise ? math.min(cruise, car.speed + accel * dt) : math.max(cruise, car.speed - 8 * dt);

    // Rivals answer the learning gates too: right gives a boost, wrong a slowdown.
    if (car.nextGate < gates.length && car.progress >= gates[car.nextGate].progress) {
      car.nextGate += 1;
      if (_random.nextDouble() < car.gateSkill) {
        car.boostTime = math.max(car.boostTime, miniBoost);
      } else {
        car.slowTime = math.max(car.slowTime, wrongGateSlowdown);
      }
    }

    // A rare, funny slip ("Oops!") once the race is going.
    if (elapsed > 8 && car.finishTime == null && _random.nextDouble() < dt * 0.012) {
      car.slowTime = 1.2;
      events.add(RivalOops(index));
    }
    car.slowTime = math.max(0, car.slowTime - dt);
    car.boostTime = math.max(0, car.boostTime - dt);
    car.progress += car.speed * dt;
    if (car.finishTime == null && car.progress >= raceLength) {
      car.finishTime = elapsed;
      _finishedRivals += 1;
      events.add(RivalFinished(index, _finishedRivals + (cars[0].finishTime == null ? 0 : 1)));
    }
  }

  /// Cars that touch are pushed gently apart; the one behind can't drive through the one ahead.
  void _resolveContacts(List<TurboEvent> events) {
    for (var a = 0; a < cars.length; a++) {
      for (var b = a + 1; b < cars.length; b++) {
        final dp = cars[b].progress - cars[a].progress;
        final dl = cars[b].lateral - cars[a].lateral;
        if (dp.abs() >= 3.6 || dl.abs() >= 2.0) continue;
        final push = (2.0 - dl.abs()) / 2;
        final side = dl >= 0 ? 1.0 : -1.0;
        cars[b].lateral += side * push;
        cars[a].lateral -= side * push;
        final behind = dp >= 0 ? a : b;
        final ahead = dp >= 0 ? b : a;
        cars[behind].speed = math.min(cars[behind].speed, math.max(0, cars[ahead].speed - 0.5));
        // Cars jostle leaving the grid; only react to bumps once the race is under way.
        if (a == 0 && _bumpCooldown == 0 && elapsed > 4) {
          _bumpCooldown = 1.5;
          events.add(const Bump());
        }
      }
    }
  }

  void _checkGates(List<TurboEvent> events) {
    final progress = cars[0].progress;
    for (var i = 0; i < gates.length; i++) {
      final gate = gates[i];
      if (gate.isPassed) continue;
      if (!gate.isAnnounced && progress >= gate.progress - announceDistance) {
        gate.isAnnounced = true;
        events.add(GateAhead(i));
      }
      if (progress >= gate.progress) {
        gate.isPassed = true;
        final slots = optionOffsets(gate.optionCount);
        final lateral = cars[0].lateral;
        var choice = 0;
        for (var s = 1; s < slots.length; s++) {
          if ((slots[s] - lateral).abs() < (slots[choice] - lateral).abs()) choice = s;
        }
        events.add(GatePassed(i, choice));
      }
    }
  }

  void _checkPickups(List<TurboEvent> events) {
    final car = cars[0];
    for (var i = 0; i < pickups.length; i++) {
      final p = pickups[i];
      if (!p.isCollected && (p.progress - car.progress).abs() < 2.5 && (p.lateral - car.lateral).abs() < 2.4) {
        p.isCollected = true;
        events.add(StarCollected(i));
      }
    }
  }

  /// Boost pads work for every car driving over them.
  void _checkBoostPads(List<double> previous, List<TurboEvent> events) {
    for (var i = 0; i < cars.length; i++) {
      final car = cars[i];
      final current = track.wrap(car.progress);
      if (car.progress <= 0 || current < previous[i]) continue; // skip the frame that wraps a lap
      for (final pad in boostPads) {
        if (pad.distance > previous[i] && pad.distance <= current && (pad.lateral - car.lateral).abs() < 2.4) {
          car.boostTime = math.max(car.boostTime, miniBoost);
          if (i == 0) events.add(const BoostPadHit());
        }
      }
    }
  }

  /// Passing a rival, or being passed, once the grid has spread out.
  void _checkOvertakes(List<TurboEvent> events) {
    if (cars[0].finishTime != null) return;
    final player = cars[0].progress;
    for (var i = 1; i < cars.length; i++) {
      if (cars[i].finishTime != null) continue;
      final gap = cars[i].progress - player;
      if (_rivalAhead[i] && gap < -overtakeMargin) {
        _rivalAhead[i] = false;
        if (elapsed > 2) events.add(Overtook(i));
      } else if (!_rivalAhead[i] && gap > overtakeMargin) {
        _rivalAhead[i] = true;
        if (elapsed > 2) events.add(OvertakenBy(i));
      }
    }
  }

  void _checkLapsAndFinish(List<TurboEvent> events) {
    final progress = cars[0].progress;
    if (progress >= raceLength) {
      lapTimes.add(elapsed - _lapStartTime);
      cars[0].finishTime = elapsed;
      final ahead = cars.skip(1).where((c) => c.finishTime != null).length;
      finishPosition = 1 + ahead;
      isRunning = false;
      events.add(RaceFinished(1 + ahead));
      return;
    }
    final lap = math.max(0, progress) ~/ track.length + 1;
    if (lap > _currentLap) {
      lapTimes.add(elapsed - _lapStartTime);
      _lapStartTime = elapsed;
      _currentLap = lap;
      events.add(LapStarted(lap));
    }
  }
}
