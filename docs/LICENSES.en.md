# Register: dependencies, models, references

*English translation of [LICENSES.md](LICENSES.md) (German). If they differ, the German file is
authoritative.*

Each entry lists the license and whether it fits the project's **AGPL-3.0** (D-3 in
[DECISIONS.en.md](DECISIONS.en.md)). Read it as a register, not a gate: new entries are added as
soon as something is included. **Ask about copyleft first.**

Licenses checked on 2026-09-21 via the GitHub API or the project's README.

## Dependencies

Included so far are Flutter, `flutter_lints`, `http`, `flutter_secure_storage` (with `tink-android`; `path_provider_android` brings `jni`, `jni_flutter`, `jni_util` from the Dart team, BSD-3-Clause), `photo_manager` (with Glide and `androidx.exifinterface`; on the Dart side only `path`, BSD-3-Clause) and the Google Sans font; the rest is planned.

| Package | Purpose | License | fits |
|---|---|---|---|
| [Flutter](https://github.com/flutter/flutter) | Framework | BSD-3-Clause | yes |
| [flutter_lints](https://github.com/flutter/packages/tree/main/packages/flutter_lints) | Lint rules, development only | BSD-3-Clause | yes |
| [photo_manager](https://github.com/fluttercandies/flutter_photo_manager) | Device gallery; also in Immich's app | Apache-2.0 | yes |
| [Glide](https://github.com/bumptech/glide) | Thumbnails in `photo_manager` | BSD, parts MIT and Apache-2.0 | yes |
| [AndroidX ExifInterface](https://developer.android.com/jetpack/androidx/releases/exifinterface) | EXIF in `photo_manager` | Apache-2.0 | yes |
| [Google Sans](https://github.com/googlefonts/googlesans) | Font as in the Immich app; files from its repo, `fonts/GoogleSans/OFL.txt` | SIL OFL 1.1 | yes — may be bundled with software |
| [http](https://github.com/dart-lang/http) | Immich API | BSD-3-Clause | yes |
| [flutter_localizations](https://github.com/flutter/flutter/tree/master/packages/flutter_localizations) | Display language German/English; part of the Flutter SDK | BSD-3-Clause | yes |
| [workmanager](https://github.com/fluttercommunity/flutter_workmanager) | Stacking in the background (D-46) | MIT | yes |
| [AndroidX WorkManager](https://developer.android.com/jetpack/androidx/releases/work) | In `workmanager`; schedules tasks via Android's JobScheduler, without Play services | Apache-2.0 | yes |
| [intl](https://github.com/dart-lang/i18n/tree/main/pkgs/intl) | Translations, date and number formats | BSD-3-Clause | yes |
| [flutter_secure_storage](https://github.com/juliansteenbakker/flutter_secure_storage) | Login data | BSD-3-Clause | yes |
| [Tink](https://github.com/tink-crypto/tink-java) (`tink-android`) | Encryption in `flutter_secure_storage`; Google library, local, without Play services | Apache-2.0 | yes |
| [JUnit 4](https://github.com/junit-team/junit4) | Tests only (JVM), not in the app | EPL-1.0 | yes — not distributed |
| [org.json](https://github.com/stleary/JSON-java) | Tests only (JVM): real JSON instead of Android's stub | Public Domain | yes |
| [AndroidX Test](https://github.com/android/android-test) (`androidx.test.ext:junit`, `runner`) | Instrumented tests in the emulator only | Apache-2.0 | yes |
| [ONNX Runtime](https://github.com/microsoft/onnxruntime) | Models on the device (M5) | MIT | yes |

## Model candidates (M5)

Code and weights licenses can differ — check the **weights** for every model.

| Purpose | Model | License | fits |
|---|---|---|---|
| Cut out a person | [MediaPipe](https://github.com/google-ai-edge/mediapipe) Segmenter | Apache-2.0 | yes — whether it is acceptable under D-6 is open (E4 in [ROADMAP.en.md](ROADMAP.en.md)) |
| Object by tap | [MobileSAM](https://github.com/ChaoningZhang/MobileSAM), [EfficientSAM](https://github.com/yformer/EfficientSAM) | Apache-2.0 | yes |
| Inpainting | [MI-GAN](https://github.com/Picsart-AI-Research/MI-GAN) | MIT | yes |
| Inpainting | [LaMa](https://github.com/advimman/lama) | Apache-2.0 | yes |
| Depth | [Depth Anything V2](https://github.com/DepthAnything/Depth-Anything-V2) **Small** | Apache-2.0 | yes |
| Depth | Depth Anything V2 Base/Large/Giant | CC-BY-NC-4.0 | **no** — non-commercial |
| Cut-out | ML Kit | proprietary, via Google Play services | **no** — D-6 |

## References (read or ported, not included)

| Project | Role | License | fits |
|---|---|---|---|
| [T8RIN/ImageToolbox](https://github.com/T8RIN/ImageToolbox) | Algorithms: GPU filters, cut-out, spot healing, perspective, batch processing. Check its models individually (BRIA's RMBG probably not free). **Not its LUTs:** the built-in ones carry the names of Photoshop's "Color Lookup" presets, the downloadable pack has no license (D-62) — our filters are our own (`tool/make_luts.py`) | Apache-2.0 | yes, with `NOTICE` |
| [burhanrashid52/PhotoEditor](https://github.com/burhanrashid52/PhotoEditor) | Drawing, text, undo | MIT | yes, with `NOTICE` |
| [immich-app/immich](https://github.com/immich-app/immich) | API; design of the mobile app adopted (theme, account sheet, settings — D-35) | AGPL-3.0 | yes |
| [open-noodle/gallery](https://github.com/open-noodle/gallery) | Immich fork, working with specs | AGPL-3.0 | yes |
| [haavardnk/immich-edit](https://github.com/haavardnk/immich-edit) | Self-hosted, non-destructive RAW developer for an Immich library: server (Rust + `wgpu`) with a browser UI, preview via WebGPU, edits as sidecars on its server, `0.x` (checked 2026-09-25). Reading only, a model for the pro mode | AGPL-3.0-**only** | yes — but adopted code would bind us to AGPL-3.0 without "or later"; D-3 does not name the variant yet |
| [dev-nick421/immich-swipe](https://github.com/dev-nick421/immich-swipe) | Interaction patterns | **none** | **no** — without a license all rights reserved; read only |
| [IMG.LY Photo SDK](https://img.ly/products/photo-sdk/) | — | proprietary | **no** — D-9 |
