import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:goabacus_tutor/lesson.dart';
import 'package:goabacus_tutor/speech/speech.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

/// Random homework and a random child: the lesson must never throw, every
/// line must render in every language, and it must always come to the end.
void main() {
  Task randomTask(Random r) {
    int n(int max) => r.nextInt(max + 1);
    switch (r.nextInt(9)) {
      case 0:
        return EqTask.parse('${n(20)}+${n(20)}');
      case 1:
        final a = n(100);
        return EqTask.parse('$a-${n(a)}');
      case 2:
        return EqTask.parse('${n(10)}*${n(10)}');
      case 3:
        return EqTask.parse('${n(100)}:${1 + n(9)}');
      case 4:
        final a = n(20), c = a + n(20);
        return r.nextBool()
            ? EqTask.parse('$a+?=$c')
            : EqTask.parse('?-$a=${n(20)}');
      case 5:
        return ChainTask(n(10), [n(9), -n(5), n(9)]);
      case 6:
        // Too big for the screen abacus (4 wires), or nonsense from OCR.
        return EqTask.parse('${n(99999)}+${n(9999)}');
      case 7:
        return EqTask.parse('${n(30)}:0');
      default:
        return StepsTask(n(90), Op.add, n(9));
    }
  }

  for (final seed in List.generate(60, (i) => i)) {
    test('random lesson $seed', () {
      final r = Random(seed);
      final tasks = [for (var i = 0; i < r.nextInt(7); i++) randomTask(r)];
      final aids = {
        for (final a in Aid.values)
          if (r.nextBool()) a,
      };
      final l = Lesson(
        TaskPacket(family: 'f', kid: 1, id: 'p', tasks: tasks),
        rows: 4,
        random: r,
        available: aids,
        progress: Progress({
          for (final s in Skill.values) s.name: r.nextInt(8),
        }),
      );
      var steps = 0;
      while (l.phase != Phase.done) {
        expect(++steps, lessThan(2000), reason: 'stuck: ${l.say}');
        for (final lang in ['ru', 'de', 'en']) {
          expect(render(l.say, lang), isNot(contains('{')), reason: '${l.say}');
        }
        switch (l.phase) {
          case Phase.setStart:
          case Phase.operate:
            // The child moves the beads right, or wanders, or asks.
            final x = r.nextInt(5);
            if (x == 0) {
              l.nextHint();
            } else {
              l.onAbacus(x == 1 ? r.nextInt(9999) : l.goalValue);
            }
          case Phase.answer:
            final x = r.nextInt(6);
            if (x == 0) {
              l.nextHint();
            } else if (x == 1) {
              l.submit(r.nextInt(150));
            } else if (x == 2 && r.nextInt(10) == 0) {
              l.skip();
            } else if (x == 3) {
              l.switchAid();
            } else {
              l.submit(l.question.answer);
            }
          case Phase.right:
            l.next();
          case Phase.demo:
            l.demoDone(own: r.nextBool());
          case Phase.done:
            break;
        }
        l.tick(r.nextDouble() * 30);
      }
      final rep = l.report();
      expect(rep.results, hasLength(tasks.length));
    });
  }
}
