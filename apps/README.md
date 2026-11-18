# GoAbacUs tutor apps

Two apps built on the GoAbacUs abacus. The GoAbacUs abacus app in the
repository root stays as it is (the free app); nothing here changes it.

| App | Who | What |
|---|---|---|
| `apps/scan` — **GoAbacUs Scan** (`com.goabacus.scan`) | parent | Photographs a homework page, reads it **on the phone** (ML Kit text recognition + rule parser, no network), shows "Is it right?" with every task editable, sends the tasks to the child's device as a signed QR code, reads the lesson report back from a QR code. |
| `apps/tutor` — **GoAbacUs Tutor** (`com.goabacus.tutor`) | child | Receives tasks by QR code and leads the lesson on the screen abacus: one small question at a time, a hint ladder (remark → wire to look at → similar example → own example move by move), mistakes classified (off by one, lost ten, wrong sign, swapped digits). Shows the report as a QR code. **No internet:** the release build has no `INTERNET` permission (checked in CI) and no network code (checked by a test). |

Shared code:

- `packages/tutor_tasks` (pure Dart): task model (`eq` incl. missing numbers and
  multiplication, `steps`, `chain`, `house`), solver and core checks, packets
  (JSON → deflate → base64url, HMAC-SHA256 with the family key, split into
  several QR codes when long), pairing, lesson reports, and the offline
  worksheet parser. Its test runs the parser on OCR boxes of the nine real
  pages: **126 of 140** tasks, 16 of 18 "by steps" groups, as the Python
  prototype.
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

The child's app also has *Try with sample tasks* and a free abacus.

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
into the app), camera reading of a real abacus (`CameraAbacusSource`), recorded
voice, Rechenrahmen 5+5 model, number houses/walls in the parser, store signing.
