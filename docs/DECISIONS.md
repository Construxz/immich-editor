# Entscheidungen und Befunde

Eine Entscheidung oder ein Befund je Eintrag, mit Datum, Begründung und — bei Befunden — wie
gemessen wurde. **Neue Einträge oben anfügen.** Was noch zu tun ist, steht in
[ROADMAP.md](ROADMAP.md), was jetzt gilt in [STATUS.md](STATUS.md), das Konzept in
[specs/0001-editor.md](../specs/0001-editor.md).

---

## 2026-09-21 · D-20: Befund — die HDR-Vorschau wirkt auf dem Pixel

Wie geprüft: App (Stand `b38bde9` + HDR-Knopf) im Release-Build auf dem Pixel 7 Pro des
Besitzers, Editor mit `testfoto-a-hdr.jpg` (Ultra HDR, D-12) offen.

- `dumpsys window`: Fenster `colorMode=COLOR_MODE_HDR`.
- `dumpsys SurfaceFlinger`: die Ebene der App mit `currentHdrSdrRatio=5`,
  `desiredHdrSdrRatio=5`; alle anderen Ebenen 1.
- Der Besitzer hat den HDR-Knopf im Editor umgeschaltet und sieht einen Unterschied. Den
  Vergleich „helle Bildstellen heller als das Weiß der Leiste" fand er ohne Schalter schwer zu
  beurteilen — der direkte Umschalter macht ihn sichtbar.

Screenshots (`screencap`) zeichnen HDR nicht auf; im Emulator gibt es kein HDR-Display
(`supportedHdrTypes=[]`).

**Anwenden:** Der Weg aus D-17 trägt: gerendertes sRGB-Bild + Gain-Map in einer nativen Ansicht
(Hybrid Composition) im HDR-Fenster. Die HDR-Anzeige bleibt ein Test auf dem Gerät.

## 2026-09-21 · D-19: Kopien sind Standard-Ultra-HDR — Immich zeigt sie, sobald es HDR kann

