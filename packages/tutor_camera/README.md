# tutor_camera

The desk camera for the GoAbacUs apps (Flutter): camera stream → recognition
(`tutor_vision`) in a worker isolate → results.

- `DeskCameraController`: `view` (for the screen) and
  `Stream<AidObservation> observations` (settled, changed results for the
  lesson: abacus number, rods per row, counters red/blue, touched cell).
- `DeskCameraScreen` — **"Что видит камера"**: the whole sheet straightened
  by the corner-marker homography (a mirror-imaged view is turned back), the
  printed layout laid over it semi-transparently (field, markers, colour strip,
  the addition / times table grid with its heavy lines after 5), and what is
  recognised: fingertip and touched cell, rods with values, counters, abacus
  wires with digits. Second tab: the raw camera frame with the markers found.
  Open it from any app with `DeskCameraScreen.open(context)`.

In the Tutor app it opens from the camera button on the home and lesson
screens ("Что видит камера").
