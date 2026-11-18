/// Which teaching aid (Arbeitsmittel) the tutor uses for a question, and how
/// far the child has already moved away from it.
///
/// The rules follow German primary-school didactics (PIKAS, Mahiko, DZLM;
/// see goabacus/methodik.md in the project files):
/// - few aids, each for what it shows best ("weniger ist mehr");
/// - up to 10 and 20: Fingerbilder and the Zwanzigerfeld with Wendeplättchen
///   (Kraft der Fünf, Zehnerstopp); coloured rods for Zerlegen / Ergänzen
///   and 10 + 3 under the orange rod;
/// - up to 100: the abacus, ten by ten (ZE ± E up to the full ten, ZE ± Z on
///   the tens wire, "by steps" for the rest);
/// - times table and division (with remainder): the Hunderterpunktefeld with
///   the Malwinkel ("3 rows of 7"), Kernaufgaben 1, 2, 5, 10 and squares,
///   others derived from them;
/// - the Einspluseins / Einmaleins tables only for checking known facts;
/// - Ablösung vom Material in four phases (Wartha & Schulz): act with the
///   aid, describe it while looking, imagine it without looking, then
///   symbols only, the aid just for checking.
library;

import 'dart:math' as math;

import 'task.dart';

/// The teaching aids of the kit (and the screen abacus).
enum Aid {
  /// Fingerbilder: 7 = one full hand and 2.
  fingers,

  /// Zwanzigerfeld (2 × 10, split 5 | 5) with red/blue Wendeplättchen.
  twentyField,

  /// Coloured rods 1–10 (no "Cuisenaire" name).
  rods,

  /// The abacus: on screen always, a real one when the family has it.
  abacus,

  /// The 10 × 10 dot field with the Malwinkel (film sheet 13).
  hundredField,

  /// The Einspluseins table 0–10 (film sheet 10), to check a known fact.
  additionTable,

  /// The Einmaleins table 1–10 (film sheet 12), to check a known fact.
  timesTable;

  /// Aids that exist only as things on the desk (the abacus is also on
  /// the screen, fingers are always there).
  bool get physical => this != abacus && this != fingers;

  static Aid? byName(String s) {
    for (final a in values) {
      if (a.name == s) return a;
    }
    return null;
  }
}

/// What a question is about, the unit the tutor tracks progress in.
enum Skill {
  /// Up to 10: 3 + 4, 9 − 5.
  within10,

  /// Ergänzen and Zerlegen: 7 + ? = 10, 9 + ? = 15.
  missing,

  /// Up to 20 without crossing ten: 12 + 5, 17 − 3.
  within20,

  /// Crossing ten up to 20: 8 + 5, 13 − 5.
  bridge20,

  /// Doubles and near doubles up to 20: 6 + 6, 7 + 8.
  doubles,

  /// Up to 100, ones up to the full ten: 34 + 5, 47 − 6.
  plusOnes100,

  /// Up to 100, whole tens: 34 + 20, 70 − 30.
  plusTens100,

  /// Up to 100, crossing a ten: 57 + 28, 38 + 7.
  bridge100,

  /// The times table: Kernaufgaben (× 1, 2, 5, 10 and squares).
  timesCore,

  /// The times table: the other tasks, derived from a core task.
  timesDerived,

  /// Division without remainder (the Umkehraufgabe of a times task).
  division,

  /// Division with remainder: 17 : 5 = 3 R 2.
  divisionRest,

  /// Anything bigger.
  big,
}

/// The four phases of moving away from the aid.
enum Stage {
  /// Act with the aid and say what you do.
  act,

  /// Look at the aid (on the screen or the desk) without touching, and say.
  look,

  /// Imagine the aid with eyes closed: the screen hides it.
  imagine,

  /// Symbols only; the aid is there to check afterwards.
  symbolic,
}

bool _crossesTen(Question q) {
  final a = q.unknown == Slot.a ? q.result : q.a;
  final b = q.b;
  return switch (q.op) {
    Op.add => a % 10 + b % 10 >= 10,
    Op.sub => a % 10 < b % 10,
    _ => false,
  };
}

bool isCoreTimes(int a, int b) =>
    a == b || {1, 2, 5, 10}.contains(a) || {1, 2, 5, 10}.contains(b);

Skill skillOf(Question q) {
  final top = math.max(q.a, math.max(q.b, q.result));
  switch (q.op) {
    case Op.mul:
      if (q.a > 10 || q.b > 10) return Skill.big;
      return isCoreTimes(q.a, q.b) ? Skill.timesCore : Skill.timesDerived;
    case Op.div:
      if (q.a > 100) return Skill.big;
      return q.a % math.max(1, q.b) == 0 ? Skill.division : Skill.divisionRest;
    case Op.add:
    case Op.sub:
      if (top > 100) return Skill.big;
      if (q.unknown != Slot.result && top <= 20) return Skill.missing;
      if (top <= 10) return Skill.within10;
      if (top <= 20) {
        if (q.op == Op.add && (q.a - q.b).abs() <= 1 && q.a >= 5) {
          return Skill.doubles;
        }
        return _crossesTen(q) ? Skill.bridge20 : Skill.within20;
      }
      if (_crossesTen(q)) return Skill.bridge100;
      if (q.b % 10 == 0) return Skill.plusTens100;
      if (q.b < 10) return Skill.plusOnes100;
      return Skill.bridge100;
  }
}

