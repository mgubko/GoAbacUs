import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goabacus_tutor/lesson.dart';
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
    expect(l.say.args['next'], 'take');
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
