# tutor_vision

On-device camera recognition for GoAbacUs. Pure Dart: no OpenCV, no native
code, no network. Used by `packages/tutor_camera` in the Tutor app.

| Step | File | What |
|---|---|---|
| Markers | `aruco.dart` | ArUco `DICT_4X4_50` detector: adaptive threshold → dark components → convex quad → edge line fit → 6×6 bits → dictionary match in all 8 orientations. A mirror-imaged marker (sheet seen from behind, odd number of mirrors) is recognised and flagged. |
| Sheet | `layout.dart`, `board.dart` | All GoAbacUs sheets share one frame (same as the desk film sheets): 8 mm corner markers 0–3 (TL, TR, BR, BL as the child sees it), a sheet-id marker, a 12-patch colour strip. From ≥2 markers: least-squares homography sheet mm → image, reprojection error, "sheet cut on the right" / "marker covered" hints, warp of any sheet rectangle to a top view at N px/mm, white balance from the strip. |
| Foreground | `blobs.dart` | Difference to the empty-sheet reference in sheet space (so the phone may move a little), with exposure drift compensation and soft-shadow suppression. |
| Rods | `rods.dart` | Blobs → 1 cm strips → colour per mm along the strip → runs → colour and length decided together (n rods of value v = 10·v·n mm) → trains (rods end to end). |
| Abacus | `abacus.dart` | Real abacus lying on sheet 15, wires along the long side: frame bars found as nearly full columns/rows, wires equally spaced, on each wire the widest gap splits counted (left) beads from the rest. Row 0 = units = bottom wire. |
| Touches | `touch.dart` | Matte translucent sheet seen from behind: background difference → high-pass (spot minus its 5 mm surroundings) → fingertip-size blobs with a sharp rim; hovering fingers are blurred by the diffuser and rejected. Room light (shadow) or backlight (bright spot) chosen automatically. Cell of the film table. |
| Counters | `counters.dart` | Round red / blue counters (Wendeplättchen, 12–32 mm): round blobs, touching ones counted by area, colour by the dominant channel; rods are told apart (thinner, straight edges vs scalloped). |
| Gate | `stillness.dart` | Judge only after the picture stood still ~0.7 s. |
| Events | `observation.dart` | `AidObservation`: abacus number, rods per row, touched cell, for the lesson core. |

Tests run the whole chain on synthetic phone pictures
(`test/fixtures`, made by `tools/vision/render_scenes.py`: random perspective,
uneven light, colour cast, blur, noise, JPEG; touches seen mirror-imaged
through a matte sheet): 7 sheet poses incl. 2 mirrored and 1 cut off,
6 rod layouts, 3 counter layouts (touching ones, a rod among them), 5 abacus states, 8 touch cases (3 of them a finger hovering
2.5–8 mm above the sheet).

Speed (desktop, AOT): find sheet 50 ms + warp 5 ms + rods 40 ms on a
1280×720 frame; a phone is a few times slower, fine for a settled picture.
