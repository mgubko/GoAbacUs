import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goabacus_tutor/lesson.dart';
import 'package:goabacus_tutor/speech/speech.dart';
import 'package:goabacus_tutor/strings.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

TaskPacket _packet(List<Task> tasks) =>
    TaskPacket(family: 'f', kid: 1, id: 'p1', tasks: tasks);

void main() {
  test('a whole steps task, led by what the abacus shows', () {
    final l = Lesson(_packet([StepsTask(57, Op.add, 28)]));
    expect(l.say.key, 'set');
    expect(l.startValue, 57);
    l.onAbacus(50); // not yet
    expect(l.phase, Phase.setStart);
    l.onAbacus(57);
    expect(l.phase, Phase.operate);
    expect(saying(l.say), contains('20'));
    l.onAbacus(77);
    expect(l.phase, Phase.answer);
    expect(l.submit(77), isTrue);
    l.next();
    // 77 + 8 goes on from the beads already there.
    expect(l.question.continues, isTrue);
    l.onAbacus(77);
    expect(l.phase, Phase.operate);
    l.onAbacus(85);
    expect(l.submit(84), isFalse);
    expect(l.say.key, 'wrong_offByOne');
    expect(l.submit(85), isTrue);
    l.next();
    expect(l.phase, Phase.done);
    expect(l.results.single.solved, isTrue);
    expect(l.results.single.mistakes, [Mistake.offByOne]);
    expect(l.results.single.hints, 1);
  });

  test('missing numbers start from the right place', () {
    final l = Lesson(_packet([EqTask.parse('?+8=15'), EqTask.parse('9+?=15')]));
    expect(l.startValue, 15);
    expect(l.goalValue, 7);
    l.onAbacus(15);
    expect(l.say.key, 'good');
    expect(l.say.then?.key, 'take');
    l.onAbacus(7);
    expect(l.say.key, 'how_many_left');
    l.submit(7);
    l.next();
    expect(l.startValue, 9);
    expect(l.goalValue, 15);
  });

  test('the hint ladder: remark, wire, similar example, own example', () {
    final l = Lesson(_packet([EqTask.parse('8+5')]));
    final h1 = l.nextHint();
    expect(l.say.key, 'guide_carry'); // 8 + 5 = 8 + 10 − 5
    expect(h1.demo, isNull);
    final h2 = l.nextHint();
    expect(h2.row, 0);
    final h3 = l.nextHint();
    expect(h3.demo, isNotNull);
    expect(h3.demo!.format(), isNot('8 + 5'));
    expect(hasCarryLike(h3.demo!.terms), isTrue);
    l.demoDone(own: false);
    expect(l.phase, Phase.setStart);
    final h4 = l.nextHint();
    expect(h4.demoIsOwn, isTrue);
    expect(h4.demo!.terms, [8, 5]);
  });

  test('desk aids as German schools use them', () {
    final all = Aid.values.toSet();
    final l = Lesson(
      _packet([
        EqTask.parse('8+5'),
        EqTask.parse('7+?=10'),
        EqTask.parse('6*7'),
        EqTask.parse('17:5'),
      ]),
      available: all,
    );
    expect(l.choice.aid, Aid.twentyField);
    expect(l.say.key, 'field_bridge');
    expect(saying(l.say), contains('8'));
    l.submit(13);
    l.next();
    expect(l.choice.aid, Aid.rods);
    expect(l.say.key, 'rods_missing');
    l.submit(3);
    l.next();
    expect(l.choice.aid, Aid.hundredField);
    expect(l.say.key, 'hf_mul');
    // The first hint derives 6 · 7 from the core task 5 · 7.
    l.nextHint();
    expect(l.say.key, 'guide_times_derived');
    expect(l.say.args['core'], 5);
    l.submit(42);
    l.next();
    expect(l.say.key, 'hf_div');
    l.submit(3);
    l.next();
    expect(l.say.key, 'hf_rest');
    l.submit(2);
    l.next();
    expect(l.phase, Phase.done);
    expect(l.results.map((r) => r.aids.first), [
      'twentyField/act',
      'rods/act',
      'hundredField/act',
      'hundredField/act',
    ]);
  });

  test('stages: look, imagine, in the head; a mistake goes back to the hands', () {
    final progress = Progress({Skill.bridge20.name: 4});
    final l = Lesson(
      _packet([EqTask.parse('8+5')]),
      available: {Aid.twentyField},
      progress: progress,
    );
    expect(l.choice.stage, Stage.imagine);
    expect(l.say.key, 'stage_imagine');
    expect(l.aidHidden, isTrue);
    l.submit(12);
    expect(l.choice.stage, Stage.act);
    expect(l.say.then?.key, 'back_to_act');
    expect(l.say.then?.then?.key, 'field_bridge');
    expect(progress.streak(Skill.bridge20), 4); // recorded at the answer
    l.submit(13);
    expect(progress.streak(Skill.bridge20), 2);
  });

  test('two misses with one desk aid: another aid', () {
    final l = Lesson(
      _packet([EqTask.parse('8+5')]),
      available: {Aid.twentyField, Aid.rods},
    );
    l.submit(12);
    expect(l.choice.aid, Aid.twentyField);
    l.submit(11);
    expect(l.choice.aid, Aid.rods);
    expect(l.say.key, 'other_aid');
  });

  test('the child asks for another aid', () {
    final l = Lesson(
      _packet([EqTask.parse('8+5')]),
      available: {Aid.twentyField, Aid.rods},
    );
    expect(l.choice.aid, Aid.twentyField);
    l.switchAid();
    expect(l.choice.aid, Aid.rods);
    expect(l.say.key, 'rods_bridge');
    l.switchAid();
    expect(l.choice.aid, Aid.abacus);
    l.switchAid();
    // All tried: start over from the first.
    expect(l.choice.aid, isNot(Aid.abacus));
  });

  test('division with remainder on the abacus', () {
    final l = Lesson(_packet([EqTask.parse('17:5')]));
    expect(l.usesAbacus, isTrue);
    l.onAbacus(17);
    expect(l.say.then?.key, 'div_abacus');
    l.onAbacus(2);
    expect(l.phase, Phase.answer);
    expect(l.submit(3), isTrue);
    l.next();
    l.onAbacus(2);
    expect(l.say.key, 'how_many_rest');
    expect(l.submit(2), isTrue);
  });

  test('every spoken line can be voiced with recorded clips', () {
    for (final lang in languages.keys) {
      final have = allClips(lang).toSet();
      for (final key in spokenKeys) {
        final args = <String, Object>{
          'n': 57, 'k': 3, 'a': 8, 'b': 5, 'c': 13, 'd': 7, 'r': 85,
          'row': 1, 'op': '+', 'e': '7 + 6', 'aid': 'rods', 'core': 5,
          'rest': 1,
        };
        final c = clips(Say(key, args), lang)!;
        for (final x in c) {
          expect(have, contains(x), reason: '$lang $key');
        }
        expect(render(Say(key, args), lang), isNot(contains('{')),
            reason: '$lang $key');
      }
    }
  });

  test('tasks answered wrongly in the book come first', () {
    final l = Lesson(
      _packet([EqTask.parse('2+2', n: 'a'), EqTask.parse('12-5', n: 'b', child: 8)]),
    );
    expect(l.task.n, 'b');
  });

  test('every tutor line exists in every language', () {
    for (final lang in languages.keys) {
      appLang.value = lang;
      for (final key in ['set', 'add', 'take', 'until', 'mul', 'done', 'hint']) {
        expect(tr(key, {'n': 3, 'k': 2}), isNot(key));
      }
    }
    appLang.value = 'ru';
  });

  test('the tutor has no network code', () {
    // The child's app must work offline; tasks only come by QR code.
    final banned = RegExp(
      r'''import\s+['"](package:(http|dio|web_socket_channel|firebase\w*)/|dart:io)''',
    );
    for (final dir in ['lib', '../../packages/tutor_tasks/lib', '../../packages/abacus_kit/lib']) {
      for (final f in Directory(dir).listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        expect(banned.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
      }
    }
  });
}

/// 8 + 5 carries, so the similar example must carry too.
bool hasCarryLike(List<int> terms) => terms[0] % 10 + terms[1] % 10 >= 10;
