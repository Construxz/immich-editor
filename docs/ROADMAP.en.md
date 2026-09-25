# Roadmap

*English translation of [ROADMAP.md](ROADMAP.md) (German), as of 2026-09-25. If they differ,
the German file is authoritative.*

**Only open work lives here**, each item with an acceptance criterion. Done items leave the file;
the result goes to [DECISIONS.en.md](DECISIONS.en.md), the history is in `git log`.

⬜ not built · 🔶 partly built or not reliably tested

## Milestones

**M2. Gallery local + server, multi-select, level-1 sliders, presets.** 🔶
Built and tested: native renderer with HDR preview, geometry including the gain map, twelve
sliders, an editor modelled on Google Photos, device photos and online photos, one timeline across
device and server, library, viewer with stacks, the look of the Immich app, presets, code in
English, German and English in the app, faster opening of copies, server photos with a local
original edited locally, stacking in the background, viewer across months and with HDR, device
folders, Noodle as a server, filters, Enhance, a viewer like Google Photos, sliders and Enhance
calibrated against Google, Pop, usable without a server (D-17 to D-79). Open, in this order:
- ⬜ **Noodle:** ask Noodle whether their editor adopts the recipe format (D-27, D-56).
- 🔶 **Calibrate sliders against Google Photos:** 8 of 11 sliders are within 10 % of Google at
  ±100 (D-73), Enhance in the same range (D-74). Open:
  - Bring contrast (26 % / 16 %), saturation + (13 %) and blue tones + (32 %) below 10 %.
  - Blank frames from the renderer in the emulator, and partial frames in the preview after fast
    swiping (D-76): find the cause and clarify whether copies can be affected.
- 🔶 **Tools as in Google Photos** (maintainer's wish, 2026-09-25; measured on the test chart,
  D-73). Pop is built (D-75); open, in this order:
  - **Tone** (`~10`/`~11`).
  - **Skin tone** (`~26`/`~27`): affects skin tones only.
  - **Dynamic** (`~3`): probably local tone mapping; D-74 shows it is also part of Enhance.
  - **Sharpen** (`~32`) and **Unblur** (`~35`, German "Scharf stellen"): only a measurement on a real photo will show
    the difference.
  - **Ultra HDR** (`~8`/`~9`): the SDR image stays, a gain map is added. Goal: give a photo without
    HDR the look it would have had if the camera had captured Ultra HDR.
  - **Portrait light "Balance light"** (`~36`/`~37`): needs on-device face detection with an open
    model (D-6). "Add light" (a virtual light source) comes after that.
  Not a priority: denoise. According to the maintainer, Google's acts more like a blur; the
  benchmark is AI denoisers on the desktop (Lightroom, Topaz).
- ⬜ **My presets:** edit and rename, a "My presets" page, save and load as one `.json` per preset
  on the phone (a first step towards the idea "share presets").