Anforderung des Besitzers: So, wie die App HDR-Kopien in Immich ablegt, sollen sie ohne
Nacharbeit in HDR erscheinen, sobald Immich upstream Ultra HDR darstellt
([immich#7262](https://github.com/immich-app/immich/discussions/7262): Web teilweise, Server über
libvips 8.18, Mobil über native Ansichten geplant).

Befund, wie geprüft: die Kopie aus D-16 mit **libvips 8.18.6** (`pyvips-binary`), dessen
Ultra-HDR-Lader auf Googles libultrahdr aufbaut — dem Weg, den Immichs Server nimmt.

| | Lader | Gain-Map | max. Content-Boost | HDR-Kapazität |
|---|---|---|---|---|
| Original | `uhdrload` | 697×926 | 4,652 | 4,652 |
| Kopie (D-16) | `uhdrload` | 697×926 | 4,653 | 4,653 |
| Kopie aus M1 (Gegenprobe) | `jpegload` | — | — | — |

Dazu D-16: Androids Dekoder liest dieselben Werte; Immich speichert die Datei Byte für Byte (D-12).

**Anwenden:** Kein eigenes HDR-Format; die Kopie bleibt Standard-Ultra-HDR (`hdrgm`-XMP,
ISO 21496-1, MPF) und liegt vorn im Stapel. Jede Änderung am Export wird mit `uhdrload`
gegengeprüft (M2-Abnahme).

## 2026-09-21 · D-18: Mindestens Android 14 (API 34)

AGSL-Shader (D-17) gibt es ab Android 13, die Gain-Map-API und HDR-Fenster ab Android 14. Mit
Android 14 als Untergrenze gibt es einen Weg statt zwei; Android 14 ist von 2023. Entschieden vom
Besitzer.

**Anwenden:** `minSdk = 34`; kein Code für ältere Versionen.

## 2026-09-21 · D-17: Renderer nativ in Android — für eine echte HDR-Vorschau

Befund: Flutter kann auf Android kein HDR darstellen — Wide Gamut gibt es nur auf iOS, Gain-Maps
gar nicht (Flutter-Doku, Stand 3.47). Immichs Maintainer kamen zum selben Schluss: „Displaying
Ultra HDR images likely requires us to write a custom image library backed by native
Kotlin/Swift viewers" ([immich#7262](https://github.com/immich-app/immich/discussions/7262),
März 2025); die Flutter-Galerie Aves wartet seit 2023 auf Flutter
([aves#838](https://github.com/deckerst/aves/issues/838)).

Der Besitzer will eine HDR-Vorschau beim Bearbeiten wie in Google Fotos — damit deren Nutzer
ohne Verlust wechseln können — und HDR in den Einstellungen abschaltbar.

Entscheidung: **Die Bildberechnung lebt in Android** (Kotlin, AGSL-Shader auf der GPU), für
Vorschau und Export — weiter ein Renderer (D-2). Die Bildfläche im Editor ist eine native
Android-Ansicht im HDR-Fenster; Android zeigt ein Bild mit Gain-Map selbst in HDR. Geometrie
wirkt mit derselben Rechnung auf Bild und Gain-Map. Flutter bleibt für Bedienung, Galerie,
Server und das Zusammensetzen der Datei (`jpeg.dart`); das Rezept wandert als JSON über einen
Kanal. Ersetzt „Vorschau per Fragment-Shader" der Spec.

**Anwenden:** Bildmathematik in AGSL/Kotlin; Tests dafür laufen als Instrumented Tests im
Emulator. Die HDR-Darstellung selbst lässt sich nur auf einem Gerät mit HDR-Display prüfen
(Pixel des Besitzers, nach Rückfrage).

## 2026-09-21 · D-16: Ultra HDR — die Kopie behält die Gain-Map (E2)

Umsetzung: Der Kodierkanal bekommt das Original, Android (ab 14, API 34) dekodiert es samt
Gain-Map; die hängt an der bearbeiteten Bitmap, und `Bitmap.compress` schreibt ein
Ultra-HDR-JPEG. Tonwert-Änderungen wirken damit auf SDR- und HDR-Darstellung gleich — die
Gain-Map beschreibt das Verhältnis HDR/SDR, nicht absolute Helligkeit. Unter Android 14 geht die
Gain-Map verloren (wie in D-12).

Befund zur Ausgabe des Kodierers (Emulator und Pixel 7 Pro, API 37): JFIF, ein eigenes kleines
EXIF, ein XMP-Paket mit `hdrgm:Version` und Gain-Map-Verzeichnis (`Container:Directory`), ICC,
ISO-21496-1-Metadaten, MPF hinter den Tabellen; die Gain-Map als zweites JPEG mit eigenem
`hdrgm`-XMP und ISO-21496-1. Einfach EXIF und Rezept-XMP davorzusetzen ergab je **zwei** EXIF-
und XMP-Segmente und eine MPF-Größe des Hauptbilds, die unsere Segmente nicht mitzählte. Deshalb
arbeitet `zusammensetzen` jetzt auf Segmenten: EXIF des Originals ersetzt das des Kodierers, das
Rezept geht ins vorhandene XMP-Paket, MPF wird angepasst.

Wie geprüft, mit `testfoto-a-hdr2.jpg` (das Testfoto A aus D-12 mit zwei Nullbytes am
Ende, damit Immich es nicht als Duplikat ablehnt), App im Emulator, Helligkeit +0,33:

- App: „Gespeichert und geprüft" (Byte-Vergleich), 13 s bis zur Meldung.
- Struktur der Kopie: ein EXIF (das des Originals), ein XMP mit `ife:recipe` **und**
  `hdrgm:Version`, MPF-Größe des Hauptbilds 2 847 906 = Beginn der Gain-Map; Gain-Map-Metadaten
  wie im Original (`GainMapMax` 2,217993).
- **Androids eigener Dekoder** (`BitmapFactory`, vorübergehender Prüfaufruf im Emulator):
  Original — Gain-Map 697×926, `ratioMax` 4,6525; Kopie — Gain-Map 697×926, `ratioMax` 4,6525;
  Gegenprobe Kopie aus M1 — keine Gain-Map.
- Stapel, Aufnahmezeit, Ort wie in D-12.
- Test `jpeg_test.dart` mit einem winzigen Ultra-HDR-Fixture im selben Aufbau
  (`test/fixtures/ultrahdr_klein.py`).

Nebenbefunde:

- Pixel-Fotos sind oft **Motion Photos** (Video am Dateiende, `GCamera:MotionPhoto`); die Kopie
  ist ein Standbild — für eine Bearbeitung richtig.
- Die Vorschau im Editor ist SDR; Flutter dekodiert ohne Gain-Map.

**Anwenden:** Geometrie-Werkzeuge (M2) müssen die Gain-Map mittransformieren — sonst passt sie
nicht mehr zum Bild. Eine HDR-Vorschau ist offen.

## 2026-09-21 · D-15: Doku und Specs auf Englisch (E3)

Das Repo wird öffentlich (D-4), die Immich-Community schreibt Englisch. Entschieden vom
Besitzer. Die bestehende Doku ist noch Deutsch.

**Anwenden:** Specs, `docs/` und `CLAUDE.md` werden in einem Durchgang übersetzt, spätestens
bevor das Repo öffentlich wird (M2 in [ROADMAP.md](ROADMAP.md)); bis dahin bleibt die Doku
einheitlich Deutsch. Code-Bezeichner bleiben, wie sie sind.

## 2026-09-21 · D-14: Nur Android, kein iOS

Der Besitzer hat keine Apple-Geräte und kann iOS weder bauen noch testen; ungetesteter
iOS-Code wäre ein Versprechen, das niemand prüft. Entschieden vom Besitzer. Der Ordner `ios/`
ist entfernt, E5 (iOS-Build in der CI) entfällt, ebenso die iOS-Seite des Kodierkanals (D-13).

**Anwenden:** Android-APIs direkt nutzen, wo sie etwas billig lösen (Kodierer, Gain-Map).
Kommt iOS später — etwa durch die Community —, erzeugt `flutter create --platforms ios .` das
Gerüst neu; dann braucht jeder Plattformkanal eine Gegenseite.

## 2026-09-21 · D-13: JPEG-Kodierer — der des Systems, nicht Dart (E1)

Wie gemessen: Pixel 7 Pro, Release-Build, ein 12,5-MP-Kamerafoto (3072×4080, Pixel 7 Pro,
s. D-12), je drei Läufe; Zeiten nach dem ersten Lauf stabil.

| Schritt | Zeit | Größe (Qualität 95) |
|---|---|---|
| Dekodieren (`instantiateImageCodec`) | 111–159 ms | |
| Rendern mit Rezept + RGBA auslesen | 77–89 ms | |
| **`Bitmap.compress`** über Plattformkanal, inkl. Übergabe von 48 MB RGBA | **248–355 ms** | 2,82 MB |
| `image` 4.10.1 (reines Dart, `encodeJpg`) | 3 191–3 215 ms | 3,35 MB |

Gewählt: **der Systemkodierer** — zwölfmal schneller, kleinere Dateien, keine Abhängigkeit
(ein Plattformkanal `immich_editor/jpeg` in `MainActivity.kt`). Preis: je Plattform eine
Gegenseite (für iOS entfallen, D-14).

**Anwenden:** Export kodiert über den Kanal. Der Android-Kodierer schreibt ein eigenes
sRGB-ICC-Profil; ob Fotos mit Display-P3-Profil farbtreu bleiben, ist nicht geprüft (beide
Testfotos sind sRGB).

## 2026-09-21 · D-12: Befund — M1 abgenommen: der Speicherweg trägt (D-2 bestätigt)

Wie geprüft, mit dem Testbenutzer „Editor Test" (STATUS) gegen Immich 3.1.0, App im
Release-Build auf einem Pixel 7 Pro:

- Testfotos von Wikimedia Commons, Pixel 7 Pro, CC BY-SA 4.0 (nur auf dem Testserver, nicht im
  Repo): „<Ort>" (03.05.2026, mit Ultra-HDR-Gain-Map) und
  „<Ort>" (30.10.2022). Beide mit EXIF-Zeit samt Zeitzone und GPS,
  beide im Album „M1-Test".
- In der App je ein Foto geöffnet, Helligkeit geändert (Testfoto A +0,32, Testfoto B dunkler),
  gespeichert. Die App lädt die Kopie danach über `/original` und vergleicht sie **Byte für
  Byte** mit dem Gesendeten, erst dann stapelt sie: „Gespeichert und geprüft" (Testfoto B).
  Unabhängig davon: SHA-1 der heruntergeladenen Testfoto-A-Kopie = Immichs `checksum`.
- Per API: Kopie ist `primaryAssetId` des Stapels (2 Assets); `localDateTime`, Zeitzone,
  Koordinaten und Ort der Kopie gleich denen des Originals; Album „M1-Test" enthält die Kopien.
  XMP der Kopie enthält `ife:recipe` und `ife:originalSha1` = `checksum` des Originals.
  Mittlere Helligkeit der Testfoto-A-Kopie +40,6 (erwartet 0,32 × 128 ≈ 40,8): Vorschau und
  Export rechnen gleich.
- Der Besitzer hat in Immichs Weboberfläche als Testbenutzer geprüft: Die Stapel werden korrekt
  angezeigt, die Bearbeitung vorn.
- Dauer vom Tippen auf „Speichern" bis zurück in der Galerie: 7,5 s (Rendern, Kodieren,
  Upload, erneuter Download zum Vergleich, Stapel, Alben; WLAN).

Nebenbefunde:

- **Die Gain-Map geht verloren**, wie in D-8 erwartet: Kopien tragen weder MPF noch das
  Google-XMP des Originals (E2).
- Das übernommene EXIF enthält die Miniatur (IFD1) des **unbearbeiteten** Originals. Immich
  erzeugt eigene Vorschauen; andere Betrachter könnten die alte zeigen.
- `POST /search/metadata` liefert auch die hinteren Assets eines Stapels — die Galerie zeigt
  Originale derzeit doppelt (M2).
- Flutter wendet die EXIF-Orientierung beim Dekodieren an (Test `jpeg_test.dart`); die Kopie
  bekommt deshalb Orientierung 1.

**Anwenden:** Der Weg „neues Asset + Rezept-XMP + Stapel" ist tragfähig; M2 baut darauf.

## 2026-09-21 · D-11: Befund — M0 abgenommen: signierte APK aus dem Tag läuft auf dem Gerät

Wie geprüft:

- `flutter doctor` auf dem Entwicklungsrechner: „No issues found" (Versionen in
  [STATUS.md](STATUS.md)).
