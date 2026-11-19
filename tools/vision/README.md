# Camera sheets and synthetic test pictures

- `make_calibration_sheets.py [out_dir] [dpi]` → `calibration-sheets.pdf`:
  page 1 = sheet 14 "Калибровка и палочки" (220 × 160 mm, grey field with a
  1 cm grid and two 20 cm tracks), page 2 = sheet 15 "Коврик для счётов"
  (whole A4, markers at the page corners). Same frame as the desk film sheets
  (`make_sheets.py` in the project files): ArUco DICT_4X4_50, 8 mm, corner ids
  0–3, sheet-id marker, colour strip.
- `render_scenes.py <sheets_300dpi> <film_pngs> <out>` → the fixtures of
  `packages/tutor_vision/test` and `truth.json`.

Needs `opencv-contrib-python-headless`, `matplotlib`, `numpy`.
