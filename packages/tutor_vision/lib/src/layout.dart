import 'homography.dart';

/// An axis-aligned rectangle on the sheet, mm, y up.
class MmRect {
  const MmRect(this.x, this.y, this.w, this.h);
  final double x, y, w, h;
  double get right => x + w;
  double get top => y + h;
  bool contains(Pt p) => p.x >= x && p.x <= right && p.y >= y && p.y <= top;
}

/// A table printed on a sheet: [cells] x [cells] square cells of [cell] mm,
/// bottom-left at ([x], [y]); row 0 and column 0 are the headers.
class TableGrid {
  const TableGrid({required this.x, required this.y, required this.cell, required this.cells, required this.first});
  final double x, y, cell;
  final int cells;

  /// Value in the first header cell (0 for addition, 1 for multiplication).
  final int first;

  double get top => y + cell * cells;

  /// (row, column) of the cell under [p], counted from the top-left header
  /// cell, or null outside the table.
  (int, int)? cellAt(Pt p) {
    final c = ((p.x - x) / cell).floor();
    final r = ((top - p.y) / cell).floor();
    if (r < 0 || c < 0 || r >= cells || c >= cells) return null;
    return (r, c);
  }

  Pt centerOf(int row, int col) => Pt(x + cell * (col + 0.5), top - cell * (row + 0.5));
}

/// The printed layout of one sheet (all coordinates in mm, origin at the
/// bottom-left corner of the sheet as the child sees it, y up).
///
/// All GoAbacUs sheets share the frame of the desk film sheets: ArUco
/// DICT_4X4_50, 8 mm, corner ids 0-3 (TL, TR, BR, BL), a sheet-id marker
/// left of the top-right corner, a 12-patch colour strip along the bottom.
class SheetLayout {
  const SheetLayout({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.field,
    this.table,
    this.markerSize = 8,
  });

  /// Sheet-id marker.
  final int id;
  final String name;
  final double width, height;
  final MmRect field;
  final TableGrid? table;
  final double markerSize;

  /// Bottom-left corners of the markers, by id.
  Map<int, Pt> get markers => {
        0: Pt(1, height - 9),
        1: Pt(width - 9, height - 9),
        2: Pt(width - 9, 1),
        3: const Pt(1, 1),
        id: Pt(width - 19, height - 9),
      };

  /// Printed TL, TR, BR, BL corners of marker [mid].
  List<Pt> markerCorners(int mid) {
    final p = markers[mid]!;
    final s = markerSize;
    return [Pt(p.x, p.y + s), Pt(p.x + s, p.y + s), Pt(p.x + s, p.y), p];
  }

  /// Colour strip: white, grey, rods 1-10.
  List<MmRect> get patches => [for (var i = 0; i < 12; i++) MmRect(14 + i * 9.5, 1.5, 8, 7)];

  static const _sheet = 220.0, _sheetH = 160.0;
  static const _field = MmRect(10, 10, 200, 140);

  static const addAnswers = SheetLayout(
      id: 10, name: 'Таблица сложения 0–10', width: _sheet, height: _sheetH, field: _field,
      table: TableGrid(x: 40, y: 10, cell: 140 / 12, cells: 12, first: 0));
  static const addBlank = SheetLayout(
      id: 11, name: 'Поле сложения 0–10', width: _sheet, height: _sheetH, field: _field,
      table: TableGrid(x: 40, y: 10, cell: 140 / 12, cells: 12, first: 0));
  static const mulAnswers = SheetLayout(
      id: 12, name: 'Таблица умножения 1–10', width: _sheet, height: _sheetH, field: _field,
      table: TableGrid(x: 40, y: 10, cell: 140 / 11, cells: 11, first: 1));
  static const mulBlank = SheetLayout(
      id: 13, name: 'Поле умножения 1–10', width: _sheet, height: _sheetH, field: _field,
      table: TableGrid(x: 40, y: 10, cell: 140 / 11, cells: 11, first: 1));
  static const calibration =
      SheetLayout(id: 14, name: 'Калибровка и палочки', width: _sheet, height: _sheetH, field: _field);
  static const abacusMat =
      SheetLayout(id: 15, name: 'Коврик для счётов', width: 273, height: 186, field: MmRect(10, 10, 253, 166));

  static const all = [addAnswers, addBlank, mulAnswers, mulBlank, calibration, abacusMat];

  static SheetLayout? byId(int id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }
}
