# Status — what applies now

*English translation of [STATUS.md](STATUS.md) (German). If they differ, the German file is authoritative.*

**This file is overwritten, not appended to.** Why something is the way it is lives in
[DECISIONS.en.md](DECISIONS.en.md), what is still missing in [ROADMAP.en.md](ROADMAP.en.md) (both also in German, authoritative:
[DECISIONS.md](DECISIONS.md), [ROADMAP.md](ROADMAP.md)).

As of: 2026-09-25, M2 in progress (open: [ROADMAP.en.md](ROADMAP.en.md), M2).

## What exists

- **A Flutter app** (Android only, D-14; application ID `io.github.construxz.photoeditor`,
  Dart package `immich_editor`, D-10), `minSdk 34` (D-18):
  - Sign in with server, email, password; token in `flutter_secure_storage`. Or "Use without
    a server": device photos only, copies to the device, no network traffic (D-79). Warns if the
    Immich major version is not 3. Without a scheme, `https://` applies; `http://` outside the
    home network only after confirmation. Logging out also ends the session on the server (D-78).
  - Look of the Immich app (colors, Google Sans, D-35), interaction modeled on Google Photos.
  - Gallery like the Immich app (D-36): "Photos" is a timeline across device and server,
    merged via the checksum (computed once, cached; on startup the state of the last sync
    immediately, then fresh, D-51; the first run
    explains itself in a dialog, afterwards a ring around the profile picture and progress in the account window, D-39), with a cloud at the bottom
    right (device only / server only / both); from the device only selected folders, default the camera
    (D-48); "Library" with the device folders: pinned ones, then manually ordered ones, then the
    rest by newest photo (like the Immich app) or A–Z, individual ones can be hidden, also all folders of an app at once (D-52, D-59, D-61).
  - HDR button in gallery, viewer and editor, one shared state; can be hidden
    in the settings (D-58). Separate
    tabs via the "View" setting. Photos from folders that Immich does not back up: after
    saving, optionally upload archived, album "Editor for Immich", open in Immich —
    with the app Android offers, or one set in the settings (D-52).
  - Display language follows the device (German, otherwise English) or is fixed (D-43).
  - Top right the profile picture → account window like in the Immich app (profile,
    storage, app and server version, server address, pending edits, log out;
    without a server "Connect to a server", D-79) and
    **Settings** as cards: Editing (HDR), Saving (online photos via the device), Networking
    (mobile data, D-30), Stacking ("Stack now") — D-32, D-35. Tapping opens the **viewer**
    (D-33): swipe, also across month boundaries (D-47), HDR from the local original, only for photos with a gain map and only once the page is at rest; there also the HDR button and "Ultra HDR" in the info (D-54, D-63, D-64), zoom with two fingers — one finger pages, own zoom on raw touches (D-65, D-66), neighbors preloaded, small placeholder, gap while swiping (D-68), stacks like in Google Photos (original, V1, V2; set primary photo,
    keep one and delete the rest, D-34), swipe up for info below the photo, stays open while paging, drag away by the handle (D-63, D-69), "Edit" → editor →
    back to the result. Two tabs: "Device" (photos on the device,
    newest first, D-26) and "Immich": server photos by month via Immich's timeline,
    months load when scrolled to, a stack counts once (the edit in front), multi-select
    by long press; the selection gets a **preset** (D-40).
  - Editor laid out like Google Photos (D-22): black; at the top close, undo/redo,
    HDR, save, ⋮ (HDR, reset all); tab "Presets" (first "Enhance", which sets the
    sliders from the image — a toggle, also in multi-select, tuned to Google, D-70, D-71, D-74; save sliders, apply, D-40), "Crop" (frame with handles,
    aspect ratio, flip, rotate, angle ruler), "Adjust" (13 sliders as round buttons, among them Pop, D-75;
    one selected: category bar, slider as a pill with a number, Reset and "Done", D-72) and "Filters" (eight own looks as 3D LUT with preview thumbnail and strength; presets
    take the filter along, D-62); press and hold shows the original, two fingers zoom (D-76). Preview and export are computed by the native
    renderer (AGSL, `Renderer.kt`), the sliders calibrated at ±100 to Google Photos (D-73); the image area is a native view in the HDR window (D-17,
    D-20). The ruler snaps near 0; zero is marked in amber (D-41). Server photos open with Immich's thumbnail, the
    original (and with it HDR) follows in the background; saving waits for it (D-29).
  - Saving: render at full resolution, encode as JPEG with the system encoder (quality 95, D-13), EXIF
    of the original with orientation 1, recipe XMP (format in the spec, *Aufbau*); upload,
    verify (server's SHA-1 = own), stack in front of the original, add to its albums;
    about 4 s in the emulator (D-23). **Device photos** are saved by the app without a server: copy into
    the same folder of the device gallery, queued; as soon as the Immich app has backed up original and copy,
    the gallery stacks on opening or refreshing (D-26). **Online photos**
    likewise (default) into the camera folder; after stacking the copy leaves the device (D-28).
    With the setting off, directly to the server as above. A server photo whose original is also
    on the device is edited locally by the app (D-45). What can never arrive (copy or
    original deleted everywhere) drops out of the queue. As long as something is pending,
    Android's WorkManager stacks about every 15 minutes even without the app open (D-46).
  - Network: timeouts (30 s, originals and upload 3 min) and understandable errors.
  - Ultra HDR: the copy keeps the original's gain map (D-16), standard format (D-19); the
    preview shows HDR (D-20). The HDR button switches off both (setting `hdr`).
  - Re-editing: opening a copy makes the editor open the original with the copy's recipe;
    on saving "Replace copy" (the old one goes to the trash) or "Save as another copy"
    — all copies stay in one stack (D-31).
  - **Not yet:** perspective — see ROADMAP.
- Code: `lib/server/` (Immich client, endpoints in the spec, one keep-alive connection, a new one after
  a network error; network errors in logcat under `flutter`, D-77),
  `lib/gallery/` (with `device.dart` via `photo_manager`), `lib/stacking/` (stacking, also
  queued after the backup), `lib/editor/` (page, recipe, presets, loading and saving a copy, ruler,
  crop frame, preview channel),
  `lib/export/` (assembling the JPEG file), `lib/photo.dart`; native in
  `android/app/src/main/kotlin/…/` `Renderer.kt`, `Geometry.kt`, `Optimize.kt`, `Pop.kt` (guided filter for Pop), `Lut.kt` (filters from `assets/luts`, generated by
  `tool/make_luts.py`), `Preview.kt` (session, view),
  calibration with `tool/testchart.py`, `tool/readchart.py`, `tool/chartdump.sh` (D-73, also for photos: D-74),
  `MainActivity.kt` (channel `immich_editor/renderer`). **Code, file names and comments in
  English** (D-42). Display language German or English according to the device, switchable
  in the settings (D-43); strings in `lib/l10n/app_{de,en}.arb`. No Google Play services, no Firebase.
- Tests: `test/` (32 — folder order, language choice, JPEG segments, Ultra HDR structure, recipe including foreign recipes, presets, ruler, queue, zoom in the viewer,
  checksum matching, server address, startup),
  `android/app/src/test/` (21 — geometry, `.cube` filters, Enhance, Pop, JVM, also in CI) and `android/app/src/androidTest/`
  (15 — renderer including filters, Pop and measurement points from Google Photos on the GPU, emulator only:
  `gradlew connectedDebugAndroidTest`; there the renderer occasionally returns an empty image, then
  1–3 tests fail at random — rerun them individually, D-73).
- **CI** ([ci.yml](../.github/workflows/ci.yml)) on every push and pull request: format,
  analyze, test, debug APK.
- **Release** ([release.yml](../.github/workflows/release.yml)) on tag `v*`: signed split
  and universal APKs with `SHA256SUMS.txt` as a GitHub release. Latest release: **v0.1.0-rc.1**
  (2026-09-25, pre-release, state D-82, rebuilt in the new repo, signed with the same key).
- **Signing key** `%USERPROFILE%\keys\immich-editor-upload.jks`, alias `upload`, backed up by
  the maintainer; in GitHub as secrets `ANDROID_KEYSTORE_BASE64`,
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. Local builds
  without `android/key.properties` sign with the debug key.
- Git repository, branch `main`, remote `origin` = `https://github.com/Construxz/immich-editor.git`
  (**public** since 2026-09-25 with pre-release `v0.1.0-rc.1`, D-4; recreated the same day
  with only the cleaned-up history, the old repo is deleted, D-82). Own
  social preview image (`docs/assets/social-preview.png`), issues only via forms (D-83).
- **The maintainer's Pixel:** app version `0.1.0-rc.1` (release build, debug key, arm64), installed
  2026-09-25 10:49 with `adb install -r`, `versionName` checked via `dumpsys`; signed in as the test user.

## Development environment

Checked 2026-09-21 with `flutter doctor`: no issues.

| Tool | Version | Location |
|---|---|---|
| Flutter (stable) | 3.47.5, Dart 3.13.4 | `%USERPROFILE%\develop\flutter` (Git clone, in the user PATH) |
| JDK | 25.0.3 (JBR from Android Studio) | `C:\Program Files\Android\Android Studio\jbr` |
| Android Studio | Build 261.26222.65 | `C:\Program Files\Android\Android Studio` |
| Android SDK | Platform 37.0, Build-Tools 36.0.0, Platform-Tools 37.0.1, cmdline-tools 23.0, NDK 28.2.13676358 | `%LOCALAPPDATA%\Android\Sdk` |
| AGP / Gradle / Kotlin | 9.1.0 / 9.3.1 / 2.4.0 | from the Flutter template |
| Android SDK Command-line Tools | `android sdk install …` instead of `sdkmanager` (which crashes in 23.0) | `%LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest\bin\android.exe` |
| Emulator | AVD `editor_pixel7pro`: Pixel 7 Pro, API 37 (`google_apis`, x86_64), 6 GB RAM, host GPU, WHPX | `%USERPROFILE%\.android\avd` |
| Test device | The maintainer's Pixel 7 Pro (Android 17), USB debugging — only after asking | — |

CI uses the same Flutter version, pinned in both workflows, and Temurin 25.
Updating Flutter means: change it locally **and** in both workflows.

## Immich test user

For development there is the user **"Editor Test"** on the maintainer's server
(created 2026-09-21): not an admin, 10 GB quota, own library. In it: the test photos
Testfoto A (Ultra HDR) and Testfoto B (D-12), plus variants of Testfoto A with appended
null bytes so Immich does not reject them as duplicates (`testfoto-a-hdr.jpg` … `-hdr4.jpg`,
`testfoto-a-exif6.jpg` with EXIF orientation 6), most with an edited copy in the stack;
older copies in the trash; album "M1-Test"; `preset-01` … `-11` and `geraet-preset` with a copy
from the presets acceptance test (D-40). The images themselves (Wikimedia Commons, CC BY-SA 4.0)
are not in the repo. Server address, API key (permission "all", only affects its own library),
email and password are in the local `.env` in the project folder (`IMMICH_SERVER`,
`IMMICH_API_KEY`, `IMMICH_TEST_EMAIL`, `IMMICH_TEST_PASSWORD`; covered by `.gitignore`).
Access via `x-api-key` against `IMMICH_SERVER/api/…`. Checked 2026-09-21: `GET /api/users/me`
returns "Editor Test", not an admin. **Use only this access**, never a key of the
admin account with the real library.

## Noodle test server

Local on the development machine (Docker Desktop), separate from any real library:
`%USERPROFILE%\noodle-test` (Compose project `noodle-test`, Noodle Gallery v5.7.0 without ML,
port 2283, data in the folder). Credentials in `.env.local` there (admin, test user "Editor Test").
Start: `docker compose up -d` in that folder — if the server exits because it started before the
database, follow up with `docker compose up -d immich-server`. The emulator reaches it at
`http://10.0.2.2:2283`.

## Which Immich version it is built against

The test user's server runs **Immich 3.2.2** (since the evening of 2026-09-21; M1 was accepted against
3.1.0, D-12). The spec's endpoints are checked against `open-api/immich-openapi-specs.json`
in tag `v3.2.2` (2026-09-21).