- `ci.yml` grün auf GitHub für `f7245f2` und `e2ce157` (format, analyze, test, Debug-APK),
  je etwa 6½ Minuten.
- Tag `v0.0.1` auf `e2ce157`: `release.yml` grün (Lauf 35618926008), Release mit vier APKs
  (arm64-v8a, armeabi-v7a, x86_64, universal) und `SHA256SUMS.txt`. Heruntergeladen,
  `sha256sum -c` für alle vier OK; `apksigner verify` für arm64-v8a: Schema v2, Zertifikat
  `CN=Construxz`, SHA-256 `9adfffc3…149a131f` — nicht der Debug-Schlüssel.
- Die arm64-APK per `adb install` auf ein Pixel 7 Pro installiert: `versionName=0.0.1`,
  `versionCode=2001`, die App startet ohne Absturz im Log. Vorher per `flutter run` im
  Debug-Modus auf demselben Gerät.

Nebenbefunde:

- **Debug- und Release-Build tragen verschiedene Schlüssel.** Beim Wechsel die App vorher
  deinstallieren (`adb uninstall io.github.construxz.photoeditor`).
- **versionCode im Release** = 1000 × ABI + Laufnummer von `release.yml`
  (`--build-number=github.run_number`), versionName aus dem Tag. `pubspec.yaml` zählt nur lokal.
