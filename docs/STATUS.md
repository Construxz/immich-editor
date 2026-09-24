# Zustand — was jetzt gilt

**Diese Datei wird überschrieben, nicht fortgeschrieben.** Warum etwas so ist, steht in
[DECISIONS.md](DECISIONS.md), was noch fehlt, in [ROADMAP.md](ROADMAP.md).

Stand: 23.09.2026, M2 in Arbeit (offen: [ROADMAP.md](ROADMAP.md), M2).

## Was es gibt

- **Eine Flutter-App** (nur Android, D-14; Application-ID `io.github.construxz.photoeditor`,
  Dart-Paket `immich_editor`, D-10), `minSdk 34` (D-18):
  - Anmelden mit Server, E-Mail, Passwort; Token in `flutter_secure_storage`. Warnt, wenn die
    Immich-Hauptversion nicht 3 ist.
  - Aussehen der Immich-App (Farben, Google Sans, D-35), Bedienung nach Google Fotos.
  - Galerie wie die Immich-App (D-36): „Fotos" ist eine Zeitleiste über Gerät und Server,
    über die Prüfsumme zusammengeführt (einmal gerechnet, zwischengespeichert; beim Start sofort
    der Stand des letzten Abgleichs, dann frisch, D-51; der erste Lauf
    erklärt sich in einem Fenster, danach Ring ums Profilbild und Stand im Konto-Fenster, D-39), mit Wolke unten
    rechts (nur Gerät / nur Server / beides); vom Gerät nur gewählte Ordner, Vorgabe die Kamera
    (D-48); „Bibliothek" mit den Geräteordnern: angepinnte, dann selbst angeordnete, dann der
    Rest nach neuestem Foto (wie die Immich-App) oder A–Z, einzelne ausblendbar (D-52, D-59).
  - HDR-Knopf in Galerie, Betrachter und Editor, ein gemeinsamer Zustand; in den Einstellungen
    ausblendbar (D-58). Getrennte
    Reiter per Einstellung „Ansicht". Fotos aus Ordnern, die Immich nicht sichert: nach dem
    Speichern auf Wunsch archiviert hochladen, Album „Editor for Immich", in Immich öffnen —
    mit der App, die Android anbietet, oder einer in den Einstellungen festgelegten (D-52).
  - Anzeigesprache wie das Gerät (Deutsch, sonst Englisch) oder fest gewählt (D-43).
  - Oben rechts das Profilbild → Konto-Fenster wie in der Immich-App (Profil,
    Speicherplatz, App- und Server-Version, Server-Adresse, wartende Bearbeitungen, Abmelden) und
    **Einstellungen** als Karten: Bearbeiten (HDR), Speichern (Online-Fotos übers Gerät), Netzwerk
    (mobile Daten, D-30), Stapeln („Jetzt stapeln") — D-32, D-35. Antippen öffnet den **Betrachter**
    (D-33): wischen, auch über Monatsgrenzen (D-47), HDR aus dem lokalen Original (D-54), zoomen, Stapel wie bei Google Fotos (Original, V1, V2; Hauptfoto festlegen,
    eines behalten und den Rest löschen, D-34), hochwischen für Infos, „Bearbeiten" → Editor →
    zurück zum Ergebnis. Zwei Reiter: „Gerät" (Fotos auf dem Gerät,
    neueste zuerst, D-26) und „Immich": Server-Fotos nach Monaten über Immichs Timeline,
    Monate laden beim Hinscrollen, ein Stapel zählt einmal (vorn die Bearbeitung), Mehrfachauswahl
    per langem Druck; die Auswahl bekommt ein **Preset** (D-40).
  - Editor im Aufbau von Google Fotos (D-22): schwarz; oben Schließen, Rückgängig/Wiederholen,
    HDR, Speichern, ⋮ (HDR, alles zurücksetzen); Reiter „Presets" (Regler sichern, anwenden,
    D-40), „Zuschneiden" (Rahmen mit Anfassern,
    Seitenverhältnis, Spiegeln, Drehen, Winkel-Lineal) und „Anpassen" (12 Regler als runde Knöpfe,
    Skalen-Lineal); Gedrückthalten zeigt das Original. Vorschau und Export rechnet der native
    Renderer (AGSL, `Renderer.kt`); die Bildfläche ist eine native Ansicht im HDR-Fenster (D-17,
    D-20). Das Lineal rastet nahe 0 ein; die Null ist bernsteinfarben markiert (D-41). Server-Fotos öffnen mit Immichs Vorschaubild, das
    Original (und damit HDR) kommt im Hintergrund nach; Speichern wartet darauf (D-29).
  - Speichern: volle Auflösung rendern, per Systemkodierer als JPEG (Qualität 95, D-13), EXIF
    des Originals mit Orientierung 1, Rezept-XMP (Format in der Spec, *Aufbau*); hochladen,
    gegenprüfen (SHA-1 des Servers = eigene), vor das Original stapeln, in dessen Alben legen;
    etwa 4 s im Emulator (D-23). **Gerätefotos** speichert die App ohne Server: Kopie in
    denselben Ordner der Gerätegalerie, vorgemerkt; sobald die Immich-App Original und Kopie
    gesichert hat, stapelt die Galerie beim Öffnen oder Aktualisieren (D-26). **Online-Fotos**
    ebenso (Vorgabe) in den Kameraordner; nach dem Stapeln verlässt die Kopie das Gerät (D-28).
    Mit der Einstellung aus direkt auf den Server wie oben. Ein Server-Foto, dessen Original auch
    auf dem Gerät liegt, bearbeitet die App lokal (D-45). Was nie ankommen kann (Kopie oder
    Original überall gelöscht), fällt aus der Warteschlange. Solange etwas wartet, stapelt
    Androids WorkManager etwa alle 15 Minuten auch ohne geöffnete App (D-46).
  - Netzwerk: Zeitgrenzen (30 s, Originale und Upload 3 min) und verständliche Fehler.
  - Ultra HDR: Die Kopie behält die Gain-Map des Originals (D-16), Standardformat (D-19); die
    Vorschau zeigt HDR (D-20). Der HDR-Knopf schaltet beides ab (Einstellung `hdr`).
  - Erneut bearbeiten: Öffnet man eine Kopie, öffnet der Editor das Original mit deren Rezept;
    beim Speichern „Kopie ersetzen" (die alte in den Papierkorb) oder „Als weitere Kopie
    speichern" — alle Kopien bleiben in einem Stapel (D-31).
  - **Noch nicht:** Filter,
    Perspektive — siehe ROADMAP.