/// The aids for each skill, best first, as German schools use them. For a
/// Russian-school child the abacus comes first where it can show the task.
List<Aid> aidsFor(Skill s, {String school = 'de', int grade = 1}) {
  final ru = school == 'ru';
  return switch (s) {
    Skill.within10 => grade <= 1
        ? [Aid.fingers, Aid.twentyField, Aid.rods, Aid.abacus]
        : [Aid.twentyField, Aid.abacus, Aid.fingers],
    Skill.missing => [Aid.rods, Aid.twentyField, Aid.fingers, Aid.abacus],
    Skill.within20 => [Aid.twentyField, Aid.abacus, Aid.rods],
    Skill.bridge20 => ru
        ? [Aid.abacus, Aid.twentyField, Aid.rods]
        : [Aid.twentyField, Aid.rods, Aid.abacus],
    Skill.doubles => [Aid.twentyField, Aid.fingers, Aid.abacus],
    Skill.plusOnes100 || Skill.plusTens100 || Skill.bridge100 => [
      Aid.abacus,
    ],
    Skill.timesCore || Skill.timesDerived => [
      Aid.hundredField,
      Aid.rods,
      Aid.abacus,
    ],
    Skill.division => [Aid.hundredField, Aid.twentyField, Aid.abacus],
    Skill.divisionRest => [Aid.hundredField, Aid.twentyField, Aid.rods],
    Skill.big => [Aid.abacus],
  };
}

/// The table that checks a known fact in the symbolic phase, if any.
Aid? checkTableFor(Question q) {
  if (q.op == Op.mul || q.op == Op.div) {
    return q.op == Op.mul && q.a <= 10 && q.b <= 10 ? Aid.timesTable : null;
  }
  if (q.op == Op.add && q.a <= 10 && q.b <= 10) return Aid.additionTable;
  return null;
}

/// How a question will be worked.
class AidChoice {
  const AidChoice(this.aid, this.stage, this.skill);
  final Aid aid;
  final Stage stage;
  final Skill skill;

  @override
  String toString() => '${skill.name}: ${aid.name}/${stage.name}';
}

/// The stage for a skill from the child's streak of answers right at the
/// first try without hints. Two in a row move one phase on; a mistake
/// moves back (see [Progress.record]).
Stage stageFor(int streak) => switch (streak) {
  < 2 => Stage.act,
  < 4 => Stage.look,
  < 6 => Stage.imagine,
  _ => Stage.symbolic,
};

/// Picks the aid and the stage for [q].
///
/// [available]: the aids the family has on the desk (the screen abacus
/// and fingers always count). [avoid]: aids that did not help with this
/// question (the tutor changes the aid instead of repeating it).
/// [lastMistake]: a lost ten sends the child to the abacus, where tens are
/// wires; a counting slip up to 20 to the Zwanzigerfeld, where the five is
/// seen at once.
AidChoice chooseAid(
  Question q, {
  Set<Aid> available = const {Aid.abacus, Aid.fingers},
  String school = 'de',
  int grade = 1,
  int streak = 0,
  Set<Aid> avoid = const {},
  Mistake? lastMistake,
}) {
  final skill = skillOf(q);
  final have = {...available, Aid.abacus, Aid.fingers};
  var order = aidsFor(skill, school: school, grade: grade);
  if (lastMistake == Mistake.placeValue) {
    order = [Aid.abacus, ...order.where((a) => a != Aid.abacus)];
  } else if (lastMistake == Mistake.offByOne &&
      math.max(q.a, q.result) <= 20 &&
      q.op != Op.mul) {
    order = [Aid.twentyField, ...order.where((a) => a != Aid.twentyField)];
  }
  final usable = order.where((a) => have.contains(a)).toList();
  final fresh = usable.where((a) => !avoid.contains(a)).toList();
  final aid = fresh.isNotEmpty
      ? fresh.first
      : usable.isNotEmpty
      ? usable.first
      : Aid.abacus;
  // Fingers only up to 10.
  final fits = aid == Aid.fingers && math.max(q.a, q.result) > 10
      ? Aid.abacus
      : aid;
  return AidChoice(fits, stageFor(streak), skill);
}

/// The way a times task is derived from a Kernaufgabe, for the hint:
/// 6 · 7 = 5 · 7 + 1 · 7, 9 · 7 = 10 · 7 − 1 · 7, 4 · 7 = 2 · 7 + 2 · 7.
/// Null for a core task.
({int core, int rest, bool minus})? deriveTimes(int a, int b) {
  if (isCoreTimes(a, b)) return null;
  // Derive along the first factor (the number of rows).
  if (a == 9) return (core: 10, rest: 1, minus: true);
  if (a == 4) return (core: 2, rest: 2, minus: false);
  if (a == 3) return (core: 2, rest: 1, minus: false);
  if (a == 8) return (core: 10, rest: 2, minus: true);
  return (core: 5, rest: a - 5, minus: false); // 6, 7
}

/// The child's progress per skill, kept on the child's device.
class Progress {
  Progress([Map<String, int>? streaks]) : streaks = {...?streaks};

  /// Right-first-try streak per skill name.
  final Map<String, int> streaks;

  int streak(Skill s) => streaks[s.name] ?? 0;

  /// One question done: right at the first try without hints moves on. A
  /// mistake goes back to acting with the aid, or, for a child who was
  /// already imagining it, back to looking at it: one slip does not undo
  /// weeks of work.
  void record(Skill s, {required bool clean}) {
    final now = streak(s);
    streaks[s.name] = clean ? now + 1 : (now >= 4 ? 2 : 0);
  }

  Map<String, int> toJson() => streaks;
}