- `sdkmanager` 23.0 stürzt auf Windows am Ende jedes Aufrufs ab (0xC0000409); Gradle lädt
  fehlende SDK-Teile (NDK 28.2) trotzdem selbst nach. Der erste Build nach frischer
  Einrichtung scheiterte einmal daran — wiederholen genügte.
- AGP 9.1 / Gradle 9.3.1 laufen mit dem JDK 25 aus Android Studio; die CI nutzt Temurin 25.

**Anwenden:** Releases entstehen nur über einen Tag `v*`; der Schlüssel liegt beim Besitzer
außerhalb des Repos und als vier Secrets in GitHub.

## 2026-09-21 · D-10: Application-ID `io.github.construxz.photoeditor`

Android-Application-ID und iOS-Bundle-ID; der Dart-Paketname bleibt `immich_editor`. Ohne
„immich" in der ID, weil sie nach dem ersten Store-Upload nicht mehr zu ändern ist — sie passt
auch, falls die Namensnutzung (D-5) beanstandet wird oder weitere Backends dazukommen.
`io.github.construxz` ist der GitHub-Namensraum des Besitzers.

## 2026-09-21 · D-9: IMG.LY Photo SDK verworfen

Geprüft als fertige Editor-Basis. Laut Anbieter „typische Deployments 600–2 000 $/Monat",
abgerechnet nach monatlich aktiven Nutzern; proprietär, also nicht mit AGPL vereinbar; und als
Canva-artiger CreativeEditor weit größer als der angestrebte Umfang.