- ⬜ Perspective (four-point).
- ⬜ Timeline offline: remember Immich's month list (D-55 — offline it stays empty).
- ⬜ HDR in the viewer for server-only photos too (load the original, depending on the "Mobile
  data" setting).
- ⬜ **Capture date without MediaStore** (finding 2026-09-25): photos without `datetaken` in
  Android (EXIF without time zone and without GPS, or no EXIF at all, e.g. WhatsApp) are sorted
  under the date they were added, so downloaded photos land on "today". Google Photos uses the
  EXIF date or the file name. *Acceptance:* `IMG_20210803_231353_596.jpg` without EXIF appears
  under August 2021.
- ⬜ **Timeline loads where you look** (maintainer's finding, 2026-09-25): when scrolling fast,
  Google Photos loads the visible range at once; we load month by month from the top. Load what
  is visible first, defer what was skipped. *Acceptance:* on the Pixel, jump to the end with the
  scroller; the visible tiles appear as fast as in Google Photos (screen recording, both
  measured).
- ⬜ Measure scrolling through a large library (frame rates on the Pixel, the maintainer swipes —
  `adb` does not scroll there, D-50).
- ⬜ **Security, remaining items from the review** (D-78), before the first release:
  - `android:allowBackup="false"`: otherwise the `flutter_secure_storage` data ends up in device
    and ADB backups. *Acceptance:* `adb backup` contains no app data.
  - Error messages: `Immich._ok` shows the whole response body. Behind a proxy this can be an
    HTML page with internal details. Show only the status and Immich's `message`, cut to about
    200 characters. *Acceptance:* a test with an HTML response.
  - CI: pin all `uses:` in `.github/workflows/` to commit SHAs, with the tag as a comment.
    `release.yml` runs with `contents: write` and the signing secrets. *Acceptance:* no `@v…`
    without a SHA left.
  - Redirects: does `dart:io` follow a redirect to another host with the `Authorization`
    header? *Acceptance:* measured against an endpoint that redirects with 302. If the header is
    sent along, follow redirects to the same host only.
  - A foreign file carrying our XMP chooses, via `originalSha1`, which of the user's own photos
    counts as its original, and when a preset is applied to a selection (`applyPreset`, always
    "replace") that photo goes to the trash. Recoverable, affects only the user's own assets. To
    clarify: replace only if the copy is already stacked with the original. *Acceptance:* a test
    with a planted copy.

*Acceptance* — met except for the eye's verdict on HDR (D-40, D-54): select 20 photos, apply a
custom preset, 20 stacks are created — also for a photo that was only on the device, once the
Immich app has backed it up. On the Pixel, the preview of an Ultra HDR photo shows HDR, also
after cropping and rotating, and the copy is Ultra HDR with a matching gain map — libvips
(`uhdrload`) recognises it (D-19); with "HDR" off, the copies are SDR.
→ first release. Pre-release `v0.1.0-rc.1` is out, the repo has been public since 2026-09-25, the
docs are in English too (D-82, D-84). Open:
- ⬜ **Email to Immich** (D-5): to questions@immich.app — name, "unofficial, API client, changes
  nothing on the server", link. Should have gone out before going public; the maintainer sends
  it later.
- ⬜ Condense the German DECISIONS (over 2000 lines, `doccheck` guideline 600; the English
  version is already condensed).

**M6. One renderer for all, then a web version.** ⬜ After M2, before M3 (maintainer,
2026-09-25). Today sliders, Pop and filters are computed in AGSL, so on Android only. Gallery,
editor, recipe, Immich client and JPEG assembly (including Ultra HDR) are already Dart. Flutter
runs custom fragment shaders on Android, iOS and the web. In this order:
- ⬜ **Shaders to GLSL** (Flutter `FragmentProgram`), one renderer for all platforms; the gain
  map stays Android-native for now. *Acceptance:* distance on the test chart
  (`tool/chartdump.sh`, `readchart.py --distance`) to today's GPU output at most 1 step per
  slider at ±100.
- ⬜ **Web, local:** open a photo from the PC (pick a file or drag it in; in Chrome and Edge also
  a folder, with the copy next to it), edit it in the browser, save a copy with recipe and gain
  map, without network traffic; a static page, nothing to install. *Acceptance:* an Ultra HDR
  photo from the Pixel edited in the browser, reopened on the phone, the recipe is the same.
- ⬜ **Web with Immich:** edit server photos, upload the copy and stack it. To clarify: serve the
  page under the server's address (reverse proxy, e.g. `/editor`) or under its own address, in
  which case the server has to allow requests from there. *Acceptance:* a server photo edited in
  the browser, the copy stacked in front of the original.

Open and still to be measured: HDR in the browser (display yes, editing is hard — the first
version is probably SDR carrying the gain map along), is Pop smooth in the browser? Distinction
from [immich-edit](https://github.com/haavardnk/immich-edit) (LICENSES): that is a self-hosted
RAW developer; our web version needs no server and stays with phone photos in the style of
Google Photos.

**M3. Level 2 and drawing.** ⬜
Pop, noise, best crop, skin tone; pen, highlighter, text.
*Acceptance:* a custom look with Pop and denoise can be applied as a preset to 20 photos.

**M4. Local adjustments.** ⬜
Brush, linear and radial gradient (`local`).
*Acceptance:* a sky can be darkened with a gradient without touching the subject.

**M5. Cut-out and eraser on the device.** ⬜
Level 3 (`patch`), models according to D-6.
*Acceptance:* a tapped object disappears in airplane mode.

## Ideas, not planned

- **Pro mode** like Lightroom Mobile (maintainer, 2026-09-25): curves, HSL, masks, open source
  and on the device. Mentioned as an idea in the README.
- **Share presets and filters** like Lightroom Mobile (maintainer, 2026-09-24): as a file
  (`.cube`, recipe JSON) or through a public server where presets are uploaded with a name,
  rated and downloaded — inside the app. A project of its own; left out (D-62).

## Open decisions

**E4. Is MediaPipe acceptable?** ⬜ See D-6.
*Acceptance:* decided before M5.