- Code: `lib/server/` (Immich-Client, Endpunkte in der Spec, eine Keep-Alive-Verbindung),
  `lib/gallery/` (mit `device.dart` über `photo_manager`), `lib/stacking/` (Stapeln, auch
  vorgemerkt nach dem Backup), `lib/editor/` (Seite, Rezept, Presets, Laden und Speichern einer Kopie, Lineal,
  Zuschnittrahmen, Vorschau-Kanal),
  `lib/export/` (Zusammensetzen der JPEG-Datei), `lib/photo.dart`; nativ in
  `android/app/src/main/kotlin/…/` `Renderer.kt`, `Geometry.kt`, `Preview.kt` (Sitzung, Ansicht),
  `MainActivity.kt` (Kanal `immich_editor/renderer`). **Code, Dateinamen und Kommentare auf
  Englisch** (D-42). Anzeigesprache Deutsch oder Englisch nach dem Gerät, in den Einstellungen
  umstellbar (D-43); Texte in `lib/l10n/app_{de,en}.arb`. Keine Google-Play-Dienste, kein Firebase.
- Tests: `test/` (22 — Ordnerreihenfolge, Sprachwahl, JPEG-Segmente, Ultra-HDR-Aufbau, Rezept, Presets, Lineal, Warteschlange,
  Prüfsummen-Abgleich, Start),
  `android/app/src/test/` (9 — Geometrie, JVM, auch in der CI) und `android/app/src/androidTest/`
  (11 — Renderer auf der GPU, nur im Emulator: `gradlew connectedDebugAndroidTest`).
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
- **Pixel des Besitzers:** App-Stand `5f3b439` (Release-Build, Debug-Schlüssel), installiert
  24.09.2026 nachmittags, als Testbenutzer angemeldet.

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
(angelegt 21.09.2026): kein Admin, 10 GB Kontingent, eigene Bibliothek. Darin: die Testfotos
Testfoto A (Ultra HDR) und Testfoto B (D-12), dazu Varianten des Testfoto A mit angehängten
Nullbytes, damit Immich sie nicht als Duplikat ablehnt (`testfoto-a-hdr.jpg` … `-hdr4.jpg`,
`testfoto-a-exif6.jpg` mit EXIF-Orientierung 6), die meisten mit bearbeiteter Kopie im Stapel;
ältere Kopien im Papierkorb; Album „M1-Test"; `preset-01` … `-11` und `geraet-preset` mit Kopie
aus der Presets-Abnahme (D-40). Die Bilder selbst (Wikimedia Commons, CC BY-SA 4.0)
liegen nicht im Repo. Server-Adresse, API-Schlüssel (Berechtigung „all", wirkt nur auf die eigene Bibliothek),
E-Mail und Passwort stehen in der lokalen `.env` im Projektordner (`IMMICH_SERVER`,
`IMMICH_API_KEY`, `IMMICH_TEST_EMAIL`, `IMMICH_TEST_PASSWORD`; von `.gitignore` erfasst).
Zugriff über `x-api-key` gegen `IMMICH_SERVER/api/…`. Geprüft 21.09.2026: `GET /api/users/me`
liefert „Editor Test", kein Admin. **Nur diesen Zugang verwenden**, nie einen Schlüssel des
Admin-Kontos mit der echten Bibliothek.

## Noodle-Testserver

Lokal auf dem Entwicklungsrechner (Docker Desktop), getrennt von jeder echten Bibliothek:
`%USERPROFILE%\noodle-test` (Compose-Projekt `noodle-test`, Noodle Gallery v5.7.0 ohne ML,
Port 2283, Daten im Ordner). Zugang in `.env.local` dort (Admin, Testbenutzer „Editor Test").
Starten: `docker compose up -d` in dem Ordner — endet der Server, weil er vor der Datenbank
startete, `docker compose up -d immich-server` nachschieben. Der Emulator erreicht ihn unter
`http://10.0.2.2:2283`.

## Gegen welche Immich-Version gebaut wird

Der Server des Testbenutzers läuft mit **Immich 3.2.2** (seit 21.09.2026 abends; M1 wurde gegen
3.1.0 abgenommen, D-12). Die Endpunkte der Spec sind gegen `open-api/immich-openapi-specs.json`
im Tag `v3.2.2` geprüft (21.09.2026).