**Anwenden:** Kein kommerzielles SDK als Kern. Offene Bausteine stehen in
[LICENSES.md](LICENSES.md).

## 2026-09-21 · D-8: Befund — neu kodierte Kopien verlieren die HDR-Gain-Map

Wie geprüft: je ein Original von fünf Tagen (2024–2026) einer Pixel-7-Pro-Bibliothek über
`GET /api/assets/{id}/original` geladen und nach `hdrgm` gesucht. Ein Foto (2024) trug eine
Ultra-HDR-Gain-Map, vier (2025/2026) nicht. Fünf Bilder sind keine Verteilung, zeigen aber:
Beides kommt vor.

**Anwenden:** Jede Bearbeitung erzeugt eine neu kodierte Kopie. Nimmt der Export die Gain-Map
nicht ausdrücklich mit, geht HDR stillschweigend verloren. Der Export muss sie übertragen,
bevor Fotos mit Gain-Map bearbeitet werden.

## 2026-09-21 · D-7: Befund — Handy-Bibliotheken sind JPEG-Bibliotheken

Wie gemessen: Dateiendung und EXIF-Kameramodell aller 13 660 Bilder aus 2025–2026 einer
Immich-Bibliothek (Timeline und Archiv, `POST /api/search/metadata`).

| Endung | Anteil | | Kamera | Anteil |
|---|---|---|---|---|
| JPG | 99,7 % | | Pixel 7 Pro | 81,1 % |
| PNG | 0,3 % | | Canon EOS R7 | 17,3 % |
| RAW | **0,0 %** | | DJI | 0,8 % |

Auch die Systemkamera lieferte ausschließlich JPEG.

**Anwenden:** Erst JPEG, RAW zuletzt, wenn überhaupt. Ein RAW-Entwickler als Ausgangspunkt
bearbeitet nichts von dem, was solche Bibliotheken enthalten.

## 2026-09-21 · D-6: KI auf dem Gerät mit offenen Modellen, keine Google-Dienste

Drei Orte standen zur Wahl: offene Modelle auf dem Gerät, die KI des Betriebssystems, das ML
des Servers. Gewählt: **auf dem Gerät, offene Modelle, beim ersten Gebrauch geladen.** Die
Betriebssystem-KI fällt auf Android weg, weil ML Kit seine Modelle über die Google
Play-Dienste lädt; Server-ML ist unterwegs nicht verlässlich erreichbar. Offen: ob MediaPipe
zulässig ist — Code von Google, aber Apache-2.0, vollständig lokal, ohne Dienstaufruf.

**Anwenden:** Keine Abhängigkeit von Google-Play-Diensten oder Firebase — das hält auch
F-Droid offen.

