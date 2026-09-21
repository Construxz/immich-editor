# Zustand — was jetzt gilt

**Diese Datei wird überschrieben, nicht fortgeschrieben.** Warum etwas so ist, steht in
[DECISIONS.md](DECISIONS.md), was noch fehlt, in [ROADMAP.md](ROADMAP.md).

Stand: 21.09.2026, nach M1.

## Was es gibt

- **Eine Flutter-App** (nur Android, D-14; Application-ID `io.github.construxz.photoeditor`,
  Dart-Paket `immich_editor`, D-10), die den Speicherweg durchgeht (D-12):
  - Anmelden mit Server, E-Mail, Passwort; Token in `flutter_secure_storage`. Warnt, wenn die
    Immich-Hauptversion nicht 3 ist.
  - Galerie: die neuesten 200 Server-Fotos als Raster — ohne Blättern, ohne Gerätefotos, und
    die hinteren Assets eines Stapels erscheinen mit.
  - Editor: nur ein Helligkeitsregler und ein HDR-Knopf. Vorschau und Export rechnet der native
    Renderer (AGSL, `Renderer.kt`); die Bildfläche ist eine native Ansicht im HDR-Fenster (D-17,
    D-20). `minSdk 34`.
  - Speichern: volle Auflösung rendern, per Systemkodierer als JPEG (Qualität 95, D-13), EXIF
    des Originals mit Orientierung 1, Rezept-XMP (Format in der Spec, *Aufbau*); hochladen,
    Byte für Byte gegenprüfen, vor das Original stapeln, in dessen Alben legen.
  - Ultra HDR: Die Kopie behält die Gain-Map des Originals (D-16), Standardformat (D-19); die
    Vorschau zeigt HDR (D-20). Der HDR-Knopf schaltet beides ab (Einstellung `hdr`).
  - **Noch nicht:** erneut bearbeiten (ein Original, das schon im Stapel liegt), Gerätefotos
    (M2), Zeitgrenzen für Netzwerkanfragen (hängt der Server, dreht die App endlos).
- Code: `lib/server/` (Immich-Client mit den neun Endpunkten der Spec),
  `lib/gallery/`, `lib/editor/`, `lib/export/`, `lib/foto.dart`; Tests in `test/` (JPEG-Segmente,
  Orientierung, XMP, Ultra-HDR-Aufbau; Start ohne Sitzung). Keine Google-Play-Dienste, kein Firebase. Konzept in
  [specs/0001-editor.md](../specs/0001-editor.md).
- **CI** ([ci.yml](../.github/workflows/ci.yml)) bei jedem Push und Pull Request: format,
  analyze, test, Debug-APK.
- **Release** ([release.yml](../.github/workflows/release.yml)) bei Tag `v*`: signierte Split-
  und Universal-APKs mit `SHA256SUMS.txt` als GitHub-Release. Letzter Release: **v0.0.1**
  (leeres Gerüst, D-11).
- **Signierschlüssel** `%USERPROFILE%\keys\immich-editor-upload.jks`, Alias `upload`, beim
  Besitzer gesichert; in GitHub als Secrets `ANDROID_KEYSTORE_BASE64`,
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. Lokale Builds
  ohne `android/key.properties` signieren mit dem Debug-Schlüssel.
- Git-Repository, Zweig `main`, Remote `origin` = `https://github.com/Construxz/immich-editor.git`
  (privat), öffentlich ab dem ersten Release (D-4).

## Entwicklungsumgebung

Geprüft 21.09.2026 mit `flutter doctor`: keine Befunde.

| Werkzeug | Version | Ort |
|---|---|---|
| Flutter (stable) | 3.47.5, Dart 3.13.4 | `%USERPROFILE%\develop\flutter` (Git-Klon, im Benutzer-PATH) |
| JDK | 25.0.3 (JBR aus Android Studio) | `C:\Program Files\Android\Android Studio\jbr` |
| Android Studio | Build 261.26222.65 | `C:\Program Files\Android\Android Studio` |
| Android SDK | Plattform 37.0, Build-Tools 36.0.0, Platform-Tools 37.0.1, cmdline-tools 23.0, NDK 28.2.13676358 | `%LOCALAPPDATA%\Android\Sdk` |
| AGP / Gradle / Kotlin | 9.1.0 / 9.3.1 / 2.4.0 | aus dem Flutter-Template |
| Android SDK Command-line Tools | `android sdk install …` statt `sdkmanager` (der stürzt in 23.0 ab) | `%LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest\bin\android.exe` |
| Emulator | AVD `editor_pixel7pro`: Pixel 7 Pro, API 37 (`google_apis`, x86_64), 6 GB RAM, Host-GPU, WHPX | `%USERPROFILE%\.android\avd` |
| Testgerät | Pixel 7 Pro (Android 17) des Besitzers, USB-Debugging — nur nach Rückfrage | — |

Die CI nutzt dieselbe Flutter-Version, fest eingetragen in beiden Workflows, und Temurin 25.
Flutter aktualisieren heißt: lokal **und** in beiden Workflows ändern.

## Immich-Testbenutzer

Für die Entwicklung gibt es auf dem Server des Besitzers den Benutzer **„Editor Test"**
(angelegt 21.09.2026): kein Admin, 10 GB Kontingent, eigene Bibliothek. Darin (21.09.2026): zwei
Testfotos (A, B; D-12) und zwei Varianten des Testfoto A
(`testfoto-a-hdr.jpg`, `testfoto-a-hdr2.jpg`, D-16), jeweils mit bearbeiteter Kopie im Stapel;
Album „M1-Test" mit den ersten vier. Server-Adresse, API-Schlüssel (Berechtigung „all", wirkt nur auf die eigene Bibliothek),
E-Mail und Passwort stehen in der lokalen `.env` im Projektordner (`IMMICH_SERVER`,
`IMMICH_API_KEY`, `IMMICH_TEST_EMAIL`, `IMMICH_TEST_PASSWORD`; von `.gitignore` erfasst).
Zugriff über `x-api-key` gegen `IMMICH_SERVER/api/…`. Geprüft 21.09.2026: `GET /api/users/me`
liefert „Editor Test", kein Admin. **Nur diesen Zugang verwenden**, nie einen Schlüssel des
Admin-Kontos mit der echten Bibliothek.

## Gegen welche Immich-Version geplant wird

Die neun Endpunkte der App sind gegen `open-api/immich-openapi-specs.json` in
`immich-app/immich` geprüft: Zweig `main`, Spec-Version **3.2.0**, und Tag `v3.1.0` — in beiden
gleich, samt Pflichtfeldern (21.09.2026). Der Server des Testbenutzers läuft mit **3.1.0**; gegen
ihn ist M1 abgenommen (D-12). Am 21.09.2026 abends auf **3.2.2** aktualisiert (während des
Neustarts „Connection refused" und 404); seitdem laufen die Tests gegen 3.2.2.
