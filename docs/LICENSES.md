# Register: Abhängigkeiten, Modelle, Vorlagen

Je Eintrag die Lizenz und ob sie zur **AGPL-3.0** des Projekts passt (D-3 in
[DECISIONS.md](DECISIONS.md)). Als Register zu lesen, nicht als Tor: Neue Einträge kommen
hinzu, sobald etwas eingebunden wird. **Zuerst nach Copyleft fragen.**

Lizenzen nachgesehen am 21.09.2026 über die GitHub-API bzw. die README des Projekts.

## Abhängigkeiten

Eingebunden sind bisher Flutter, `flutter_lints`, `http`, `flutter_secure_storage` (mit `tink-android`; über `path_provider_android` kommen `jni`, `jni_flutter`, `jni_util` vom Dart-Team, BSD-3-Clause), `photo_manager` (mit Glide und `androidx.exifinterface`; Dart-seitig nur `path`, BSD-3-Clause) und die Schrift Google Sans; der Rest ist geplant.

| Paket | Zweck | Lizenz | passt |
|---|---|---|---|
| [Flutter](https://github.com/flutter/flutter) | Framework | BSD-3-Clause | ja |
| [flutter_lints](https://github.com/flutter/packages/tree/main/packages/flutter_lints) | Lint-Regeln, nur Entwicklung | BSD-3-Clause | ja |
| [photo_manager](https://github.com/fluttercandies/flutter_photo_manager) | Gerätegalerie; auch in Immichs App | Apache-2.0 | ja |
| [Glide](https://github.com/bumptech/glide) | Miniaturen in `photo_manager` | BSD, Teile MIT und Apache-2.0 | ja |
| [AndroidX ExifInterface](https://developer.android.com/jetpack/androidx/releases/exifinterface) | EXIF in `photo_manager` | Apache-2.0 | ja |
| [Google Sans](https://github.com/googlefonts/googlesans) | Schrift wie in der Immich-App; Dateien aus deren Repo, `fonts/GoogleSans/OFL.txt` | SIL OFL 1.1 | ja — darf mit Software gebündelt werden |
| [http](https://github.com/dart-lang/http) | Immich-API | BSD-3-Clause | ja |
| [flutter_localizations](https://github.com/flutter/flutter/tree/master/packages/flutter_localizations) | Anzeigesprache Deutsch/Englisch; Teil des Flutter-SDK | BSD-3-Clause | ja |
| [intl](https://github.com/dart-lang/i18n/tree/main/pkgs/intl) | Übersetzungen, Datums- und Zahlenformate | BSD-3-Clause | ja |
| [flutter_secure_storage](https://github.com/juliansteenbakker/flutter_secure_storage) | Anmeldedaten | BSD-3-Clause | ja |
| [Tink](https://github.com/tink-crypto/tink-java) (`tink-android`) | Verschlüsselung in `flutter_secure_storage`; Google-Bibliothek, lokal, ohne Play-Dienste | Apache-2.0 | ja |
| [JUnit 4](https://github.com/junit-team/junit4) | nur Tests (JVM), nicht in der App | EPL-1.0 | ja — wird nicht weitergegeben |
| [org.json](https://github.com/stleary/JSON-java) | nur Tests (JVM): echtes JSON statt Androids Attrappe | Public Domain | ja |
| [AndroidX Test](https://github.com/android/android-test) (`androidx.test.ext:junit`, `runner`) | nur Instrumented Tests im Emulator | Apache-2.0 | ja |
| [ONNX Runtime](https://github.com/microsoft/onnxruntime) | Modelle auf dem Gerät (M5) | MIT | ja |

## Modell-Kandidaten (M5)

Code- und Gewichtslizenz können abweichen — bei jedem Modell die **Gewichte** prüfen.

| Zweck | Modell | Lizenz | passt |
|---|---|---|---|
| Person freistellen | [MediaPipe](https://github.com/google-ai-edge/mediapipe) Segmenter | Apache-2.0 | ja — Zulässigkeit nach D-6 offen (E4 in [ROADMAP.md](ROADMAP.md)) |
| Objekt per Antippen | [MobileSAM](https://github.com/ChaoningZhang/MobileSAM), [EfficientSAM](https://github.com/yformer/EfficientSAM) | Apache-2.0 | ja |
| Inpainting | [MI-GAN](https://github.com/Picsart-AI-Research/MI-GAN) | MIT | ja |
| Inpainting | [LaMa](https://github.com/advimman/lama) | Apache-2.0 | ja |
| Tiefe | [Depth Anything V2](https://github.com/DepthAnything/Depth-Anything-V2) **Small** | Apache-2.0 | ja |
| Tiefe | Depth Anything V2 Base/Large/Giant | CC-BY-NC-4.0 | **nein** — nicht-kommerziell |
| Freistellen | ML Kit | proprietär, über Google-Play-Dienste | **nein** — D-6 |

## Vorlagen (gelesen oder portiert, nicht eingebunden)

| Projekt | Rolle | Lizenz | passt |
|---|---|---|---|
| [T8RIN/ImageToolbox](https://github.com/T8RIN/ImageToolbox) | Algorithmen: GPU-Filter, Freistellen, Spot-Healing, Perspektive, Stapelverarbeitung. Seine Modelle einzeln prüfen (RMBG von BRIA vermutlich nicht frei) | Apache-2.0 | ja, mit `NOTICE` |
| [burhanrashid52/PhotoEditor](https://github.com/burhanrashid52/PhotoEditor) | Zeichnen, Text, Rückgängig | MIT | ja, mit `NOTICE` |
| [immich-app/immich](https://github.com/immich-app/immich) | API; Design der Mobil-App übernommen (Theme, Konto-Fenster, Einstellungen — D-35) | AGPL-3.0 | ja |
| [open-noodle/gallery](https://github.com/open-noodle/gallery) | Immich-Fork, Arbeitsweise mit Specs | AGPL-3.0 | ja |
| [haavardnk/immich-edit](https://github.com/haavardnk/immich-edit) | RAW-Entwickler (Rust + `wgpu`), nur Lektüre | AGPL-3.0 | ja |
| [dev-nick421/immich-swipe](https://github.com/dev-nick421/immich-swipe) | Bedienmuster | **keine** | **nein** — ohne Lizenz alle Rechte vorbehalten; nur lesen |
| [IMG.LY Photo SDK](https://img.ly/products/photo-sdk/) | — | proprietär | **nein** — D-9 |
