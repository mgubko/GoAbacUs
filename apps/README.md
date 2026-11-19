# GoAbacUs tutor apps

Two apps built on the GoAbacUs abacus. The GoAbacUs abacus app in the
repository root stays as it is (the free app); nothing here changes it.

| App | Who | What |
|---|---|---|
| `apps/scan` — **GoAbacUs Scan** (`com.goabacus.scan`) | parent | Photographs a homework page, reads it **on the phone** (ML Kit text recognition + rule parser, no network), shows "Is it right?" with every task editable, sends the tasks to the child's device as a signed QR code, reads the lesson report back from a QR code. |
| `apps/tutor` — **GoAbacUs Tutor** (`com.goabacus.tutor`) | child | Receives tasks by QR code and leads the lesson on the screen abacus: one small question at a time, a hint ladder (remark → wire to look at → similar example → own example move by move), mistakes classified (off by one, lost ten, wrong sign, swapped digits). Shows the report as a QR code. **No internet:** the release build has no `INTERNET` permission (checked in CI) and no network code (checked by a test). |

| `apps/camlab` — **GoAbacUs Camera Lab** (`com.goabacus.camlab`) | developer / test | Point the phone at a printed sheet: it finds the corner markers, shows the straightened field and reads rods (sheet 14), an abacus (sheet 15) or finger touches from behind (film tables 10–13). For testing the camera before the desk box exists. |

Shared code:

- `packages/tutor_tasks` (pure Dart): task model (`eq` incl. missing numbers and
  multiplication, `steps`, `chain`, `house`), solver and core checks, packets
  (JSON → deflate → base64url, HMAC-SHA256 with the family key, split into
  several QR codes when long), pairing, lesson reports, and the offline
  worksheet parser. Its test runs the parser on OCR boxes of the nine real
  pages: **126 of 140** tasks, 16 of 18 "by steps" groups, as the Python
  prototype.
- `packages/tutor_vision` (pure Dart): camera recognition, see its README.
- `packages/abacus_kit`: physics, painting, sound, tilt and the example player,
  copied from the GoAbacUs app (`lib/`), plus two tutor options on the
  controller: hide the row digits, light up a wire.

## Flow

1. Parent: *Add a child* → *Pair the child's device* shows a pairing QR code
   (it holds the family key). Child: *Scan code*.
2. Parent: *Photograph a page* → *Is it right?* → *Send to the child* shows the
   task QR code. Child: *Get tasks* → *Start*.
3. After the lesson the child's device shows the report QR code; parent:
   *Read the child's report*.

One phone for both: on the task QR screen the parent taps *Continue on this
phone*; Scan opens the tutor by the app link `goabacus-tutor://open` with the
pairing and the task packet, and the lesson starts. At the end *Give the phone
back* opens Scan with the report (`goabacus-scan://open`). Same signed codes,
no network.

The child's app also has *Try with sample tasks* and a free abacus.

## Teaching aids

For every question the tutor picks a desk aid the family has (set in the
parent's app: abacus, rods, twenty frame, 10×10 field, addition and times
table films; fingers and the screen abacus always count) and a stage: hands
on → look → imagine → in the head. The rules follow German primary-school
methodology (PIKAS, Mahiko, Wartha & Schulz); the table is in
`packages/tutor_tasks/lib/src/aids.dart`, the lesson in
`apps/tutor/lib/lesson.dart`, the pictures in `apps/tutor/lib/aid_picture.dart`.

## Voice

The tutor's lines are recorded at build time and shipped as assets
(`apps/tutor/assets/voice/<lang>/`, AAC, `index.json` maps clip text to file).
Each line is cut at its numbers into fixed phrases; numbers 0–100 and the full
hundreds are recorded once each. After changing a line in
`lib/speech/lines.dart`:

```
cd apps/tutor
VOICE_DUMP=1 flutter test test/voice_clips_test.dart   # updates tool/voice/clips.json
GEMINI_API_KEY=... python3 tool/voice/make_voice.py      # records only new clips
```

The script checks every recording with speech recognition and retries. A test
fails while `clips.json` is out of date; a clip without a recording is shown
but not spoken.

## Build

```
cd apps/tutor   # or apps/scan
flutter pub get
flutter run
```

CI: `.github/workflows/tutor-apps.yml` tests both packages and apps and builds
debug APKs (artifacts `goabacus-scan-apk`, `goabacus-tutor-apk`).

## Not yet

Cloud parsing for hard pages (needs the server proxy: the Gemini key never goes
into the app), camera reading of a real abacus and desk aids (`CameraAbacusSource`), Rechenrahmen 5+5 model, number houses/walls in the parser, store signing.