## 2026-09-21 · D-5: Name „immich-editor", Titel „Editor for Immich"

Repository `immich-editor`; in App und README „Editor for Immich — An open-source mobile photo
library and editor for Immich". Bewusst generisch, bis sich zeigt, ob das Projekt Resonanz
findet.

Befund zur Namensnutzung (21.09.2026):

- Die Marke „Immich" gehört FUTO. Das [Immich-FAQ](https://docs.immich.app/FAQ/) sagt:
  Integrationen seien „typically approved, provided proper notification is given"; man dürfe
  nicht als offiziell verbunden auftreten; Rückfragen an questions@immich.app.
- Immichs Liste [awesome.immich.app](https://awesome.immich.app/) führt viele
  „Immich X"-Projekte. „immich-edit" (haavardnk) und „Immich Companion" sind vergeben;
  `immich-editor` war auf GitHub frei.

**Anwenden:** README und App sagen „inoffiziell". Kein Immich-Logo im App-Icon. Vor dem
öffentlichen Release eine Mail an questions@immich.app (Name, „inoffiziell, API-Client,
verändert nichts am Server", Link). Für die Stores prüfen, ob „Immich" im Titel stehen darf.

## 2026-09-21 · D-4: Vertrieb zuerst über GitHub Releases, Repo privat bis zum ersten Release

APK aus GitHub Actions an GitHub-Releases, später Google Play und App Store. Das Repository
bleibt privat, bis der erste Release (Meilenstein M2 in [ROADMAP.md](ROADMAP.md)) steht —
keine halbfertigen Versprechen an die Community.

## 2026-09-21 · D-3: Lizenz AGPL-3.0

Wie Immich. Jede weitergegebene Veränderung bleibt offen, und Code aus Immich und anderen
AGPL-Projekten darf übernommen werden. Apache-2.0- und MIT-Code ist verträglich, mit
Herkunftshinweis in einer `NOTICE`-Datei. Alle Abhängigkeiten stehen in
[LICENSES.md](LICENSES.md).

## 2026-09-21 · D-2: Speichern als Kopie mit Rezept-XMP, mit dem Original gestapelt

Befund, nachgesehen in `immich-app/immich`, Zweig `main`: Immich speichert eigene Bearbeitungen
als Rezept in der Tabelle `asset_edit` und rendert sie serverseitig mit Sharp
(`server/src/repositories/media.repository.ts`, `applyEdits`). Erlaubt sind nur `crop`,
`rotate` (0/90/180/270°) und `mirror` — ein zod-Enum in `server/src/dtos/editing.dto.ts`;
jede andere Aktion lehnt der Server ab. Stapel lassen sich über die Standard-API anlegen
(`POST /api/stacks`, `assetIds`, „first becomes primary, min 2").

Entscheidung: Die App rendert auf dem Gerät, lädt das Ergebnis als **neues Asset** hoch, trägt
das Rezept als **XMP im eigenen Namensraum** in der Kopie und **stapelt die Kopie vor das
Original**. Begründung: kein Server-Fork nötig; vollständig umkehrbar (nur gewöhnliche Assets
und Stapel); und es gibt nur **einen** Renderer — ein Weg über `asset_edit` hätte dieselbe
Bildmathematik zusätzlich in Sharp gebraucht, das Perspektive, 3D-LUTs, Spitzlichter und Masken
nicht direkt kann. Preis: jede bearbeitete Aufnahme liegt zweimal auf dem Server.

Ausgeführt in [specs/0001-editor.md](../specs/0001-editor.md).

## 2026-09-21 · D-1: Eigenständige Flutter-App, Immich bleibt unverändert

Eine eigene App für Android und iOS, die Immich nur über dessen API anspricht — kein Fork von
Immichs App oder Server. Die Immich-App bleibt Bibliothek und Backup. Begründung: Immich hatte
einen Editor mehrfach im Blick und wieder verworfen; ein eigenständiger Client entwickelt sich
unabhängig davon und ändert nichts Irreversibles am Server. Flutter, weil Immichs eigene App
Flutter ist und damit beide Plattformen aus einem Code entstehen.
