import 'abacus.dart';
import 'rods.dart';
import 'touch.dart';

/// A settled observation of a desk aid, what the lesson core consumes
/// (one event per settled picture, see the tutor's aids.dart).
sealed class AidObservation {
  const AidObservation();
}

/// The number shown on the abacus.
class AbacusObservation extends AidObservation {
  const AbacusObservation(this.value);
  final int value;
}

/// Rods per row, top to bottom as the child sees them, each row as rod
/// values (1-10) from left to right.
class RodsObservation extends AidObservation {
  const RodsObservation(this.rows);
  final List<List<int>> rows;
}

/// A touched cell of a film table (sheet ids 10-13), row/column counted from
/// the header row/column (0 = header).
class CellTouchObservation extends AidObservation {
  const CellTouchObservation(this.sheetId, this.row, this.col);
  final int sheetId, row, col;
}

extension AbacusReadingObservation on AbacusReading {
  AbacusObservation? get observation => value == null ? null : AbacusObservation(value!);
}

extension RodsResultObservation on RodsResult {
  /// Trains grouped into rows (centres within 7 mm vertically), top first.
  RodsObservation get observation {
    final items = [
      for (final t in trains)
        (y: t.rods.map((r) => r.center.y).reduce((a, b) => a + b) / t.rods.length,
            x: t.rods.map((r) => r.center.x).reduce((a, b) => a < b ? a : b),
            values: [
              for (final r in (List.of(t.rods)..sort((a, b) => a.center.x.compareTo(b.center.x)))) r.value
            ])
    ]..sort((a, b) => b.y.compareTo(a.y));
    final rows = <List<({double y, double x, List<int> values})>>[];
    for (final it in items) {
      if (rows.isNotEmpty && (rows.last.first.y - it.y).abs() < 7) {
        rows.last.add(it);
      } else {
        rows.add([it]);
      }
    }
    return RodsObservation([
      for (final r in rows) [for (final it in (r..sort((a, b) => a.x.compareTo(b.x)))) ...it.values]
    ]);
  }
}

extension TouchObservation on Touch {
  CellTouchObservation? observation(int sheetId) =>
      cell == null ? null : CellTouchObservation(sheetId, cell!.$1, cell!.$2);
}
