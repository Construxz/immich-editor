# Decisions and findings

*Condensed English translation of [DECISIONS.md](DECISIONS.md) (German). Every decision, reason,
number and measurement method is kept; if the two differ, the German file is authoritative.*

One decision or finding per entry, with date, reasoning and — for findings — how it was
measured. **New entries go on top.** What is still to do is in [ROADMAP.en.md](ROADMAP.en.md),
what is true now in [STATUS.md](STATUS.md) (German), the concept in
[specs/0001-editor.md](../specs/0001-editor.md) (German).

---

## 2026-09-25 · D-84: ROADMAP and DECISIONS also in English

The maintainer's wish before going public: outsiders should be able to read the plan and the
decisions. Decided: **in addition**, the German files stay authoritative
([ROADMAP.en.md](ROADMAP.en.md), this file). The English DECISIONS is condensed (decisions,
reasons, numbers and measurement methods stay, filler goes). Whoever changes the German file
updates the English one in the same commit (CLAUDE.md). `doccheck` does not count point numbers
in `*.en.md`, otherwise it would report every ROADMAP number twice (its self-test checks this).
The full translation per D-15 (M2) is still open.

---

## 2026-09-25 · D-83: Contributions: CONTRIBUTING, issue forms, AI contributions allowed if labelled

Before going public, to curb generated issues and PRs:
- **[CONTRIBUTING.md](../CONTRIBUTING.md)** (English): bugs, requests; discuss larger changes in
  an issue first. AI contributions **allowed** (unlike Immich; this project is itself vibe-coded)
  if labelled, self-tested and understood.
- **Issue forms** only (`.github/ISSUE_TEMPLATE/`, `blank_issues_enabled: false`): bug report
  requires phone model, Android version, app version, photo location, steps, expected/actual;
  request requires goal and current workaround. Generated reports rarely fill these well.
- **External PRs:** nothing configured. GitHub runs Actions for first-time contributors only after
  approval, fork PRs get no secrets, and the release workflow runs only on tags.

---

## 2026-09-25 · D-82: Personal data removed from repo and history; first pre-release 0.1.0-rc.1

Searched all tracked files and the full history (106 commits) for personal data:
- **Clean:** no credentials, tokens or keys (`.env`, `key.properties` never committed); no server
  domain, private e-mail in text or device serial; all images without GPS.
- **Removed** (maintainer: "the e-mail must go, rework the rest safely"):
  - Every commit's author/committer had the private Gmail address and full name. Now
    `Construxz <153311222+Construxz@users.noreply.github.com>`, also going forward (`git config`).
  - Paths with the Windows user name → `%USERPROFILE%`, `$HOME`, `<Projektordner>`.
  - Test photos renamed Test photo A (Ultra HDR) and B, file names too (`testfoto-a-hdr.jpg` …);
    street locations → `<Ort>`; the camera app → "a camera companion app".
- **How:** `git filter-branch` with new identity and a replacement script per commit, after a
  `git bundle` backup outside the repo. Verified: 106 commits, all new identity; name, e-mail,
  paths, places, street: 0 hits in history; tip differs only in the 33 intended lines. Commit
  hashes in DECISIONS updated. Force-pushed.
- **Releases:** old tags/releases (`v0.0.1`, `v0.1.0-dev.75`, `-dev.76`) deleted; first release is
  pre-release `v0.1.0-rc.1`. The release workflow takes version and build number from
  `pubspec.yaml` (not the CI run number), fails on tag mismatch, and marks hyphenated tags as
  pre-release.
- **New GitHub repo instead of cleanup** (addendum, 2026-09-25): in the old repo 96 of 108 Actions
  runs still referenced old commits whose author the API returned with the old e-mail; GitHub keeps
  rewritten commits reachable by hash indefinitely, and the activity log shows the force push. Old
  repo renamed `immich-editor-old` (private backup, maintainer deletes it). `Construxz/immich-editor`
  created fresh with only the cleaned history and tag `v0.1.0-rc.1`; maintainer re-entered the four
  signing secrets. **Verified via REST API:** 108 commits, all noreply; 3 Actions runs (CI on
  `a1fdee3` and `eb0fb08`, release on `eb0fb08`), all green and noreply; one release
  `v0.1.0-rc.1` (pre-release) with 4 APKs and `SHA256SUMS.txt`; one tag; activity shows only
  creation of `main`. Old e-mail across all responses (repo, commits, runs, releases, tags, refs,
  events, activity, contributors; 540 kB): 0 hits. New arm64 APK has the same signing certificate
  (`apksigner verify --print-certs`, SHA-256 `9adfffc3…131f`), so updates over old installs work.
  To do: enable "Keep my email addresses private" and "Block command line pushes that expose my
  email" in the GitHub account.

App version `0.1.0-rc.1` (build 82).

---

## 2026-09-25 · D-81: Screenshots and before/after for the README; selected filter visible

**Screenshots** (`docs/assets/screenshots/app.webp`): gallery, editor with Pop 71, filters; release
build, emulator, no-server mode. Gallery shows only `Pictures/Showcase` (no server addresses or
account names). The maintainer's photos: 18 picked by him, 24 drawn randomly from June–August
2026, keeping only subjects without people, plates, interiors or notes. GPS, serials and maker data
stripped (only the EXIF block replaced, image bytes identical, checked on 53 files).

