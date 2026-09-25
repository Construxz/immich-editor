# Arbeitsanweisung für Agenten

**Editor for Immich** — eine eigenständige Flutter-App für Android (kein iOS, D-14), die über die Immich-API
Fotos bearbeitet: lokal und auf dem Server, nicht-destruktiv. Das Konzept steht in
[specs/0001-editor.md](specs/0001-editor.md), die Begründungen in
[docs/DECISIONS.md](docs/DECISIONS.md). Vor jeder Arbeit **STATUS, ROADMAP und die Spec lesen.**

## Unverrückbar

- **Immich wird nicht verändert.** Kein Server-Fork, keine Schemaänderung, kein Eingriff in
  Backup oder Bildverwaltung. Die App schreibt nur neue Assets und Stapel über die öffentliche
  API (D-1, D-2).
- **Getestet wird ausschließlich mit einem eigenen Immich-Testbenutzer**, nie mit der echten
  Bibliothek des Besitzers. Zugangsdaten nur in einer lokalen `.env` (ist in `.gitignore`).
- **Keine Google-Play-Dienste, kein Firebase, kein Cloud-Dienst** für Bildverarbeitung (D-6).
- **Lizenz AGPL-3.0** (D-3). Vor jeder neuen Abhängigkeit die Lizenz nachsehen und in
  [docs/LICENSES.md](docs/LICENSES.md) eintragen — zuerst nach Copyleft und nach
  nicht-kommerziellen Modellgewichten fragen.
- **Geheimnisse nie ins Git:** Signierschlüssel, `key.properties`, `.env`. Ein Geheimnis, das
  einmal committet war, bekommt man nicht wieder heraus — dann rotieren, nicht löschen.
- **Immich-Typen verlassen `server/` nicht**; Galerie und Editor arbeiten mit eigenen Modellen.

## Arbeitsweise

- In Meilensteinen aus [docs/ROADMAP.md](docs/ROADMAP.md), in ihrer Reihenfolge. Ein Meilenstein
  ist fertig, wenn seine Abnahme nachweislich erfüllt ist — gemessen, nicht angenommen.
- Das kleinste, das die Abnahme erfüllt. Keine Abstraktion auf Vorrat.
- Nicht-triviale Logik (Rezept-Format, XMP, Stapeln, Prüfsummen) bekommt einen Test.
- **Doku nach der Rollenteilung** in der README (*Documentation*): jede Aussage hat genau einen
  Besitzer. Erledigtes verlässt die ROADMAP, das Ergebnis geht mit Datum und Messweg in
  DECISIONS, der Ist-Stand wird in STATUS überschrieben. Danach `python doccheck.py`.
- Doku-Sprache wird Englisch (D-15); bis zur Übersetzung in M2 bleibt sie einheitlich Deutsch.
  ROADMAP und DECISIONS haben daneben eine englische Fassung (`*.en.md`, D-84): Wer die
  deutsche ändert, zieht die englische im selben Commit nach (DECISIONS gestrafft).
  README englisch.
- **Commits:** Dateien einzeln benennen, nie `git add -A`; die Nachricht sagt, was jetzt anders
  ist. Pushen auf `origin` (öffentlich) ist erlaubt; Tags und Releases nur nach Rückfrage.
- **App-Version mit jedem Feature anheben** (Wunsch des Besitzers): in `pubspec.yaml`
  `0.1.0-dev.N+N`, N = Nummer der jüngsten Entscheidung in DECISIONS (D-N), vor jedem Aufspielen
  aufs Telefon; ein Release-Kandidat heißt `0.1.0-rc.K+N` (D-82). Commits unter der Identität
  aus `git config` dieses Repos (GitHub-noreply), nie mit privater Adresse. Das Konto-Fenster zeigt sie; STATUS nennt den Stand auf dem Pixel.

## Umgebung

- Windows, Projekt unter `<Projektordner>`. Shells: PowerShell und Git Bash.
- Remote: `https://github.com/Construxz/immich-editor.git` (öffentlich seit 25.09.2026, D-4).
- **Ausprobieren im Emulator** `editor_pixel7pro` (STATUS), `adb` immer mit `-s emulator-5554`;
  Steuerung über `tool/emu.sh`. Das Telefon des Besitzers nur nach Rückfrage steuern — er benutzt
  es nebenher; HDR sieht man nur dort (Emulator ohne HDR-Display, Screenshots ohne HDR).
- Stolpersteine im Emulator: `gradlew connectedDebugAndroidTest` deinstalliert die App danach
  (Anmeldung weg); hängt die Texteingabe, `adb shell ime reset`; `adb`-Wischer über die
  Werkzeugleiste verstellen leicht das Lineal. Nach dem Speichern die Kopie über ihre ID
  prüfen, nie über „den ersten Suchtreffer" (D-23). Friert das Emulator-Fenster ein, obwohl
  `adb` antwortet (Screenshot zeigt Neues, das Fenster nicht): `adb emu rotate` zweimal. Nicht per
  `adb` testen, während der Besitzer den Emulator bedient — installieren und Tippen stören ihn.
  Auf dem Pixel kommt Wischen per `adb` (`input swipe`, `motionevent`) nicht als Scrollen an,
  Tippen schon — Listen dort den Besitzer scrollen lassen (D-50).
- **Ist das Pixel per USB dran, läuft `gradlew connectedDebugAndroidTest` auch dort** und
  deinstalliert die App: immer mit `ANDROID_SERIAL=emulator-5554`. `adb` in einer
  `while read`-Schleife verschluckt deren Eingabe — `adb … </dev/null`. Hängt `git push`, mit
  `GIT_TERMINAL_PROMPT=0 timeout 90 git push` wiederholen.
- **Bauen aus Git Bash:** `flutter` und `java` fehlen dort im PATH. Flutter liegt unter
  `$HOME/develop/flutter/bin/`, für `gradlew` gilt `JAVA_HOME` = JBR aus STATUS
  (*Entwicklungsumgebung*). `gradlew` bricht mit `MSYS_NO_PATHCONV=1` ab („GradleWrapperMain"),
  und `tool/emu.sh` setzt genau das — also nicht in derselben Shell bauen. **Nach jedem
  Aufspielen `dumpsys package … | grep versionName` prüfen:** Scheitert der Build in einer Kette,
  installiert `adb install` sonst die alte APK aus `build/` (so kam einmal 0.0.1 aufs Pixel).
  Aufs Pixel: `flutter build apk --release --split-per-abi`, dann die arm64-APK mit
  `install -r`, das behält die Anmeldung. Release-APKs von GitHub sind anders signiert und
  gehen nur nach Deinstallieren (Anmeldung weg).
- Zwei-Finger-Gesten lassen sich im Emulator nicht auslösen: `input` kennt einen Finger,
  `sendevent` wirkt auch mit `adb root` nicht. Pinch prüft der Besitzer auf dem Pixel (D-76).
- **Auf dem Pixel messen, ohne zu steuern** (der Besitzer bedient, der Agent liest): `adb logcat`
  mit vorübergehenden Logzeilen (D-65), `adb shell screenrecord` und die Einzelbilder mit PyAV
  auswerten (D-67), `dumpsys window`/`display` für den HDR-Zustand (D-63). Vorher ansagen, wann
  die Aufnahme läuft — sonst ist sie leer.
- Werkzeuge: siehe README, *Development*. Installationen, die Administratorrechte, Käufe oder
  Konten brauchen, übernimmt der Besitzer — vorher fragen, nicht selbst anstoßen.
