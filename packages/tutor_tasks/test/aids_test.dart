import 'package:test/test.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

Question q(String e) => EqTask.parse(e).questions.first;

void main() {
  test('skills by difficulty', () {
    expect(skillOf(q('3+4')), Skill.within10);
    expect(skillOf(q('7+?=10')), Skill.missing);
    expect(skillOf(q('12+5')), Skill.within20);
    expect(skillOf(q('8+5')), Skill.bridge20);
    expect(skillOf(q('13-5')), Skill.bridge20);
    expect(skillOf(q('7+8')), Skill.doubles);
    expect(skillOf(q('34+5')), Skill.plusOnes100);
    expect(skillOf(q('34+20')), Skill.plusTens100);
    expect(skillOf(q('57+28')), Skill.bridge100);
    expect(skillOf(q('5*7')), Skill.timesCore);
    expect(skillOf(q('6*7')), Skill.timesDerived);
    expect(skillOf(q('42:7')), Skill.division);
    expect(skillOf(q('17:5')), Skill.divisionRest);
    expect(skillOf(q('345+278')), Skill.big);
  });

  test('aids as in a German school, the abacus first in a Russian one', () {
    expect(chooseAid(q('8+5'), available: {Aid.twentyField}).aid, Aid.twentyField);
    expect(chooseAid(q('8+5'), available: {Aid.twentyField}, school: 'ru').aid, Aid.abacus);
    // Without the kit only what is always there.
    expect(chooseAid(q('8+5')).aid, Aid.abacus);
    expect(chooseAid(q('3+4')).aid, Aid.fingers);
    expect(chooseAid(q('7+?=10'), available: {Aid.rods}).aid, Aid.rods);
    expect(chooseAid(q('6*7'), available: {Aid.hundredField}).aid, Aid.hundredField);
    expect(chooseAid(q('17:5'), available: {Aid.hundredField, Aid.twentyField}).aid,
        Aid.hundredField);
    expect(chooseAid(q('57+28'), available: Aid.values.toSet()).aid, Aid.abacus);
  });

  test('another aid when one did not help, and after a lost ten', () {
    final all = Aid.values.toSet();
    expect(chooseAid(q('8+5'), available: all, avoid: {Aid.twentyField}).aid, Aid.rods);
    expect(chooseAid(q('8+5'), available: all, lastMistake: Mistake.placeValue).aid,
        Aid.abacus);
  });

  test('stages and progress', () {
    final p = Progress();
    expect(stageFor(p.streak(Skill.bridge20)), Stage.act);
    for (var i = 0; i < 2; i++) {
      p.record(Skill.bridge20, clean: true);
    }
    expect(stageFor(p.streak(Skill.bridge20)), Stage.look);
    for (var i = 0; i < 4; i++) {
      p.record(Skill.bridge20, clean: true);
    }
    expect(stageFor(p.streak(Skill.bridge20)), Stage.symbolic);
    p.record(Skill.bridge20, clean: false);
    expect(stageFor(p.streak(Skill.bridge20)), Stage.look);
    p.record(Skill.bridge20, clean: false);
    expect(stageFor(p.streak(Skill.bridge20)), Stage.act);
  });

  test('times tasks derived from core tasks', () {
    expect(deriveTimes(5, 7), isNull);
    expect(deriveTimes(6, 7), (core: 5, rest: 1, minus: false));
    expect(deriveTimes(9, 7), (core: 10, rest: 1, minus: true));
    expect(deriveTimes(4, 8), (core: 2, rest: 2, minus: false));
  });

  test('division with remainder asks for the quotient, then the rest', () {
    final t = EqTask.parse('17:5');
    expect(t.format(), '17 : 5 = ? R ?');
    expect(t.questions.map((x) => x.answer), [3, 2]);
    expect(t.questions[1].format(), '17 : 5 = 3 R ?');
    expect(Task.fromJson(t.toJson()).format(), t.format());
    expect(EqTask.parse('42:7').questions.single.answer, 6);
  });
}