**Before/after** (`before-after.webp`, `tool/before_after.py`): a divider sweeps over four photos.
"After" is rendered by our GPU renderer (`ChartDump`, now applying the recipe's crop), reproducing
the maintainer's Google edits: crop via normalized cross-correlation of edges, sliders via an
optimizer on a Python port of the shader (≤ 0.6 levels from the GPU). Distance to Google in levels,
before → after: painted lady 13.1 → 6.0; tower 14.9 → 6.5; Fiat 7.9 → 2.3; mountains 9.9 → 3.8.
Castle (13.5 → 13.3) not reproducible, probably perspective correction. Shop and coast: Google
barely changed them.

**Findings:**
- **Selected filter invisible** (maintainer): its ring was drawn *behind* the thumbnail, on every
  device. Now on top (`DecorationPosition.foreground`); the selected label is coloured and bold,
  including "Enhance". Checked in the emulator on "Film".
- **Photos without capture date:** if Android lacks `datetaken` (EXIF without time zone and GPS,
  or no EXIF), they sort by date added. Three maintainer photos on the Pixel affected (ROADMAP).
- **Timeline scrolling:** loads month by month from the top, not where you look (maintainer, vs.
  Google Photos; ROADMAP).

App version `0.1.0-dev.81`.

---

## 2026-09-25 · D-80: App icon, slogan and a README for outsiders

**Icon and slogan** by the maintainer: four red/yellow/green/blue leaves around a white crop frame
with a magic wand; "Your photos. Your edits. Your server." Made for dark backgrounds; the white
centre glow vanishes on white (checked on white and dark grey).

**Built** with `tool/make_icons.py` from `docs/assets/icon-source.png`:
- **App icon:** adaptive (`mipmap-anydpi-v26`), background `#202124`, motif at 62 % of 108 dp, so
  round masks don't clip it; legacy 48 dp icons as a dark rounded tile. The Android 12+ splash uses
  it instead of the Flutter logo.
- **GitHub:** `docs/assets/icon.png` atop the README; `docs/assets/social-preview.png` (1280 × 640,
  icon, name, slogan in Google Sans), uploaded by hand under *Social preview* (no API for it).

**New README** (English, for the Immich community): features, platforms, how it works with Immich;
openly vibe-coded and how it is still verified; why no PR to Immich, iPhone, ideas, contributing.
Facts checked 2026-09-25:
- Immich's [CONTRIBUTING.md](https://github.com/immich-app/immich/blob/main/CONTRIBUTING.md):
  "We ask you not to open PRs generated with an LLM"; larger PRs to be discussed on Discord first.
  So a PR is out.
- [Building the Immich editor](https://immich.app/blog/immich-editor) (2026-01-30): Immich v2.5.0
  has non-destructive crop, rotate and flip, stored server-side as "Edit Actions"; filters planned.
  Four earlier PRs failed (#3271, #5151, #9575, #11658).
- Trigger: Noodle Gallery was rejected on Reddit as an AI fork ("why no PR?"; maintainer's
  screenshots).

App version `0.1.0-dev.80`.

---

## 2026-09-25 · D-79: Usable without a server

Maintainer's request (D-77): without an Immich or Noodle account the app should edit device
photos, no Google services, no ads. Previously it showed only the login, and the timeline knew
device photos only via server matching.

**Built:**
- **Entry:** login page has "Use without server" ("Ohne Server nutzen"), stored as `withoutServer`;
  the app then starts in the gallery. Account sheet shows "No server" with "Connect to server"
  (leads to login, keeps settings and the choice). Logging in clears it.
- **`Immich?` everywhere:** gallery, library, viewer, editor, saving, presets, settings. The
  compiler flagged every site; server-only paths use `!`.
- **Timeline:** `checkBackup(null)` lists all device photos without checksums; no cloud icons.
- **Viewer:** no place names (`placeAt` uses Immich); coordinates remain.
- **Saving:** always to the device; no stacking queue, no "open in Immich?", message "Saved on
  device".
- **Settings:** "Saving", "Network", "Stacking" hidden.
- **Also fixed:** the account sheet opened only after the account loaded, so with the server down
  settings were unreachable, and a failed load stayed empty until restart (empty avatar in D-77).
  Now it always opens; a failed load is retried on the next gallery reload.

**Verified** 2026-09-25 in the emulator, per ROADMAP acceptance:
- `pm clear`, photo permission, "Use without server": gallery shows device photos, no clouds.
- Edited brightness, saved: copy is the newest MediaStore row (`optimize-blau.edit (2).edit.jpg`,
  `DCIM/Camera/`).
- **No network traffic:** app UID rx+tx in `dumpsys netstats` (after `--poll`) identical before and
  after (516,309).
- Account sheet shows "Connect to server"; settings have four sections. Reconnected as the test
  user: gallery with server and clouds.
- `flutter analyze` clean, `flutter test` 32 green.

App version `0.1.0-dev.79`.

---

## 2026-09-25 · D-78: Security: HTTP only after confirmation, logout revokes the token, foreign recipes clamped

Reviewed client, login, storage, background job, native channel, recipe and JPEG parsing,
manifest, CI, git history. Fine: token in `flutter_secure_storage`, no certificate exceptions, no
secrets in history (only variable names), no private host names in docs, only the launcher
exported. Fixed:

- **Cleartext login.** Cleartext is allowed in the manifest and `http://` passed silently, exposing
  password and bearer token. Now no scheme means `https://` (`Immich.address`); `http://` needs
  confirmation unless private (`Immich.isPrivate`: 10/8, 172.16/12, 192.168/16, loopback,
  link-local, fc00::/7, `localhost`, `.local`/`.lan`/`.home.arpa`/`.internal`, Tailscale 100.64/10
  and `.ts.net`, encrypted by WireGuard). Cleartext stays in the manifest: HTTP Immich at home is
  common, and Network Security Config can't express IP ranges.
- **Logout left the server session valid.** Now `POST /api/auth/logout` first (5 s, errors only
  logged, logout proceeds), then `cancelBackgroundStacking`. `curl` with the test user:
  `GET /users/me` 200 before, 401 after.
- **Recipes from foreign files.** Anyone can write the XMP namespace (shared album, download).
  `crop:[0,0,1000,1000]` would allocate a huge bitmap and OOM the app; broken JSON or EXIF aborted
  open/save. Now `Recipe.fromJson` and Kotlin `Geometry.from` clamp: sliders −1…1, angle ±45,
  quarter turns mod 4, filter strength 0…1. Out-of-frame or zero-area crop → full image; wrong
  types → missing. `recipeFrom` reads broken JSON as "not a copy". If the original's EXIF is
  invalid, the copy is saved without EXIF. Tests: `test/recipe_test.dart`, `test/jpeg_test.dart`,
  `test/immich_test.dart`, `GeometryTest.kt`.

Not tried in the emulator: the `http://` dialog is covered only by a classification test. Open
items: [ROADMAP.md](ROADMAP.en.md), M2 (*Security*).

---

## 2026-09-25 · D-77: New connection after a network error; device photos without a server

Maintainer (2026-09-25, Pixel, right after an Android update): gallery and avatar stayed empty,
then "Server unreachable"; only repeated closing/reopening helped.

**Pixel logcat** (`adb`, `logcat -b all` since the 09:50 reboot; no crash in `dumpsys dropbox`):
- Android launched the app itself at 09:52:48 (process 9968). Wi-Fi validated since 09:52:26;
  mobile re-registered at 09:52:51.
- "Close and reopen" returned the **same process** until 10:05 (only `wm_on_resume`). Swiping it
  away at 10:05:39 killed it; the new process reached the server.
- Our errors weren't logged, so the exact cause is open.

**Cause (inferred, not measured):** one keep-alive connection per process (D-23), and "Retry"
reused the client. A connection stuck across a network switch fails every request until the
process ends.

**Built:**
- `Immich._await`: after a network error (timeout, socket, aborted connection) the next request
  uses a **new client**, at most every 5 s (parallel requests like thumbnails fail together). The
  old client closes after 3 min.
- Network errors logged (`flutter`: `Immich: …`).
- Gallery reloads itself on returning to the foreground after a server error.
- Without a server the timeline keeps device photos from the last sync, with a notice and "Retry",
  instead of an empty error page.

**Verified** 2026-09-25 in the emulator: started in airplane mode: "Server unreachable: Failed host
lookup" above device photos, causes in logcat. Airplane mode off, background and back, **without**
"Retry": timeline loads with server.

The stuck-after-update case can't be reproduced; the next Pixel reboot (now logged) will tell.
`flutter analyze` clean, `flutter test` green. App version `0.1.0-dev.77`.

---

## 2026-09-25 · D-76: Pop only 0 … 100, bar scrolls to the slider, zoom in the editor

Maintainer's findings on the Pixel with `0.1.0-dev.75`:
- **Google's Pop has no negative side** (0 = off, 100 = full). Ruler now 0 to 100 (`oneSided` in
  `recipe.dart`); the renderer still accepts −1 … 1.
- **Category bar didn't scroll to the slider** when coming from the buttons. Cause: a `ListView`
  builds only visible items, so Pop (far right) didn't exist and `ensureVisible` found nothing. Now
  all 13 entries are built.
- **No pinch zoom in the editor** (native preview had no gestures). Now Flutter detects pinch/pan
  (1 … 4×, double-tap resets) over the image and sends scale and offset to the native view
  (`zoom`), which redraws its preview, so high zoom is only as sharp as the preview (≤ 2048 px).
  Off while cropping, reset on close.

**Verified** 2026-09-25 in the emulator: from the buttons, "Pop" sits yellow mid-bar; ruler starts
at 0, stays there dragged down, reaches 100. Pinch **not** testable: `adb input` has one finger,
`sendevent` multi-touch (with `adb root`) reached none of eleven virtual touchscreens; the
maintainer checks on the Pixel. `flutter analyze` clean, `flutter test` green.

**Finding:** after fast ruler swipes (three in three seconds) the emulator preview showed only a
strip of the image in 3 of 12 cases (Pop and vignette); slow: 0 of 12. Probably the blank images
from D-73 (ROADMAP). App version `0.1.0-dev.76`.

---

## 2026-09-25 · D-75: Pop: local contrast with a guided filter, no relief

Maintainer uses Pop often; Google's Pop 100 on the test chart looked to him "like a normal map",
each patch with a drop shadow right and below.

**Method.** Google Pop 100 copies of six maintainer camera photos (`DCIM/Camera`, 2026-09-25: the
five from D-74 plus one; working folder only). A second chart (`python tool/testchart.py pop`: 80
squares at 30/90/170/230 on grey 128, every edge direction equally often) with Pop 100
(`popchart~2`) and, per the maintainer, Pop 50 (`popchart~3`). Google's luminance change regressed
onto local contrast (image minus blur), x/y derivatives (= relief) and a tone curve.

**Findings:**
- **No relief.** Derivatives add at most 0.4 % on chart and photos. Left/right edges treated
  alike; top/bottom fringes differ by about 4 levels but flip sign with grey level, so no light
  direction. The 3D look is local contrast: a 90 square on 128 → 54, a 170 one → 213, plus edge
  fringes.
- **Edge-preserving.** A guided-filter base explains 45–80 %, a Gaussian less. Fixed values for all
  photos (radius 2 % of the long edge, eps 0.01, detail × 2.31): 30–67 %. Multi-scale, log-space
  detail or brightness-dependent gain add only a few points.
- **Colour** +0–14 % (mean about 8 %); tone curve negligible.
- **Pop 50 (`popchart~3`) stronger than Pop 100** (90 square → 34 vs. 54): copies swapped or 50
  applied on the Pop 100 copy. On the first chart (`~33`/`~34`) 50 was half of 100, so Pop is
  taken as linear.

**Built:**
- New slider `pop` (−1 … 1, recipe format in the spec) in "Adjust" before the vignette.
- `Pop.kt` computes the guided filter on a ≤ 512 px copy (running sums, O(n)) and stores
  coefficients a, b in a half-float bitmap (Extended sRGB, read unchanged by the shader). The
  renderer maps them with the same geometry ("Fast Guided Filter"), so preview and export match.
- Shader, right after sharpening: `L + 1,31 · pop · (L − (a·L + b))` on all channels, saturation
  + 0.07 · pop.
- Negative values remove local contrast (Google has only 0 … 100).

**Result** (emulator GPU, 768 px, mean change in levels):

| Photo | Google | ours | match with Google |
|---|---|---|---|
| Mushroom | 18.9 | 11.7 | 54 % |
| Evening sky | 3.4 | 3.2 | 98 % |
| Haze | 9.2 | 6.4 | 72 % |
| House | 10.5 | 11.5 | 87 % |
| Forest | 11.2 | 10.1 | 82 % |
| new photo | 10.0 | 9.4 | 89 % |

Strength matches; per-pixel match is moderate, expected for local filters (a slightly different
radius shifts fringes). 2× crops (house, mushroom, forest): same character, clearer structure, no
fringes; Google stronger on mushroom and forest (darker shadows, richer red).

**Verified** 2026-09-25: `PopTest` (JVM, 2: flat area is its own base, strong edge stays in base,
fine structure goes to detail). `RendererTest` `popRaisesFineDetailFlatStays` (GPU, 3 of 3).
`flutter analyze` clean, `flutter test` 28 green. Also fixed: `optimizedKeys` lacked the D-74
saturation, so it stayed when "Enhance" was turned off. App version `0.1.0-dev.75`.

---

## 2026-09-25 · D-74: "Enhance" tuned to match Google Photos

Finding D-71: "Enhance" is barely visible. After D-73 it was far too strong on dark photos: it pulled the median to at least 0.35, and brightness is now powerful.

**How measured.** The maintainer saved "Enhance" copies of five of his own camera photos in Google Photos (`DCIM/Camera/PXL_…~2.jpg`, 2026-09-25): mushroom in a forest, evening sky, warm haze, house in sun, dark backlit forest. The photos stay in the working folder for measuring, not in the repo. Our side: `SOURCE=foto.png bash tool/chartdump.sh … optimize '{}'` (our Enhance plus the renderer in the emulator). Compared: median, 1st and 99th percentile of brightness; R/B and G over near-grey pixels (linear light, as Enhance); mean chroma; mean change in levels.

**What Google's "Enhance" does:** raises the median about a quarter of the way (in stops) toward 0.6 — 0.26 to 1.0 stops (evening sky 0.47, well-exposed mushroom 0.26). About 10–15 % more chroma. Corrects strong casts to R/B ≈ 1.1 and G ≈ 1.0–1.04 (haze 1.47 → 1.14); leaves blue hour (0.77 → 0.80) and slightly warm photos alone. Barely moves white and black.

**Built** (`Optimize.kt`):
- Brightness: median a quarter of the way in stops toward 0.6, instead of 70 % of the way to at least 0.35.
- White point: a quarter of the way instead of half.
- White balance: range R/B 0.8 … 1.1 and G 0.95 … 1.04 instead of 1.0 … 1.25 and 0.95 … 1.1.
- Saturation +0.1, except on grey or already vivid photos (mean chroma 0.02 … 0.2).

D-70's rule "a well-exposed neutral photo gets nothing" no longer holds; like Google, it gets a slight lift.

| Photo | Change Google | ours before / now | Distance to Google before / now |
|---|---|---|---|
| Mushroom | 6.9 | 4.7 / 8.6 | 3.9 / 2.9 |
| Evening sky | 8.4 | 32.0 / 20.2 | 23.6 / 12.0 |
| Haze | 7.3 | 4.5 / 4.6 | 6.5 / 6.1 |
| House | 11.0 | 8.4 / 14.0 | 4.4 / 3.7 |
| Forest | 16.7 | 34.1 / 20.4 | 17.3 / 4.7 |

(Mean over all pixels in 8-bit levels, 512 px.) Strength is now in Google's range. Three differences remain:
- Google deliberately keeps the evening sky darker than the similarly dark forest. Median and percentiles don't separate them; five photos are too few to tune this reliably.
- We correct the haze only to R/B 1.21, because the shift has less effect in the bright sky.
- Google gives the forest more local contrast and keeps shadows rich. A global slider can't; this belongs to Pop/Dynamic (ROADMAP).

**Verified** 2026-09-25: the table above; in side-by-side comparison (original, Google, ours) all five are visibly close to Google. `OptimizeTest` (6, green) adjusted to the measured limits: a neutral photo gets only brightness ≤ 0.1, a warm evening (R/B 1.2) only warmth −0.15 … 0, a blue cast warmth > 0.2. App version `0.1.0-dev.74`.

---

## 2026-09-24 · D-73: Sliders calibrated against Google Photos

Finding D-71 (maintainer): at ±100 our sliders are much weaker than Google Photos'.

**How measured.** On the Pixel (2026-09-24, 22:59–23:12) the maintainer saved −100 and +100 copies per slider in Google Photos from the unmodified `Pictures/Testtafel/testchart.png` (`tool/testchart.py`, 132 patches) (`testchart~4.jpg` … `~29.jpg`, sRGB, 1200 × 1600, JPEG). He mapped the numbers; direction checked by effect (−100 always first). Our side: `tool/chartdump.sh` renders the chart in the emulator through `Renderer.kt` on the GPU. `python tool/readchart.py --distance unsere.png google.jpg` prints mean |ours − Google| over all patches and channels, **relative to Google's own change** of the chart. JPEG noise is 0.2 levels (copies that don't change the SDR image: Ultra HDR, "Sharpen focus"). Formulas were fitted on a Python replica of the shader (Nelder-Mead, distance to GPU ≤ 0.6 levels); results measured on the GPU.

**What Google computes**, now in `Renderer.kt`:
- **Tone sliders** bend luminance L (Rec. 709 on sRGB values) and carry colour as c − L, not per channel (per channel, shadows and highlights were off by 45 %; this way 4 %). Shadows +: `L + 2,66 · L · (1 − L)^4,46`, highlights: `L + 1,64 · L^4,53 · (1 − L)`, both equally on all channels. Black point −: `L + 0,16 · (1 − L)^2,07`, +: `L − 0,50 · (1 − L)^1,63`. White point +: gain × 1.33 with clipping, −: `L − 0,22 · L^1,98`. Brightness: exposure in linear light, −2.4 / +2.8 stops, soft shoulder upward. Contrast: power curves either side of 0.356, black and white stay (previously black moved to 77 at −100). Chroma scales per slider with its own factor (0.68 … 1.5).
- **Saturation −** mixes toward the grey of *linear* luminance (red 178 → 82). **+** lifts muted colours more than saturated ones: × (1 + 1.27 · (1 − (max − min))).
- **Warmth and tint** are not a gain in linear light but a shift in sRGB, strongest in midtones (`L^1,55 · (1 − L)^1,19`). Black and white stay; barely visible on saturated colours. Grey 133 becomes 172/127/72 at warmth +100.
- **Blue tones** act on cyan to azure (184° ± 58°), not pure blue, as saturation at constant maximum.
- **Vignette** is round in pixels, not elliptical as ours was. Strength mainly shifts where it starts (100: from 0.24 of the half diagonal, 50: from 0.31); depth stays (0.95 / 0.90).

Only ±100 was measured (vignette 100 and 50). In between, factors and exponents go smoothly from centre to edge; vignette below 50 is estimated.

| Slider | before −100 / +100 | after −100 / +100 |
|---|---|---|
| Brightness | 47 % / 36 % | 2 % / 7 % |
| Contrast | 413 % / 68 % | **26 % / 16 %** (2.1 / 3.0 levels) |
| White point | 36 % / 40 % | 3 % / 4 % |
| Black point | 39 % / 41 % | 4 % / 7 % |
| Highlights | 96 % / 55 % | 5 % / 8 % |
| Shadows | 65 % / 59 % | 4 % / 5 % |
| Saturation | 18 % / 45 % | 4 % / **13 %** |
| Warmth | 76 % / 77 % | 6 % / 6 % |
| Tint | 91 % / 90 % | 5 % / 6 % |
| Blue tones | 126 % / 116 % | 11 % / **32 %** (1.2 levels) |
| Vignette 100 / 50 | 35 % / – | 5 % / 7 % |

Acceptance (≤ 10 %) met for 8 of 11 sliders. Not yet:
- **Contrast:** the curve fits on grey; the rest is in saturated colours. At −100 Google darkens e.g. red 255 to 227. Free luminance weights, Oklab and mixed forms didn't get below 26 %.
- **Saturation +:** green gets too strong.
- **Blue tones +:** Google darkens azure and rotates it slightly toward blue. A model with rotation and darkening still stayed at 28 %.

**Google only**, not built (finding): Tone (`~10`/`~11`), Skin tone (`~26`/`~27`, skin tones only, 2.7 levels), Pop (`~33`/`~34`), Dynamic (`~3`), Ultra HDR (`~8`/`~9`, SDR image unchanged, only a gain map), Sharpen (`~32`), Sharpen focus (`~35`), Portrait light "balance light" (`~36`/`~37`). The maintainer skipped "Add light" because it detects faces. Google has no sharpness slider; ours stays.

**Enhance** mirrors the new formulas: black point, white point and brightness solved directly, white balance by bisection on the mean grey pixel. It stays target-driven, so on photos it is as strong as before — "barely visible" (D-71) is **not fixed**. It sets nothing on the chart (fully exposed and neutral). Google's "Enhance" changes the chart by 4.8 levels on average, "Dynamic" by 10.4. Only real photos allow a comparison.

**Recipe** stays `v: 1`: the spec promises backward compatibility only from the first release. Saved test copies and custom presets look stronger when reopened.

**Emulator finding:** the renderer occasionally returns an empty, transparent image: 4 of about 30 chart renders; in `RendererTest` 1–3 of 13 tests fail randomly per run, also on the code before this change. Each test is green when rerun alone. Waiting on the `ImageReader` image's fence didn't help. Many renders in one run crashed the emulator twice. Not seen on the Pixel; whether a saved copy can come out empty is open.

**Verified** 2026-09-24: the table above (GPU in emulator). `RendererTest` has one more test, `matchesGooglePhotosOnGray`: ten grey points from the Google copies within ±5 levels. All 14 tests green three times each, run individually. `OptimizeTest` green; tint threshold lowered from 0.2 to 0.1 because the new tint is stronger. App version `0.1.0-dev.73`.

---

## 2026-09-24 · D-72: Two-level "Adjust" like Google Photos

Maintainer's request (D-71, with Google Photos screenshots): buttons first; a tap opens the slider, above it the categories to switch, number on the left, ticks filled up to the value (every 50 longer, reached = yellow, else grey), reset, "Done" goes up a level — all at the bottom, with our dots for changed values. Built:
- "Adjust" with no slider selected shows only the round buttons (dot if changed).
- Selected: category bar (selected one yellow, scrolled to centre, dot on changed ones), below it `Ruler` as a **pill** (`pill: true`): number left (yellow once ≠ 0), ticks from 0 to the value yellow, every 10th tick (= 50) long, reset on the right; below that "Done" (yellow) instead of the tabs. Double-tap on the ruler still resets to 0.
- The crop angle ruler and filter strength stay unchanged.

**Verified** 2026-09-24 in the emulator (screenshots): overview with buttons and tabs; "Shadows" → bar, pill, "Done"; dragged to 100 — all ticks to the value yellow, the 50 tick long, dot on "Shadows"; reset → 0, dot gone; "Done" → overview with tabs. App version `0.1.0-dev.72`.

---

## 2026-09-24 · D-71: "Enhance" as a toggle and in multi-select; presets bar

Maintainer's findings on the Pixel (compared with Google Photos, 2026-09-24): "Enhance" doesn't show whether it's on; custom presets sat behind "Save" — illogical; "Enhance" missing from multi-select. Also: sliders at ±100 much weaker than Google's, "Adjust" should be two-level like Google, edit and save presets (→ ROADMAP).

Built:
- **Toggle:** "Enhance" computes once per photo; shown selected (also for screen readers, `Semantics.selected` on all round buttons) while the sliders hold exactly its values; tapping it when selected resets those sliders to 0.
- **Bar:** Enhance, Save │ custom presets (vertical divider).
- **Multi-select:** at the top of the picker sheet "Enhance — computed per photo", presets below; no longer aborts without custom presets. Each photo gets "Enhance" from its original (`optimize` with bytes, natively the same steps as the editor preview: ≤ 2048 px, then 256 px). `withOptimized` and `optimizedKeys` in `recipe.dart`, used by editor and multi-select (tested).

**Verified** 2026-09-24 in the emulator: toggle on → selected, "Save" enabled; off → not selected, nothing to save; on again. Multi-select `optimize-dunkel.jpg` and `optimize-blau.jpg` → recipes **identical** to the editor's (D-70): white point 1.0 / brightness 0.39 and white point 0.16 / warmth 0.33 / tint 0.07. Finding: two copies "optimized" via multi-select were treated as originals (`… .edit (1).edit.jpg`) — the test photos have no EXIF date, and the device finds the original by checksum **and** capture time; camera photos have the date. App version `0.1.0-dev.71`.

---

## 2026-09-24 · D-70: "Enhance"

Per ROADMAP (maintainer's idea, D-62): first entry under "Presets", like Google Photos' "Auto"; sets only existing sliders, editable afterwards under "Adjust", undo reverts it. `Optimize.kt` reads the editor preview scaled to 256 px; formulas mirror `Renderer.kt`:
- **Black/white point:** darkest and brightest 0.5 % moved halfway to the edge — a flat but good photo stays close, a dark one gets the full range.
- **Brightness:** only if the median (after stretching) is outside 0.35 … 0.6, 70 % of the way.
- **Warmth/tint:** over near-grey pixels (brightness 0.15 … 0.9, colour distance < 0.2; at least 5 % of the image), in linear light, **only outside a natural range** — R/B 1.0 … 1.25, G 0.95 … 1.1 of the red-blue mean — up to its edge. Tuning finding: plain grey world (first draft, damped) would have cooled the good, warm test photo by warmth −0.38.

A second tap computes from 0, not on top. If it sets nothing: hint "Das Foto ist schon ausgewogen" ("The photo is already balanced").

**Verified** 2026-09-24: JVM test `OptimizeTest` (6: neutral → nothing, dark → brighter, blue and green cast, warm evening stays warm, vivid colours stay). Acceptance in the emulator with test photo B (SDR) and two derived versions (two stops darker; blue cast R × 0.8, B × 1.25 linear), optimized and saved in the app; values from the copies (brightness median, R/B over grey pixels):

| Test image | Recipe | Median | R/B |
|---|---|---|---|
| good | white point 0.12 | 0.368 → 0.375 | 1.22 → 1.21 |
| too dark | white point 1.0, brightness 0.39 | 0.183 → 0.304 | 1.03 → 1.13 |
| blue cast | white point 0.16, warmth 0.33, tint 0.07 | 0.363 → 0.371 | 0.90 → 0.96 |

Limits: the white-point slider stretches at most 15 % — the dark image doesn't quite reach the original's median (0.37); warmth brings the blue cast to neutral (R/B 1.0 in grey pixels), not back to the original warmth. The maintainer accepts the filters (D-62) "for now" (2026-09-24). App version `0.1.0-dev.70`.

---

## 2026-09-24 · D-69: Drag handle on the viewer's info panel

Maintainer's request: close the info panel via a handle like Google Photos, instead of swiping on the image hoping it works. Built: Material 3 sheet handle at the top of the info panel (32 × 4 pt, `onSurfaceVariant` at 40 %); the panel follows the finger down (shrinks, photo grows), closes at 60 pt or on a fast drag (> 300 pt/s), otherwise springs back. For screen readers a "Close" button.

**Verified** 2026-09-24 in the emulator: slow 24 pt drag — info stays; 160 pt — info closes. App version `0.1.0-dev.69`.

---

## 2026-09-24 · D-68: Paging like Google Photos — neighbours preloaded, placeholder, gap

Maintainer's finding: you swipe faster than the next photo loads and briefly see black; in Google Photos the previous and next pages are already loaded, a thin black gap separates photos while swiping, and only extremely fast swiping shows a blurry image. Measured 2026-09-24 on the Pixel (`0.1.0-dev.67`, recording as in D-67, 35 s, maintainer paged about 5 photos/s): **71 drops**; in the frames the incoming page shows the loading spinner — its photo loads only when it enters view (`PageView` builds only visible pages).

Built:
- `allowImplicitScrolling`: previous and next pages stay built, their photos load ahead.
- Under the full image a small one that is available immediately: 160 px for device photos (`photo_manager`), the gallery thumbnail for server photos (disk, D-55; `serverThumbnail` in `tiles.dart` made public). If you outrun the full image, you see the photo blurry instead of black.
- 16 pt gap: each page is wider than the screen by the gap (`OverflowBox`), the photo inset by half the gap — at rest it fills the width, while swiping black shows between.

**Verified** 2026-09-24 in the emulator: full width at rest; mid-swipe (screenshot) gap on the right and next photo already loaded. Tests green (27). On the Pixel, maintainer's verdict: "jetzt ist es top" ("now it's great", 2026-09-24); this also confirms D-67. App version `0.1.0-dev.68`.

---

## 2026-09-24 · D-67: Viewer no longer flickers while paging

Maintainer's finding after D-66: fast paging flickers — preview, briefly black, then back. Measured 2026-09-24 on the Pixel (`0.1.0-dev.66`): screen recorded with `adb shell screenrecord` (25 s, 540 × 1170), every frame analysed with PyAV — a strip of the image centre > 85 % black, not before and after: **17 drops of 30–120 ms in 9 s of paging, one per swipe**; in the frame the incoming page is black, the previous one still visible. Cause (D-66): the image area's key (`GlobalKey`) moved to the new page on page change, and only the current page got the zoom wrapper — both make Flutter rebuild the page content, so the device photo reloads (`FutureBuilder`, `Image.memory`).

Changed: each page has its own fixed key and always the same wrapper (`Zoomed` with `ValueListenableBuilder`); pages not in front are bound to `noZoom` (always 1).

**Verified:** widget test `zoom_test.dart` counts how often a page's content is created — before 3 for two pages and one change, now 2. Confirmed on the Pixel with D-68. App version `0.1.0-dev.67`.

---

## 2026-09-24 · D-66: Custom zoom in the viewer instead of `InteractiveViewer`

Maintainer's finding after D-65: swiping perfect, but two-finger zoom no longer works. Cause (reproduced in a widget test): the first finger drifts before the second lands; from 18 px paging claims it, and zoom lacks a finger. And the second finger never reaches the page — while a list scrolls, Flutter disables its children's touches (`Scrollable`, `IgnorePointer`). Thresholds can't solve the race; before D-65 zoom usually won the first finger, but stole the swipes.

Built: `PinchZoom` (`lib/gallery/zoom.dart`) wraps the pages and works on raw pointer events (`Listener`), outside the gesture arena: pages keep every swipe; when a second finger lands, pages stop (a started movement springs back) and the pinch zooms, even with a finger paging already had. Zoomed, one finger pans (image covers the area, no black edge); unzoomed, vertical swipes on the image open/close the info. The page shows magnification via `Zoomed`; only the current page zooms, reset to 1 on paging. `InteractiveViewer` and the D-65 threshold are removed.

**Verified** 2026-09-24: widget test `zoom_test.dart` — one finger pages, a pinch zooms (> 1.5×) even after the first finger drifted 40 px into a page movement, the page springs back; swipe up/down reports the direction. Emulator: swipe up opens the info, 3 of 3 fast swipes over the image page. Pinch on the Pixel: checked by the maintainer. App version `0.1.0-dev.66`.

---

## 2026-09-24 · D-65: Viewer paging — zoom no longer steals swipes

Maintainer's finding on the Pixel: without the info panel, paging resists — one swipe isn't enough, only "hold and swipe"; once moving it works; with info open it's smooth.

Measured 2026-09-24 on the Pixel (`0.1.0-dev.65` with temporary log lines, `adb logcat` read only, maintainer paged for 90 s): `InteractiveViewer` (zoom) took **35 of 88 swipes** as a one-finger gesture (`onInteractionStart`, about 0.1 s, no page change); 53 paged. With the HDR overlay view (D-54) on top, 20 swallowed vs 6 paged; without, 15 vs 47. Cause: zoom claims a finger from 36 px movement (`kPanSlop`), paging from 18 px; when moves arrive in coarse steps (apparently more often with the native view), both cross in the same event and the deeper zoom wins. While the page animation runs, paging catches the next swipe — hence "once moving it works". With info open you swipe on the info, outside the zoom. Reproduced in the emulator with 120 ms `adb` swipes: none over the image paged, all over the header did.

Changed: while not zoomed, zoom gets `touchSlop` 60 (one-finger threshold 120 px instead of 36); two-finger zoom (own threshold) and swipe-up for info stay. When zoomed, normal thresholds apply for panning.

**Verified** 2026-09-24: emulator — 4 of 4 fast swipes over the image page, no zoom; swipe up/down opens and closes info. Pixel, maintainer paged for 75 s: **73 page changes, 0 taken by zoom** (3 with HDR overlay on top). Log lines removed again.

---

## 2026-09-24 · D-64: Viewer shows Ultra HDR; HDR button only where there is HDR

Maintainer's finding: "Ultra HDR" was off in the Pixel camera; with an Ultra HDR photo the button (D-63) works. Request: see in the info whether a photo is Ultra HDR, and no HDR button on other photos. Built with the same check as D-63 (gain map of the on-device original, once the page settles): the info appends "Ultra HDR" to resolution and size; the viewer button appears only then — also when HDR is off, so it can be turned back on. Server-only photos count as unknown (no hint, no button) until the viewer loads their originals (ROADMAP). Gallery and editor keep their button.

**Verified** 2026-09-24 in the emulator: `preset-10.edit.jpg` (copy with gain map, on device) — "12.5 MP · 3072 × 4080 · 2.9 MB · Ultra HDR" and button "HDR on"; the original `preset-10.jpg` (server only) — no hint, no button. App version `0.1.0-dev.64`.

---

## 2026-09-24 · D-63: Viewer — HDR only with a gain map, info stays open while swiping

Maintainer on the Pixel (`0.1.0-dev.62`): the viewer's HDR button only looks "like sharpening", zoomed in nothing; swiping pauses after each photo; with info open, no swiping.

Measured (read-only `adb`): viewer window in standard mode, display `hdrSdrRatio 1.0`. The photo and **all 61 newest JPEGs** in the camera folder have no gain map (`grep -c hdrgm`; cross-checked on an Ultra HDR copy: 12 hits) — the camera's "Ultra HDR" is probably off. The "sharpness" was the native view (D-54) laying even SDR photos at full resolution over Flutter's 1440 px preview (hidden on zoom by design). It was created and fully decoded for **every** resting photo — likely the swipe pause.

Changed:
- Native view only for photos **with a gain map**, checked natively (`hasGainmap`): `ImageDecoder` at 1/16 size still reports it. Scanning the header for `hdrgm` isn't enough: ISO 21496-1 files carry it only in the second image (`geraet-preset.jpg`: MPF at byte 638, `hdrgm` at 2.4 MB; libvips sees Ultra HDR, Android sees no gain map even fully decoded).
- Native view only after the page **rests 300 ms**.
- **Info inline** instead of a modal sheet: swipe up or ⓘ opens it below the photo (max 40 % height, scrollable), swipe down or ⓘ closes; stays open while swiping, for comparing.
- Log `immich_editor: hdr window on/off`.

**Verified** 2026-09-24 in the emulator: gain-map device photos → `true`, copies → `false`; "hdr window on" only for the former, button toggles off/on. Swiping with info open `preset-10` → `-07`, info follows. Very fast `adb` swipes (120 ms) over the image don't page (the zoom `InteractiveViewer` wins the gesture arena with few large steps), over the header or at 400 ms they do; the maintainer judges the finger case. Gain map check: 1.8 s per photo in the emulator, in the background after the rest. App version `0.1.0-dev.63`.

---

## 2026-09-24 · D-62: Filters (3D LUT), own looks

Agreed with the maintainer (2026-09-24): **own looks**, no third-party LUTs; recipe stores only **ID and strength**; "Enhance" ("Optimieren") becomes a separate first entry under "Presets" (like Google Photos' "Auto"; "Dynamic" too strong). **Sharing** (preset/LUT files, public rated server) stays an idea, not M2.

Image Toolbox (Apache-2.0, source checked 2026-09-24): its built-in 512×512 LUTs carry Photoshop "Color Lookup" names (Bleach Bypass, Candlelight, Drop Blues, Edgy Amber, Fall Colors, Filmstock 50, Foggy Night, Kodak 5218) — probably Adobe's, not free; `ImageToolboxRemoteResources` has no license; only Amatorka is from GPUImage (BSD). Nothing taken.

Built:
- **Eight looks** (Vivid, Warm, Cool, Film, Faded, B&W, Noir, Sepia), generated by `tool/make_luts.py` as `.cube` (17³, 100 KB each) into `android/app/src/main/assets/luts/`. IDs are versioned (`warm@1`); a changed look gets a new ID so old recipes don't change.
- **Renderer:** `Lut.kt` reads `.cube` into a strip of 17 slices; the AGSL shader interpolates trilinearly (GPU filters red/green, shader blends blue between slices). Runs **after the sliders, before the vignette**, `mix`ed by strength. Unknown ID (newer app's recipe): no filter, no error.
- **HDR:** applied to the SDR image; gain map unchanged. With a single-channel gain map (Pixel) B&W stays grey in HDR; three-channel might reintroduce color — untested, no test image.
- **Recipe:** `"filter":{"id":"bw@1","strength":0.8}`, only if strength > 0. **Presets** carry the filter; a preset without one removes it.
- **Editor:** "Filter" tab after "Adjust" (Spec, *Bedienung*): "No filter", then round 192 px previews of the photo per look (ring marks the choice); choosing one shows the 0 … 100 strength ruler.
- Previews in **one** GPU pass as side-by-side tiles: individually 9.5 s in the emulator (~1 s per look, mostly `HardwareRenderer`/`ImageReader` setup; LUT read 50–150 ms), together **2.7 s** from tab switch (log `editor: filters after`), once per editor session.

**Verified** 2026-09-24, emulator, test user: `preset-11` (Ultra HDR, server only) with Warm — mean R/G/B 99/91/91 → 100/88/83; saved with B&W: `preset-11.edit.jpg` in the camera folder, recipe `{"v":1,"filter":{"id":"bw@1","strength":1.0}}`, libvips (`uhdrload`) sees Ultra HDR, single-channel gain map (697×926), SDR colorless (max channel difference 0). Tests: 24 Flutter (new: filter in recipe/preset), 12 JVM (new: `.cube` parsing, all eight looks, B&W grey), 13 GPU (new: B&W, half strength, Warm, unknown ID). App version `0.1.0-dev.62`.

---

## 2026-09-24 · D-61: Device folders by app

Maintainer: Obsidian's many attachment folders each show separately; wanted: hide a whole app or some subfolders, with app icon and name. Pixel (`content query`, `owner_package_name`): Android records each image's creating app — Google Camera 9,347, a camera companion app 3,148, Google Photos 2,235, system (screenshots) 964, WhatsApp 902, Obsidian (`md.obsidian`) 70, 467 none (cable/sync).

Built: native `folderOwners` (the app that created ≥ 60 % of a folder's images, else none) and `appInfo` (name, PNG icon). Manifest `<queries>` for launcher apps, not the broad "query all packages" permission. Settings → Device folders → Library has "Folders | Apps": each app with icon, name, "3 folders · 1 hidden", one eye for all its folders, expandable with per-folder eyes; unclear folders under "Other and unknown". Writes the same hide list as D-59. The Library itself doesn't group. App version `0.1.0-dev.61`.

**Verified** 2026-09-24 on the Pixel: names and icons load (Bimostitch Pro, Camera Connect, ChatGPT, Day One, eBay, Photos (4 folders), PhotoScan, Instagram, Camera (2 folders) …). Obsidian is further down and `adb` can't scroll there (D-50); the maintainer checks it.

---

## 2026-09-24 · D-60: Device folders on two pages

Maintainer: "Show under 'Photos'" and "Library" (62 folders each on the Pixel) on separate pages instead of one long one. Settings → Device folders now has two entries, each opening its list; hint text on top, title in the app bar. App version `0.1.0-dev.60`.

**Verified** 2026-09-24 in the emulator: both entries; "Library" shows sort option and list with eye, pin, handle (Test15 pinned on top).

---

## 2026-09-24 · D-59: Pin, arrange, hide device folders

Maintainer: favorites pinned on top, others arranged manually, the rest below alphabetically or by recency; hiding in the same menu. Settings → Device folders → **Library**: per row an eye (closed: greyed, not in Library), a pin and a drag handle; above, "Rest: newest first / A–Z". `arrangeFolders` (tested) orders pinned, arranged, rest. Dragging a folder also fixes everything above it; existing arranged/pinned entries keep their place (`orderAfterMove`, tested). Stored as `pinnedFolders`, `folderOrder`, `folderSort`, `hiddenFolders`.

Deviation: Flutter's `SliverReorderableList` shows a gap and an accent border, not a colored line — but it auto-scrolls while dragging (62 folders on the Pixel); a line would mean building both ourselves.

**Verified** 2026-09-24 in the emulator (20 folders): Test15 pinned → on top; Test13 hidden → greyed, gone from Library; Test12 dragged after Test5 → "Test15, Camera, Privat, Screenshots, Test1 … Test5, Test12, Test6 …".

---

## 2026-09-24 · D-58: HDR button everywhere, can be turned off

Maintainer: HDR toggle in gallery, viewer and editor, hidden everywhere only if disabled in settings — a first step towards customizable buttons. Shared state in `lib/hdr.dart` (`hdrOn`, `hdrButton`, read at startup like the language), one `HdrButton` widget; the editor listens and switches the renderer. Settings → Editing: "HDR" and new "Show HDR button" (`hdrButton`).

**Verified** 2026-09-24 in the emulator: gallery toggle reflects in viewer and back; "Show HDR button" off → no button in gallery and viewer, on → back.

---

## 2026-09-24 · D-57: Library no longer jumps when scrolling up

Maintainer on the Pixel: scrolling up, the list jumps. Cause: folder rows loaded as one line and grew to two ("30 photos · …"); rows reloading above pushed the list. Now rows are two lines from the start and stay alive off-screen (`AutomaticKeepAliveClientMixin`), so counting a folder's photos (Camera: 7,519) also runs once. Installed on the Pixel (`3907d19`); smoothness is for the maintainer to judge.

---

## 2026-09-24 · D-54: HDR in the viewer; lens; M2 HDR acceptance on the Pixel

Built:
- **Viewer:** while a page rests unzoomed, a native view (`HdrImageView`, `immich_editor/hdr`) over Flutter's image draws the local original via `ImageDecoder` with gain map and EXIF rotation; with a gain map and "HDR" on, the window switches to HDR and back on leaving (a counter over all such views so editor and viewer don't switch each other off). Sources: device photos and server photos whose original is on the device (checksum). Server-only photos stay SDR — the viewer doesn't download originals.
- Creating the native view mid-swipe (`onPageChanged` fires halfway) left the page stuck between photos (Hybrid Composition). Now it goes away when a swipe starts and returns on `ScrollEndNotification`.
- **Gentle HDR ramp** (Android 15+): `desiredHdrHeadroom` goes from 1 to the display maximum over 0.5 s, then unlimited — editor and viewer.
- **Lens** for device photos: AndroidX `ExifInterface` instead of the framework one (has `LensModel`); already present via `photo_manager` (LICENSES.md).

**Verified** 2026-09-24 on the Pixel (release `3907d19`), test photo A (Ultra HDR) in a folder the Immich app doesn't back up, deleted afterwards:
- Viewer: `COLOR_MODE_HDR`, `currentHdrSdrRatio=4.99999` (desired 5).
- Editor: after rotate and square crop still `COLOR_MODE_HDR`, ratio 5. Saved "Device only": libvips 8.18.6 loads it with **`uhdrload`**, 3072 × 3072, content boost 4.6525 as in the original — **Ultra HDR with matching gain map**. With "HDR off": `jpegload`, no `hdrgm` — **SDR**. The HDR part of the M2 acceptance is met except for the visual judgment.
- Info (emulator, same file): "Google Pixel 7 Pro / Pixel 7 Pro back camera 6.81mm f/1.85 / f/1.9 · 1/231 s · ISO 47 · 6.8 mm".
- Emulator: swiping back and forth over several pages without getting stuck.

Pitfall: after a `system_server` restart in the emulator ("Binder buffer full") the launcher hung; restarting it helped. The emulator has no HDR; `dumpsys` shows no color mode there.

---

## 2026-09-24 · D-56: Noodle Gallery as server — verified

Local Noodle server in Docker, without touching the maintainer's library: compose from Noodle release `v5.7.0`, own project/container name, no machine-learning service, own DB password, data in `%USERPROFILE%\noodle-test` (STATUS). Admin and test user via API, test photo A (Ultra HDR) uploaded.

Findings and changes:
- Noodle reports `/server/version` **5.7.0**, `/server/about` `repository: open-noodle/gallery`. The app warned for every major version except 3; now Immich 3 or Noodle 5 count as known (`isKnownServer`) — a future Immich 5 still warns.
- The app blocked cleartext HTTP (Android default), so home servers without HTTPS failed. Now allowed like the Immich app (`usesCleartextTraffic="true"`, v3.2.2).

**Verified** 2026-09-24 in the emulator against `http://10.0.2.2:2283`: login without warning; timeline with server and device photos; account window with storage, "5.7.0" and address; editor with the original and gain map (HDR button); rotated and saved to the server → stack original + V1. Via API: copy on top, recipe in XMP, `hdrgm`, SHA-1 matches. Then back to the Immich test user, containers stopped.

---

## 2026-09-24 · D-55: Server thumbnails on disk

The gallery fetches server thumbnails via the keep-alive client (`Immich.thumbnail`) and stores them in Android's cache folder (`cache/thumbnails`); the newest thousand stay in memory so Flutter's image cache recognizes them. Scrolling back or reopening loads from disk. Failed fetches aren't cached (new copies get thumbnails only seconds after upload, D-31).

**Verified** 2026-09-24 in the emulator: 20 cache files after startup, all thumbnails shown. Limit: offline the timeline is empty — it needs Immich's month list, not cached yet.

---

## 2026-09-24 · D-53: Show pending edits individually

ROADMAP: show queued edits whose backup doesn't happen although the file exists (backup off, folder not backed up). Settings → Stacking lists each pending copy with thumbnail, file name and folder ("Copy in Pictures/Privat/ — not in Immich yet"); × removes it from the queue, the file stays. Copies are found by checksum in the stored device checksums.

**Verified** 2026-09-24 in the emulator: 7 pending copies, incl. `privat-test` from non-backed-up `Pictures/Privat`; × → "6 edits waiting", file still there.

---

## 2026-09-24 · D-52: "Open with" selectable; device folders by newest photo

Maintainer's decisions:

1. **"Open in Immich"** still uses Android's chooser with "Just once"/"Always" (Immich and Noodle Gallery both handle `immich://` on the Pixel, D-50). New: Settings → Saving → "Open edits with": "Ask Android" (default) or an app Android knows for `immich://` (`queryIntentActivities`, hence `<queries>` in the manifest). A fixed app overrides a wrong Android "Always". Stored as `openWith`.
2. **Folder order** as in the Immich app (`v3.2.2`, `providers/infrastructure/album.provider.dart`): `localAlbumProvider` sorts by `SortLocalAlbumsBy.newestAsset`; the perceived "importance" (Camera, then Screenshots) is recency. Adopted for Library and settings. The date comes from the all-photos list (newest first); photo_manager's first photo per folder isn't reliably the newest — the first attempt put Screenshots (Sept 22) before Camera (Sept 23).

**Verified** 2026-09-24 on the Pixel (release): Library "Camera, Screenshots, Telegram Images, Camera Remote, WhatsApp …"; "Open edits with" lists Ask Android, Immich, Noodle Gallery; selecting and resetting works.

---

## 2026-09-24 · D-51: Device photos right at startup

Maintainer: at launch only server stacks show, device photos ~3 s later. **Measured** 2026-09-24 on the Pixel (17,490 photos, profile build, timestamps): device photos after **5.6–6.2 s** — listing all photos 1.1–2.1 s, reading the checksum file < 0.1 s, `bulk-upload-check` as 18 sequential requests **2.7–3.3 s**, listing all photos again **1.1 s**.

Built:
- `existing` sends the 1,000-item requests concurrently.
- The sync reuses the checksum run's list (`lastListed`).
- Its result is cached in `backup.json` (device photos with date, size, folder, plus the cloud-icon sets). The gallery shows it immediately and swaps in the fresh sync; new photos appear after the sync.

**Result** on the Pixel: fresh sync after **2.3–2.8 s**; cached state **0.6–0.7 s** after tapping the icon (log `START` → state loaded), as the window appears — the screenshot at 1.5 s shows the full timeline.

---

## 2026-09-24 · D-50: Finding — "Open in Immich" on the Pixel

Checked 2026-09-24 on the maintainer's Pixel (release `9e61540`, as test user; the Immich app stayed on the main account at the maintainer's request):

- Test photo in `Pictures/EditorTest` (not backed up), rotated, saved → "Open edit in Immich?" → "Open in Immich": copy archived for the test user, in album "Editor for Immich".
- `immich://asset?id=…` opens Android's chooser: **Immich and Noodle Gallery** both handle it. Immich opens its timeline but can't find the test user's photo with the main account. The jump works; opening the photo needs the same account to verify.
- Cleanup: test folder deleted, copy in the test user's trash.

Side findings: Library lists 62 folders in ~1 s (Camera last). `adb` swipes don't scroll timeline or Library there, taps work; manual scrolling works (somewhat jerky in debug).

---

## 2026-09-24 · D-49: Finding — first checksum sync of a large library

Measured 2026-09-24 on the maintainer's Pixel 7 Pro (17,490 photos), `9e61540` debug build (checksums run in Kotlin, unaffected by debug): `checksums.json` moved aside, `dumpsys battery unplug`, `batterystats --reset`, app started.

- Explainer dialog (D-39): "1,960 of 17,490 photos · done in about 4 minutes".
- **Duration ~7½ min** (12:05:30 → 12:13:11), avg 39 photos/s, uneven (15–75 s per 1000) — the estimate was too optimistic, it tracks the first seconds' speed.
- **Battery: 10.4 mAh** per `batterystats` (3 min foreground, 4½ min background), ~0.24 % of 4,370 mAh; gauge stayed at 95 %.
- Continued with screen off and app in background.

Release build reinstalled; new file kept, old one deleted.

**Takeaway:** the first sync is an acceptable one-time cost; no need for WorkManager. The remaining-time estimate could average over a longer window.

---

## 2026-09-24 · D-48: Which device folders appear under "Photos" and in the Library

Maintainer: "Photos" mixed everything from the device (screenshots, downloads, messengers); Google Photos shows camera photos there. Wanted: choose folders for "Photos", hide folders from the Library.

- **Settings → Device folders**: checkbox lists "Show under 'Photos'" (default `DCIM/Camera/`) and "Hide in Library". A folder is its relative path, as used when saving; stored as `photoFolders`, `hiddenFolders`.
- "Photos" shows everything from the server (Immich timeline) and from the device only non-backed-up photos in the chosen folders. The "Device" view stays complete.

**Verified** 2026-09-24 in the emulator: `Pictures/Screenshots` with a photo without EXIF date — not under "Photos"; settings list Privat, Camera, Screenshots, Camera checked. Screenshots enabled, Privat hidden → "Photos" shows the photo on top, Library only Camera and Screenshots.

---

## 2026-09-23 · D-47: Swipe across month boundaries in the viewer

Swiping used to stop at the edge of the server photo's month. Now the viewer loads the adjacent month at the edge (`more` in `ViewerPage`, `_openAcross` in the gallery): older months appended, newer prepended with the page index shifted; video-only months skipped. Timeline and server view; the device view was already continuous.

**Verified** 2026-09-23 in the emulator: first October 2022 photo "Oct 30, 2022" → right → "May 3, 2026" → back → "Oct 30, 2022".

---

## 2026-09-23 · D-46: Stacking in the background

ROADMAP: stack without opening the app. Via Android **WorkManager** (plugin `workmanager`, MIT; AndroidX WorkManager, Apache-2.0; no Play services — [LICENSES.md](LICENSES.md)):

- A periodic task (Android minimum 15 min, network required) runs `stackPending` in an Activity-less Flutter engine. Scheduled when the queue gets an entry or still has one after a run; cancelled when empty.
- Without an Activity there's no renderer channel (checksums) and no delete dialog, so the background only stacks. Local copies due to leave the device (D-28) go into `deviceTrashLater`; Android asks once for all at next start. Only the foreground discards unreachable entries (D-45).
- Foreground and background may overlap (two isolates); double stacking is harmless.

**Verified** 2026-09-23 in the emulator: app on home screen, backup of `preset-11.edit (1).jpg` simulated. Forcing (`cmd jobscheduler run -f -n androidx.work.systemjobscheduler …`) is refused for periodic work ("executed before schedule"); the regular run came 14 min after scheduling: `Worker result SUCCESS` after 2.4 s, via API the copy on top of the stack with `preset-11.jpg`, replaced copy gone. At next app open Android asked to trash the local copy; then it was gone. Pitfall: `am force-stop` clears the app's scheduled work until the next start (swiping away doesn't).

---

## 2026-09-23 · D-45: Edit server photos locally if the original is local; discard unreachable entries

Extends D-24 ("original on the device: edit the local file, don't ask the server") from photos opened on the device to server photos.

- `loadPhoto` looks up the original's checksum (for a copy, from its recipe) in the **stored** device checksums (`deviceIdWithChecksum`; never computes, so the editor doesn't wait for a sync). On a hit it uses the local file if its SHA-1 still matches: full resolution and HDR at once, no server preview, the copy goes into the original's folder and is queued, as for device photos.
- `saveCopy` derives "on device" from the photo (`folder`), not the entry point. **Replace** also hits a server copy's local twin (by checksum; Android asks); the server part is trashed during stacking.
- **Queue:** after stacking, entries that can never arrive (copy or original neither on server nor device; `unreachable`, tested) are dropped. Only a checksum run started after reading the queue counts, else a just-saved copy would be lost; without photo access nothing is dropped. A present but non-backed-up copy keeps waiting.

**Verified** 2026-09-23 in the emulator: top copy of stack `geraet-preset` (original also local) — image after 1.4 s instead of 2 s; saved `geraet-preset.edit (1).jpg` to the camera folder, no upload. Stack `preset-11` (original server-only, old copy also local) → "Replace copy" → Android asks, old file gone, new one present. Queue: 10 stays 10 (all copies local); `testfoto-a-lokal.edit.jpg` deleted → 9.

---

## 2026-09-23 · D-44: A copy opens in 2 s

ROADMAP: opening an older copy from the viewer took "about 8 s". **Measured** 2026-09-23 in the emulator (debug build, tap "Edit" to image, externally via `adb` plus debug-log timestamp `editor: image after … ms`): before **2.5–2.9 s** (top copies 2.5/2.7 s, older copy V1 2.9 s) — the 8 s was an older build. Steps: details and file head 0.1–0.5 s each, finding the original 0.1 s, **Immich's preview ~1.1 s** — the largest item.

Built (`loadPhoto` in `lib/editor/save.dart`):
- Details and file head concurrently; for a copy, the original's details and preview concurrently. The original's file head is no longer loaded (never used). Settings and presets load alongside.
- The preview starts as soon as details show a name not looking like a copy (`.edit`) — only a prefetch guess; the XMP recipe still decides.
- Rejected: always prefetching the preview (the copy download crowded other requests, 3.0–3.3 s); longer idle connections (Dart default 15 s) — no effect.
- Parallel requests are awaited individually so network errors surface as themselves, not `ParallelWaitError`.

**Result**, two runs: top copies **2.0–2.3 s**, older copy V1 **1.9–2.0 s**, original 1.8–2.0 s — acceptance (< 3 s) met. An opened copy is still recognized (⋮ "Go to saved edit").

---

## 2026-09-23 · D-43: Display language German and English

Maintainer: app usable internationally — language follows the device, German and English first, switchable in settings.

- Flutter's standard: `flutter_localizations` (SDK) and `intl`, both BSD-3-Clause ([LICENSES.md](LICENSES.md)); strings in `lib/l10n/app_en.arb` (template) and `app_de.arb`, 147 keys, ICU plurals; `flutter gen-l10n` generates `AppLocalizations`.
- Settings → **Language**: "Device language" (default), Deutsch, English; stored as `language`, kept on logout. Other device languages get English.
- Widgets use `AppLocalizations.of(context)` and rebuild on switch; context-free code (errors, save steps) uses `l10n` from `lib/language.dart`.
- Dates, months, weekdays, numbers via `intl` instead of German lists ("Mi., 23. Sept. 2026 · 12:00", "f/1,9" vs. "f/1.9").
- The emulator app is set to German, since `tool/emu.sh` matches German strings.

**Verified** 2026-09-23: widget test — English device → "Log in", switched to German → "Anmelden" without restart; `fr` → English. Emulator (English device): gallery and account window English ("8 edits are waiting for the backup"); Settings → Language → Deutsch → German at once, including the page below; still German after restart; viewer info with German date and decimal comma.

---

## 2026-09-23 · D-42: Code in English

Maintainer's request: all file names, identifiers and comments in English — Dart, Kotlin (incl. AGSL shader), tests, `tool/emu.sh` (`tap`, `shot`, `open_photo` …), `doccheck.py`. Docs stay German until translated (D-15); older entries use old names.

- Persisted names stay, so installs (Pixel) lose nothing: `flutter_secure_storage` keys and values (`hdr`, `mobil`, `online`, `zusammen`, `stapeln` with `kopie`, `original`, `alt`, `entfernen`), marked `// persisted: do not rename`.
- Never shipped, renamed: `abgleichErklaert` → `checksumsExplained`, `presets.json` field `rezept` → `recipe`, `pruefsummen.json` → `checksums.json` (renamed on first read).
- Stack type: `PhotoStack` (`Stack` is Flutter's widget).
- Next: UI language follows the device, German/English, switchable (ROADMAP).

**Verified** 2026-09-23: `flutter analyze` clean, 18 Flutter + 9 JVM tests green; emulator: gallery, editor (shader, HDR button after original), save as copy with recipe and `hdrgm`, `checksums.json` migrated. `RendererTest` (instrumented) compiles, not run (uninstalls the app).

---

## 2026-09-23 · D-41: The rulers' zero point is visible

Zero snapped with haptics but was barely visible. Now on all rulers (sliders, angle) a thick amber tick with dot, distinct from the blue center. Center drawn first; at 0 the zero lies on top, center turns amber.

**Verified** 2026-09-23, emulator: brightness 32 → zero visible left of center; dragged to 0 → snaps, center amber.

---

## 2026-09-23 · D-40: Presets — save in the editor, apply to a multi-selection

Per spec (*Presets*: recipe without geometry or masks):
- **Editor**, tab **"Presets"** first (spec, *Bedienung*): "Save" asks a name, stores changed sliders; tap applies sliders (crop, rotation kept); long press deletes (confirmed). Names, not thumbnails — the renderer does one image at a time.
- `presets.json` in the app folder (recipe JSON, `v: 1`), not `flutter_secure_storage` (cleared on logout).
- **Gallery**: long-press multi-select → ✨ "Apply preset" → progress "3 of 20 photos". Same path as the editor: `lib/editor/speichern.dart` (`fotoLaden`, `kopieSpeichern`). Native export takes the original as bytes, no editor session.
- A selected **copy by this app** is **replaced** (original + its crop + preset sliders; old copy to trash) — D-31 default, no per-photo prompt. Failures don't stop the rest; message gives the count.

**Acceptance (M2) measured** 2026-09-23, emulator, test user: preset "Contrast" on 20 photos — 19 server (8 edited stacks, 11 new `preset-01` … `-11`) + device-only `geraet-preset.jpg`. **233 s** (~12 s/photo: load original, render, write to camera folder, default "via device", D-28); 20 copies, no errors, each with recipe and `hdrgm`. Backup simulated (unchanged via `POST /assets`); after restart, by asset ID: **20/20 copies on top of the stack with their original**, incl. `geraet-preset.edit.jpg`; replaced copies in trash.

---

## 2026-09-23 · D-39: The first checksum scan explains itself

On the Pixel, first launch showed only "6000/17400" next to the avatar, unexplained. Built:
- First scan (D-36) opens a **"Photo scan" dialog**: one checksum per photo to see what's in Immich (clouds); first time only, then new photos; nothing uploaded, only checksums sent. Bar, "200 of 1,211 photos", ETA. Once per install (key `abgleichErklaert`); closes when done.
- **"In background"**: progress ring around the avatar (like Immich's backup), "Photo scan" section in the account dialog. App-bar number removed.
- Shared state `abgleichStand` (`ValueNotifier`) in `pruefsummen.dart` replaces the callback.

**Verified** 2026-09-23, emulator: `pruefsummen.json` deleted, 400 then 1,200 test-photo copies in `DCIM/Abgleichtest`. First launch → dialog, "0 of 411 photos", auto-closes. Second run (1,211, no dialog) → ring; account dialog "200 of 1,211 photos · done in about 2 minutes"; then ring and section gone, 1,211 entries. Test photos deleted.

---

## 2026-09-23 · D-38: Alongside the Immich app without confusion; Immich as the source

Maintainer's guidelines:

1. **Coexist with the Immich app.** Never modify existing device files; only create and delete own copies (deletion confirmed by Android). Only the server is shared; each app keeps its own checksums (ours: `pruefsummen.json`). Unchanged originals mean no rescans — the Immich app sees a copy as a new camera photo. Checksums match because both read the unmodified file incl. location (`ACCESS_MEDIA_LOCATION`, D-26). Server assets of the Immich app are only stacked and added to albums.
2. **Immich as information source** where simple: public API (timeline, stacks, EXIF, place names, storage, users, `bulk-upload-check`). The Immich app's phone DB is unreachable (sandbox, no ContentProvider) — hence own checksums (D-36; device ID rejected as too unreliable). No local copies of data Immich serves.

**Apply:** before computing or storing anything, check `open-api/immich-openapi-specs.json` (tag `v3.2.2`) for whether Immich provides it.

---

## 2026-09-23 · D-37: All editing happens here — Immich is gallery and backup

Agent proposal: save geometry-only edits (crop, 90° rotate, flip) via `PUT /assets/{id}/edits` on the original, like Google Photos' reversible edits. Maintainer: **no.** All edits are made here and saved as a copy with recipe (D-2); Immich is gallery and backup, no switching editors.

**Apply:** don't propose Immich's editing features; new tools go into the recipe.

---

## 2026-09-23 · D-36: One timeline across device and server; folders Immich doesn't back up

Maintainer's decisions: **one timeline** with cloud icons like the Immich app, split only via setting. Device photos are backed up if the server knows their **checksum** (not device ID). Photos in folders the Immich app skips can be edited; then the app **asks**, optionally uploads **archived** to album "Editor for Immich" and opens it in the Immich app. Folders: **"Library"** tab.

Built:
- **Checksums** native (`MainActivity`, own thread, streamed, `setRequireOriginal`), cached in `pruefsummen.json` with mtime; only new/changed recomputed (`abgleichen`, tested). Lookup via `POST /assets/bulk-upload-check`, batches of 1000 — finds archived, not trashed. Stacking (D-26) uses it too: one request instead of three per copy.
- **Timeline** "Photos": server months + device-only photos, merged by `fileCreatedAt`. Cloud as in Immich's `thumbnail_tile`: `cloud_off` device, `cloud` server, `cloud_done` both. App bar shows checksum progress. Settings → View: "Device and server together" off → tabs "Device", "Immich", "Library".
- **Library**: "On this device", folders with count and backed-up share; open, view, edit.
- **Not backed up** = neither original nor any other folder photo (up to 200) on the server. After save: "Open edit in Immich?" → `POST /assets` with `visibility: archive`, verify, album (created if missing), `immich://asset?id=…` (Immich's `deep_link.service.dart`).
- Limit: archived copies aren't in the timeline (as in the Immich app), only album and folder.

**Verified** 2026-09-23, emulator: server stacks (cloud), device photos (crossed cloud), backed-up test photo B stack (check), no duplicates; library "Camera · 9 photos · 2 backed up". `Pictures/Privat` photo edited → prompt → copy in folder and archived on server (same SHA-1), album with 1 photo. Immich-app jump only testable on the Pixel.

---

## 2026-09-23 · D-35: Immich app look, Google Photos interaction

Guideline: **Immich app design** (colors, font, account dialog, settings), **features and key areas from Google Photos** (black editor, bottom tools, D-22; viewer, stacks, D-33, D-34).

From Immich app source (tag `v3.2.2`, AGPL-3.0, D-3):
- **Theme** (`lib/thema.dart`): brand `#4150AF` / dark `#ACCBFA`, desaturated surfaces, text sizes, brand-colored AppBar title, **Google Sans** (SIL OFL 1.1, `fonts/GoogleSans/` + `OFL.txt`). Editor and viewer dark, editor on black.
- **Account dialog** like `ImmichAppBarDialog`: close + name; card with profile (avatar like `UserCircleAvatar`, Immich colors), storage (quota, else `GET /server/storage`), app and server version, server URL; then pending edits, settings, log out (confirmed), licenses. Not taken: Immich logo (trademark, D-5), avatar upload, app log, "Free up space".
- **Settings** like `SettingsPage`: card per section (Editing, Saving, Network, Stacking), `SettingsSwitchListTile`-style switches.
- App version via platform channel (`PackageManager`), no dependency.

**Verified** 2026-09-23, emulator: brand-color title left; "104.4 MiB of 10.0 GiB used", "0.0.1 build.1", "3.2.2", server URL, "6 edits waiting for backup"; settings as cards.

---

## 2026-09-22 · D-34: Stacks in the viewer like Google Photos' long exposures

From a Google Photos screenshot: date and local time on top, shown version below; stack thumbnails under the image. Order **Original, V1, V2 …** (copies by `createdAt`), primary starred. ⋮ on a thumbnail: **"Set as primary"** (`PUT /stacks/{id}`) and **"Keep this photo, delete the rest"** (confirmed; rest to Immich trash, `DELETE /stacks/{id}`). No multi-select — not needed.

**Verified** 2026-09-22, emulator, `testfoto-a-hdr` (original + 2 copies): V1 primary → server confirms; keep original → copies in trash, no stack, date still shown. Test data restored.

Bugs: `setState(() => _x = future)` returns the Future, Flutter aborts — use a block; "delete the rest" reloaded from the deleted copy — now from the shown photo.

---

## 2026-09-22 · D-33: Viewer between gallery and editor

Maintainer: view first, then edit, see the result after saving. Sharing, albums, trash, map stay in the Immich app.

Tile tap → viewer: swipe (device: all; server: the month, for now), zoom to 8×, server stack members at bottom ("Original", "Edit", "Edit 2", by `.edit` in the name). "Edit" opens the shown member; the new copy comes back and is shown. Swipe up: date/time, name, MP, dimensions, size, camera, lens, exposure, location — server: Immich's `exifInfo` (`localDateTime`, city/country); device: Android `ExifInterface` via platform channel, place from Immich's `GET /map/reverse-geocode` (server's own geodata, no third party). No raw coordinates (meaningless, maintainer). ISO is `ISOSpeedRatings` in the framework. No dependency.

Pitfall: `InteractiveViewer` swallows swipe-up from `GestureDetector`; handled in `onInteractionEnd`, unzoomed only.

**Verified** 2026-09-22, emulator: 3-member stack, info (Google Pixel 7 Pro, f/1.9 · 1/231 s · ISO 47 · 6.8 mm, <place>), swipe to next; Edit → "Replace copy" → new copy shown; device photo EXIF.

---

## 2026-09-22 · D-32: Avatar, account and a settings page

A device edit was backed up but never stacked: the app used the test user, the Immich app the maintainer's account — stacking only happens in the app's account (D-26). Nothing showed this.

So, like the Immich app: avatar top right (`GET /users/me`, `GET /users/{id}/profile-image`; else initial on `avatarColor`). Tap: name, email, server, edits awaiting backup (the Immich app must back up with this account), "Log out", "Settings". Settings on their own page (Editing, Saving, Stacking with "Stack now", Account) instead of ⋮.

**Verified** 2026-09-22, emulator: blue "E", "3 edits waiting for backup", all switches.

---

## 2026-09-22 · D-31: Replace a copy or save alongside; thumbnails of new copies

Pixel feedback (build `1a96574`): saving works, the old ANR (D-23) is gone. Google Photos makes a new loose copy each time a copy is edited — messy; usually you want to change that copy.

Decision: saving an opened copy (original + its recipe, D-23) offers **"Replace copy"** (old to trash, D-23) or **"Save as another copy"** (both stacked). Immich files are immutable (D-1): "replace" = new copy on top, old in trash, reversible. Edits stay reversible since the original is in the stack.

Stacking (Immich `v3.2.2`, `server/src/repositories/stack.repository.ts`, `create`): `POST /stacks` merges an existing stack only if its **primary** is in `assetIds`; otherwise only the named asset moves. So the app sends `[new copy, original, previous primary]`, keeping one stack; deleting the previous primary (D-23) is dropped.

Black thumbnail: Immich generates it seconds after upload; the tile stayed empty. Now retries every 2 s (max. 10).

**Measured** 2026-09-22, emulator (direct to server): `testfoto-a-hdr` → "Save as another copy" → new copy, original, older copy; thumbnail immediate. Then "Replace copy" → newest, original, older; replaced one in trash.

---

## 2026-09-22 · D-30: "Mobile data" setting

Follows D-24: gallery ⋮ "Originals and uploads over mobile data", default on. If off and metered (`isActiveNetworkMetered` via platform channel, needs `ACCESS_NETWORK_STATE`, no dependency), the editor doesn't auto-load originals and asks once on save if an original or direct upload is pending. Thumbnails, previews, API calls always run; on-device copies are backed up by the Immich app.

**Measured** 2026-09-22, emulator: off, Wi-Fi off (metered) → preview, no original after 15 s (no HDR button); save → prompt; "Anyway" → full-res copy (3072 px wide).

---

## 2026-09-22 · D-29: Open online photos with Immich's preview; HDR only in the image

For server photos the editor first loads details, the first 64 KB (EXIF, recipe XMP — identifies copies) and Immich's preview (`GET /assets/{id}/thumbnail?size=preview`, upright, no gain map), shown at once. The original loads in the background and replaces it in the renderer with the current recipe (no flash); then HDR. Save waits for the original ("Loading original …"); copies always come from it. Recipe is resolution-independent, same aspect ratio.

**Measured** 2026-09-22, emulator (debug, `testfoto-a-hdr`, 4.6 MB): image after 2.6 s (before: only with original), HDR button after 10.4 s. Saved before the original arrived → 3072 × 4080 with `hdrgm`, MPF, recipe.

**Pixel** (maintainer, 2026-09-22): HDR only brightens the image, not bars or buttons — intended (D-17, D-20).

---

## 2026-09-22 · D-28: Online photos backed up via the device — built

Follows D-25: gallery ⋮ "Back up edits of online photos via the device", default on (`online` = `geraet`/`server`). Copies of server-only photos go to `DCIM/Camera/`, recorded by device ID. Stacking after backup (D-26) sends replaced server copies to Immich trash and the local copy to device trash — one Android prompt for all.

Limit: backed up only if the Immich app backs up the camera folder; otherwise stays local and pending.

**Measured** 2026-09-22, emulator: `testfoto-a-exif6` (server-only, older copy) → `testfoto-a-exif6.edit.jpg` in camera folder; backup simulated (`POST /assets`, unchanged); refresh → new copy on top, old in server trash, Android prompt, local copy gone.

---

## 2026-09-22 · D-27: No server extension; the recipe format is the interface

Maintainer asked for a removable server extension, as Noodle Gallery offers, so the server understands edits — also on Noodle.

Finding (`open-noodle/gallery` README, 2026-09-22): Noodle is **its own server image, not a plugin** — a fork rebased per Immich release (now 3.2.2, own version `v5`), removable by a script dropping its tables and columns; DB stays Immich-compatible. One image per server, so "for Immich and Noodle" means a patch on both forks every release.

Maintainer: **not for now**, D-2 suffices:
- A server that understands edits must render them (thumbnails, preview, download): a second TypeScript/libvips renderer, pixel-identical to the AGSL shader, with gain map; barely feasible for masks, 3D LUTs, eraser (M4, M5). D-2 avoids this.
- Small gain: web, Immich app, shared albums already show the edit (copy on top). Mainly saves doubled storage.
- D-1 would still hold.

Door open: every copy carries the versioned recipe as XMP (`ife:recipe`) with the original's checksum, readable by any future extension (ours, Noodle's, Immich's). **Apply:** keep the recipe format stable and documented (spec, *Aufbau*); Noodle-server compatibility is in the ROADMAP.

---

## 2026-09-21 · D-26: Device photos — edit without server, stack after backup

Built per D-24:

- **Gallery** tabs "Device" (`photo_manager`, newest first, pages of 120) and "Immich". Combined timeline in ROADMAP.
- **Device editor:** loads the file, computes SHA-1; saves `<name>.edit.jpg` in the **same folder** with the **same capture time** (`DATE_TAKEN`) — backed up by the Immich app, shown next to the original.
- **Re-edit:** original found by capture time (same second) and SHA-1 from the recipe XMP. Old copy to device trash (Android asks).
- **Stack later:** each local copy is recorded (SHA-1 of copy, original, replaced copy; `flutter_secure_storage`). On gallery open/refresh both are found by checksum and stacked as in direct save (`lib/stapeln/`).
- **`ACCESS_MEDIA_LOCATION` required.** Otherwise Android redacts location: different bytes, a SHA-1 no backup has, a copy without GPS. Granted with photo access, no extra prompt.
- **Build:** `kotlin.incremental=false` in `android/gradle.properties` — pub cache on `C:`, build on `M:` breaks Kotlin's incremental cache ("Could not close incremental caches").

**Measured** 2026-09-21, emulator, test user: test photos B and A (zero bytes appended) in `DCIM/Camera`, not on server. B edited → copy in same folder, same `datetaken`; reopened → original with recipe; saved again → old copy in trash. Backup simulated (both unchanged via `POST /assets`) → after pull-to-refresh one stack, copy on top, latitude in both. A (Ultra HDR) → copy with `hdrgm` XMP, MPF, recipe.

**Apply:** online photos (D-25, default "Device") take the same path.

---

## 2026-09-21 · D-25: Editing a server-only photo — setting, default device

Maintainer on E6: user setting; default (b), his preference.

- **(b) Device (default):** as D-24: copy to device gallery, Immich app backs up, we stack and delete the local file once on the server (checksum, `POST /assets/bulk-upload-check`); Android confirms deletion (`MediaStore.createDeleteRequest`).
- **(a) Server:** as D-23: upload, stack, verify; nothing on device.

**Apply:** "Online photos" (M2) builds both; setting "Edits of online photos: Device / Server".

---

## 2026-09-21 · D-24: Where editing and saving happen — local before server, network per setting

Maintainer's proposal and decision:

- **Original on device** (backed up or not): edit the local file, no server calls. Copy (with recipe XMP) to device gallery; Immich app backs up; we stack once both are on the server. Unstacked on device, stacked on web. The app never uploads such copies itself (would duplicate the backup).
- **Original only on server:** open at once with Immich's preview (recipe is resolution-independent). The original (full res, gain map) is needed only to save — Immich can't apply recipes (D-2), so the copy is rendered on device. Previews lack gain maps: HDR preview only with the original.
- **Network:** user setting — mobile data or Wi-Fi only for originals and uploads.

Server-only photo edits: D-25.

**Apply:** basis for the device-photo gallery (M2); settings "Mobile data" and "Edits of local photos: Device / directly to server".

---

## 2026-09-21 · D-23: Gallery via the timeline; re-edit; save in 4 s

**Gallery:** `POST /search/metadata` can't collapse stacks — `withStacked:false` hides *all* stacked images (1 instead of 8 entries). The timeline API (`/timeline/buckets`, `/timeline/bucket`, `withStacked=true`) returns each stack's primary with count, by month, like Immich's app — 8 entries instead of 15. The editor fetches checksum and file name via `GET /assets/{id}`.

**Re-edit** (spec, *Speicherweg* 5): a file with this app's recipe opens its original (found by checksum) with that recipe. Finding: re-stacking an already-stacked original dissolves the old stack, leaving the old copy loose (tested with `POST /stacks`). So saving trashes the opened copy and the previous primary — the latter only if its head (64 KB range request, 206) has our recipe. Emulator: after editing a loose older copy, exactly one active copy tops the stack.

**Saving was too slow**: the maintainer aborted on the Pixel after "App isn't responding". Emulator timestamps: render+encode 0.5 s, upload 3.8 s, **re-download to verify 7.9 s**, stack/albums/trash 2.4 s — 14.7 s. From the PC: 0.15 s (small) / 0.4 s (download); the client opened a connection per request. Now one keep-alive client, and instead of re-downloading, Immich's SHA-1 (computed on receipt) is compared to ours (Android `MessageDigest`) — equally strict. Result: 0.5 + 3.0 + 0.2 + 0.3 = **4.0 s**. Decoding on open moved off the main thread; whether the ANR is gone is still to be checked on the Pixel.

Side finding: D-22's "19 s" and its measurements are from different copies — two saves that evening (20:03 contrast + geometry, 20:18 all sliders via `adb` swipes over the toolbar). Measurements: 20:03; 19 s: 20:18.

**Apply:** verify saved copies by ID, never "the first search hit".

---

## 2026-09-21 · D-22: Stage-1 sliders in one shader; editor modeled on Google Photos

One AGSL shader for all twelve sliders (spec, recipe format). White balance in linear light, tones in perceived lightness; unsharp mask with radius relative to image size, so preview and export match; all 0 = unchanged. **Brightness is now a midtone curve** (γ = 2^−value), replacing M1's additive offset (D-12) — the recipe format is free until the first release.

Verification: 11 instrumented tests on the emulator GPU (`RendererTest`): neutral ≤ 2/255 off; brightness lifts midtones, keeps black; contrast spreads; saturation −1 → gray; blue tones hit the blue patch, not orange; warmth raises red, lowers blue; shadows, highlights, white/black point, vignette, sharpness move correctly; geometry swaps width/height. Emulator edit (contrast +0.39, 7.8°, crop) saved: "Saved and verified" after 19 s, 2432×3333, `uhdrload`, gain map 552×757, correlation with image 0.605 (rotated −0.089).

UI (spec, *Bedienung*): black editor, tabs, round tool buttons, scale ruler, crop frame with handles (outside dimming: brightness 76 → 42), undo/redo, press-and-hold for original.

Finding: ruler and crop frame computed drags from the last repaint's value, losing movement when several drags hit one frame (86 px → 1° instead of 8°). Both now track their own value while dragging.

**Apply:** new sliders go into `Renderer.REGLER`, the shader and `werkzeuge` (Dart), with a test in `RendererTest`.

---

## 2026-09-21 · D-21: One geometry computation for image and gain map; EXIF orientation

Implementation: `Geometrie.kt` computes a source → output matrix (quarter turns, mirroring in the rotated view, straightening with zoom so no corners are empty, crop). The image gets it as a shader matrix on the GPU; the gain map gets the same matrix at its own resolution on the CPU and keeps its HDR metadata. JVM tests check corners, rotation direction, mirroring, crop, and that straightening leaves no empty corners.

Finding: `BitmapFactory` does not apply EXIF orientation, unlike Flutter's decoder, which M1 relied on. Since the native renderer (M2/1), EXIF-rotated portrait photos would have come out landscape, because the copy carries orientation 1. The EXIF orientation is now the base geometry (`nachExif`); user adjustments are applied on top.

Verified in the emulator: test photo A with EXIF orientation 6 (pixels and gain map unchanged) displays correctly rotated. Added a quarter turn, 4:3 and about 13° straightening, saved: "Gespeichert und geprüft" (saved and verified), 3072×2304, EXIF orientation 1, on top of the stack. Copy's gain map 697×523 (aspect 1.3327 vs. 1.3333 for the image), `gainmap-max-content-boost` 4.653 (libvips). Does it match the image? Correlation luminance ↔ gain map, each at 96×96: original 0.745; copy **0.633**; controls: gain map rotated 180° −0.033, mirrored −0.071.

**Apply:** Every new geometry function (perspective, M2/M3) goes into `Geometrie.kt` and thus affects both.

---

## 2026-09-21 · D-20: Finding — the HDR preview works on the Pixel

Verified: app (at `151a316` + HDR toggle), release build on the maintainer's Pixel 7 Pro, editor open with `testfoto-a-hdr.jpg` (Ultra HDR, D-12).

- `dumpsys window`: window `colorMode=COLOR_MODE_HDR`.
- `dumpsys SurfaceFlinger`: the app's layer has `currentHdrSdrRatio=5`, `desiredHdrSdrRatio=5`; all other layers 1.
- The maintainer toggled HDR in the editor and saw a difference. Judging "highlights brighter than the white of the toolbar" was hard without a toggle; switching directly makes it visible.

Screenshots (`screencap`) do not capture HDR; the emulator has no HDR display (`supportedHdrTypes=[]`).

**Apply:** The D-17 approach holds: rendered sRGB image + gain map in a native view (Hybrid Composition) in an HDR window. HDR display stays an on-device test.

---

## 2026-09-21 · D-19: Copies are standard Ultra HDR — Immich will show them once it supports HDR

Maintainer's requirement: HDR copies the app stores in Immich should show in HDR without rework once Immich upstream renders Ultra HDR ([immich#7262](https://github.com/immich-app/immich/discussions/7262): web partially, server via libvips 8.18, mobile planned via native views).

Finding: checked the D-16 copy with **libvips 8.18.6** (`pyvips-binary`), whose Ultra HDR loader builds on Google's libultrahdr — the path Immich's server takes.

| | Loader | Gain map | Max content boost | HDR capacity |
|---|---|---|---|---|
| Original | `uhdrload` | 697×926 | 4.652 | 4.652 |
| Copy (D-16) | `uhdrload` | 697×926 | 4.653 | 4.653 |
| Copy from M1 (control) | `jpegload` | — | — | — |

Also D-16: Android's decoder reads the same values; Immich stores the file byte for byte (D-12).

**Apply:** No custom HDR format; the copy stays standard Ultra HDR (`hdrgm` XMP, ISO 21496-1, MPF) and sits on top of the stack. Every export change is cross-checked with `uhdrload` (M2 acceptance).

---

## 2026-09-21 · D-18: Minimum Android 14 (API 34)

AGSL shaders (D-17) exist from Android 13; the gain map API and HDR windows from Android 14. With Android 14 as the floor there is one code path instead of two; Android 14 is from 2023. Decided by the maintainer.

**Apply:** `minSdk = 34`; no code for older versions.

---

## 2026-09-21 · D-17: Native Android renderer — for a real HDR preview

Finding: Flutter cannot display HDR on Android — wide gamut only on iOS, gain maps not at all (Flutter docs, 3.47). Immich's maintainers reached the same conclusion: "Displaying Ultra HDR images likely requires us to write a custom image library backed by native Kotlin/Swift viewers" ([immich#7262](https://github.com/immich-app/immich/discussions/7262), March 2025); the Flutter gallery Aves has been waiting on Flutter since 2023 ([aves#838](https://github.com/deckerst/aves/issues/838)).

The maintainer wants an HDR preview while editing, as in Google Photos, so its users can switch without losing anything, with HDR switchable off in settings.

Decision: **Image processing lives in Android** (Kotlin, AGSL shaders on the GPU), for preview and export — still one renderer (D-2). The editor canvas is a native Android view in an HDR window; Android displays an image with gain map in HDR itself. Geometry applies the same computation to image and gain map. Flutter keeps UI, gallery, server and file assembly (`jpeg.dart`); the recipe goes over a channel as JSON. Replaces the spec's "preview via fragment shader".

**Apply:** Image math in AGSL/Kotlin; its tests run as instrumented tests in the emulator. HDR display itself can only be checked on a device with an HDR display (the maintainer's Pixel, after asking).

---

## 2026-09-21 · D-16: Ultra HDR — the copy keeps the gain map (E2)

Implementation: the encode channel receives the original; Android (14+, API 34) decodes it with its gain map, which is attached to the edited bitmap, and `Bitmap.compress` writes an Ultra HDR JPEG. Tone changes thus act equally on SDR and HDR rendering — the gain map describes the HDR/SDR ratio, not absolute brightness. Below Android 14 the gain map is lost (as in D-12).

Finding on encoder output (emulator and Pixel 7 Pro, API 37): JFIF, its own small EXIF, an XMP packet with `hdrgm:Version` and gain map directory (`Container:Directory`), ICC, ISO 21496-1 metadata, MPF after the tables; the gain map as a second JPEG with its own `hdrgm` XMP and ISO 21496-1. Simply prepending EXIF and recipe XMP produced **two** EXIF and two XMP segments, and a main-image MPF size that did not count our segments. So `zusammensetzen` now works on segments: the original's EXIF replaces the encoder's, the recipe goes into the existing XMP packet, MPF is adjusted.

Verified with `testfoto-a-hdr2.jpg` (test photo A from D-12 plus two trailing zero bytes so Immich doesn't reject it as a duplicate), app in emulator, brightness +0.33:

- App: "Gespeichert und geprüft" (byte comparison), 13 s until the message.
- Copy structure: one EXIF (the original's), one XMP with `ife:recipe` **and** `hdrgm:Version`, main-image MPF size 2 847 906 = start of gain map; gain map metadata as in the original (`GainMapMax` 2.217993).
- **Android's own decoder** (`BitmapFactory`, temporary check call in emulator): original — gain map 697×926, `ratioMax` 4.6525; copy — gain map 697×926, `ratioMax` 4.6525; control copy from M1 — no gain map.
- Stack, capture time, location as in D-12.
- Test `jpeg_test.dart` with a tiny Ultra HDR fixture of the same structure (`test/fixtures/ultrahdr_klein.py`).

Side findings:

- Pixel photos are often **Motion Photos** (video at end of file, `GCamera:MotionPhoto`); the copy is a still — correct for an edit.
- The editor preview is SDR; Flutter decodes without the gain map.

**Apply:** Geometry tools (M2) must transform the gain map too, or it no longer matches the image. HDR preview is open.

---

## 2026-09-21 · D-15: Docs and specs in English (E3)

The repo will go public (D-4); the Immich community writes English. Decided by the maintainer. Existing docs are still German.

**Apply:** Specs, `docs/` and `CLAUDE.md` are translated in one pass, at the latest before the repo goes public (M2 in [ROADMAP.en.md](ROADMAP.en.md)); until then docs stay uniformly German. Code identifiers stay as they are.

---

## 2026-09-21 · D-14: Android only, no iOS

The maintainer has no Apple devices and can neither build nor test iOS; untested iOS code would be a promise nobody checks. Decided by the maintainer. The `ios/` folder is removed; E5 (iOS build in CI) is dropped, as is the iOS side of the encode channel (D-13).

**Apply:** Use Android APIs directly where they solve something cheaply (encoder, gain map). If iOS comes later, e.g. from the community, `flutter create --platforms ios .` regenerates the scaffold; every platform channel then needs a counterpart.

---

## 2026-09-21 · D-13: JPEG encoder — the system's, not Dart (E1)

Measured: Pixel 7 Pro, release build, a 12.5 MP camera photo (3072×4080, Pixel 7 Pro, see D-12), three runs each; times stable after the first run.

| Step | Time | Size (quality 95) |
|---|---|---|
| Decode (`instantiateImageCodec`) | 111–159 ms | |
| Render with recipe + read RGBA | 77–89 ms | |
| **`Bitmap.compress`** via platform channel, incl. passing 48 MB RGBA | **248–355 ms** | 2.82 MB |
| `image` 4.10.1 (pure Dart, `encodeJpg`) | 3 191–3 215 ms | 3.35 MB |

Chosen: **the system encoder** — twelve times faster, smaller files, no dependency (a platform channel `immich_editor/jpeg` in `MainActivity.kt`). Cost: a counterpart per platform (dropped for iOS, D-14).

**Apply:** Export encodes via the channel. The Android encoder writes its own sRGB ICC profile; whether Display P3 photos keep their colors is unchecked (both test photos are sRGB).

---

## 2026-09-21 · D-12: Finding — M1 accepted: the save path holds (D-2 confirmed)

Verified with test user "Editor Test" (STATUS) against Immich 3.1.0, app as release build on a Pixel 7 Pro:

- Test photos from Wikimedia Commons, Pixel 7 Pro, CC BY-SA 4.0 (only on the test server, not in the repo): "<Ort>" (2026-05-03, with Ultra HDR gain map) and "<Ort>" (2022-10-30). Both with EXIF time incl. time zone and GPS, both in album "M1-Test".
- In the app, opened each photo, changed brightness (test photo A +0.32, test photo B darker), saved. The app then downloads the copy via `/original` and compares it **byte for byte** with what it sent before stacking: "Gespeichert und geprüft" (test photo B). Independently: SHA-1 of the downloaded test photo A copy = Immich's `checksum`.
- Via API: copy is the stack's `primaryAssetId` (2 assets); copy's `localDateTime`, time zone, coordinates and location equal the original's; album "M1-Test" contains the copies. The copy's XMP contains `ife:recipe` and `ife:originalSha1` = the original's `checksum`. Mean brightness of test photo A copy +40.6 (expected 0.32 × 128 ≈ 40.8): preview and export compute the same.
- The maintainer checked in Immich's web UI as the test user: stacks display correctly, edit on top.
- Time from tapping "Save" to back in the gallery: 7.5 s (render, encode, upload, re-download for comparison, stack, albums; Wi-Fi).

Side findings:

- **The gain map is lost**, as expected in D-8: copies carry neither MPF nor the original's Google XMP (E2).
- The copied EXIF contains the thumbnail (IFD1) of the **unedited** original. Immich generates its own previews; other viewers may show the old one.
- `POST /search/metadata` also returns a stack's non-primary assets — the gallery currently shows originals twice (M2).
- Flutter applies EXIF orientation when decoding (test `jpeg_test.dart`), so the copy gets orientation 1.

**Apply:** The "new asset + recipe XMP + stack" path is sound; M2 builds on it.

---

## 2026-09-21 · D-11: Finding — M0 accepted: signed APK from the tag runs on the device

Verified:

- `flutter doctor` on the dev machine: "No issues found" (versions in [STATUS.md](STATUS.md)).
- `ci.yml` green on GitHub for `cd7972f` and `5166b58` (format, analyze, test, debug APK), about 6½ minutes each.
- Tag `v0.0.1` on `5166b58`: `release.yml` green (run 35618926008), release with four APKs (arm64-v8a, armeabi-v7a, x86_64, universal) and `SHA256SUMS.txt`. Downloaded; `sha256sum -c` OK for all four; `apksigner verify` for arm64-v8a: scheme v2, certificate `CN=Construxz`, SHA-256 `9adfffc3…149a131f` — not the debug key.
- Installed the arm64 APK via `adb install` on a Pixel 7 Pro: `versionName=0.0.1`, `versionCode=2001`, app starts with no crash in the log. Before that, ran via `flutter run` in debug mode on the same device.

Side findings:

- **Debug and release builds use different keys.** Uninstall the app before switching (`adb uninstall io.github.construxz.photoeditor`).
- **Release versionCode** = 1000 × ABI + `release.yml` run number (`--build-number=github.run_number`); versionName from the tag. `pubspec.yaml` only counts locally.
- `sdkmanager` 23.0 crashes on Windows at the end of every call (0xC0000409); Gradle still downloads missing SDK parts (NDK 28.2) itself. The first build after fresh setup failed once because of this; retrying was enough.
- AGP 9.1 / Gradle 9.3.1 run with the JDK 25 from Android Studio; CI uses Temurin 25.

**Apply:** Releases come only from a `v*` tag; the key is kept by the maintainer outside the repo and as four GitHub secrets.

---

## 2026-09-21 · D-10: Application ID `io.github.construxz.photoeditor`

Android application ID and iOS bundle ID; the Dart package name stays `immich_editor`. No "immich" in the ID, because it cannot change after the first store upload — it also fits if name use (D-5) is objected to or more backends are added. `io.github.construxz` is the maintainer's GitHub namespace.

---

## 2026-09-21 · D-9: IMG.LY Photo SDK rejected

Evaluated as a ready-made editor base. Vendor states "typical deployments $600–2,000/month", billed per monthly active user; proprietary, so incompatible with AGPL; and as a Canva-like CreativeEditor far larger than the intended scope.

**Apply:** No commercial SDK at the core. Open building blocks are listed in [LICENSES.md](LICENSES.md).

---

## 2026-09-21 · D-8: Finding — re-encoded copies lose the HDR gain map

Verified: downloaded one original from each of five days (2024–2026) of a Pixel 7 Pro library via `GET /api/assets/{id}/original` and searched for `hdrgm`. One photo (2024) had an Ultra HDR gain map, four (2025/2026) did not. Five images are no distribution, but both cases occur.

**Apply:** Every edit produces a re-encoded copy. Unless export explicitly carries the gain map over, HDR is silently lost. Export must transfer it before photos with gain maps are edited.

---

## 2026-09-21 · D-7: Finding — phone libraries are JPEG libraries

Measured: file extension and EXIF camera model of all 13 660 images from 2025–2026 in an Immich library (timeline and archive, `POST /api/search/metadata`).

| Extension | Share | | Camera | Share |
|---|---|---|---|---|
| JPG | 99.7 % | | Pixel 7 Pro | 81.1 % |
| PNG | 0.3 % | | Canon EOS R7 | 17.3 % |
| RAW | **0.0 %** | | DJI | 0.8 % |

The system camera also delivered only JPEG.

**Apply:** JPEG first, RAW last if at all. A RAW developer as the starting point would edit nothing such libraries contain.

---

## 2026-09-21 · D-6: On-device AI with open models, no Google services

Three options: open models on the device, the OS's AI, the server's ML. Chosen: **on device, open models, downloaded on first use.** OS AI is out on Android because ML Kit loads its models via Google Play services; server ML is not reliably reachable on the go. Open: whether MediaPipe is acceptable — Google code, but Apache-2.0, fully local, no service calls.

**Apply:** No dependency on Google Play services or Firebase — this also keeps F-Droid open.

---

## 2026-09-21 · D-5: Name "immich-editor", title "Editor for Immich"

Repository `immich-editor`; in app and README "Editor for Immich — An open-source mobile photo library and editor for Immich". Deliberately generic until it's clear whether the project gets traction.

Finding on name use (2026-09-21):

- The "Immich" trademark belongs to FUTO. The [Immich FAQ](https://docs.immich.app/FAQ/) says integrations are "typically approved, provided proper notification is given"; one must not appear officially affiliated; questions to questions@immich.app.
- Immich's list [awesome.immich.app](https://awesome.immich.app/) has many "Immich X" projects. "immich-edit" (haavardnk) and "Immich Companion" are taken; `immich-editor` was free on GitHub.

**Apply:** README and app say "unofficial". No Immich logo in the app icon. Before the public release, email questions@immich.app (name, "unofficial, API client, changes nothing on the server", link). For the stores, check whether "Immich" may be in the title.

---

## 2026-09-21 · D-4: Distribution first via GitHub Releases, repo private until first release

APK from GitHub Actions to GitHub Releases, later Google Play and App Store. The repository stays private until the first release (milestone M2 in [ROADMAP.en.md](ROADMAP.en.md)) — no half-finished promises to the community.

---

## 2026-09-21 · D-3: License AGPL-3.0

Same as Immich. Every distributed modification stays open, and code from Immich and other AGPL projects may be reused. Apache-2.0 and MIT code is compatible, with attribution in a `NOTICE` file. All dependencies are listed in [LICENSES.md](LICENSES.md).

---

## 2026-09-21 · D-2: Save as a copy with recipe XMP, stacked with the original

Finding, checked in `immich-app/immich`, branch `main`: Immich stores its own edits as a recipe in table `asset_edit` and renders them server-side with Sharp (`server/src/repositories/media.repository.ts`, `applyEdits`). Only `crop`, `rotate` (0/90/180/270°) and `mirror` are allowed — a zod enum in `server/src/dtos/editing.dto.ts`; the server rejects any other action. Stacks can be created via the standard API (`POST /api/stacks`, `assetIds`, "first becomes primary, min 2").

Decision: the app renders on the device, uploads the result as a **new asset**, stores the recipe as **XMP in its own namespace** in the copy, and **stacks the copy in front of the original**. Reasons: no server fork; fully reversible (only ordinary assets and stacks); and only **one** renderer — going via `asset_edit` would have needed the same image math again in Sharp, which cannot directly do perspective, 3D LUTs, highlights or masks. Cost: every edited photo is stored twice on the server.

Detailed in [specs/0001-editor.md](../specs/0001-editor.md).

---

## 2026-09-21 · D-1: Standalone Flutter app, Immich stays unchanged

A separate app for Android and iOS that talks to Immich only through its API — no fork of Immich's app or server. The Immich app remains library and backup. Reason: Immich considered an editor several times and dropped it; a standalone client evolves independently and changes nothing irreversible on the server. Flutter, because Immich's own app is Flutter and one codebase covers both platforms.
