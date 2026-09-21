# 0001 — Editor for Immich: Umfang, Speicherweg, Projektplan

**Stand 21.09.2026.** Erste Spec des Projekts, nichts gebaut. Arbeitssprache der Specs ist
Deutsch; vor dem Öffentlichmachen entscheiden, ob sie übersetzt werden.

## Ziele

1. **Umfang und Bedienung wie der Editor in Google Fotos** — einfach, kein Snapseed, kein
   Lightroom.
2. **Dazu, was Google fehlt:** lokale Anpassungen mit Masken (keine Ebenen) und eigene
   Presets, die sich auf viele Bilder zugleich anwenden lassen.
3. **Alles, was geht, auf dem Gerät gerechnet**, ohne Cloud-Dienst — auch ohne Google-Dienste.
4. **Eine eigenständige Flutter-App** für Android und iOS, mit eigener Galerie über lokale
   Fotos **und** den Immich-Server; Bearbeiten ohne Umweg über Teilen, Mehrfachauswahl
   inklusive.
5. **Immich bleibt unverändert.** Kein Server-Fork, keine Schemaänderung, kein Eingriff in
   Backup oder Bildverwaltung — dafür bleibt die Immich-App zuständig. Warum eigenständig:
   Immich hatte einen Editor mehrfach im Blick und hat ihn wieder fallen lassen.

**Rollen:**

| | Immich-App | Editor for Immich | Immich-Server |
|---|---|---|---|
| Rolle | Bibliothek und Backup | Auswählen, Bearbeiten, Presets | Speicher und Anzeige |
| sieht | alle Fotos | lokale Fotos und Server-Assets über die API | Original, Kopie, Stapel |
| schreibt | Backups | bearbeitete Kopien und Stapel über die API | — |

## Speichern: Kopie plus Rezept, mit dem Original gestapelt

Immich speichert eigene Bearbeitungen als Rezept in der Tabelle **`asset_edit`** und rendert
sie serverseitig mit Sharp (`server/src/repositories/media.repository.ts`, `applyEdits`).
Erlaubt sind nur **`crop`, `rotate` (0/90/180/270°), `mirror`**, geprüft über ein zod-Enum
(`server/src/dtos/editing.dto.ts`); jede andere Aktion lehnt der Server ab (nachgesehen in
`immich-app/immich`, `main`, 21.09.2026). Neue Werkzeuge dort einzubauen hieße Server-Fork.

Deshalb:

1. **Die App rendert das fertige Bild auf dem Gerät** und legt es als **neues Asset** an.
2. **Das Rezept reist im Bild mit** — als XMP in einem eigenen Namensraum, so wie Lightroom
   (`crs:`) und darktable ihre Entwicklungseinstellungen schreiben: alle Einstellungen und die
   Prüfsumme des Originals. Immich verändert hochgeladene Dateien nicht; der Server muss das
   Rezept nicht kennen.
3. **Kopie und Original werden gestapelt**, die Kopie vorn — per Standard-API
   (`POST /api/stacks`, `assetIds`, „first becomes primary, min 2"; Wechsel per
   `PUT /api/stacks/{id}`). Immichs Timeline zeigt die Bearbeitung, das Original liegt im
   Stapel.
4. **Die Kopie erbt Aufnahmezeit, Ort und Alben des Originals**, damit sie in Timeline, Karte
   und Alben an derselben Stelle steht.
5. **Erneut bearbeiten:** Original laden, Rezept aus der Kopie lesen, weiterbearbeiten, neue
   Kopie an den Stapel, alte Kopie in den Papierkorb (dort umkehrbar).

Vorteile: vollständig umkehrbar (nur gewöhnliche Assets und Stapel), und es gibt **einen
einzigen Renderer** — auf dem Gerät. Ein Weg über Immichs `asset_edit` hätte dieselbe
Bildmathematik zusätzlich in Sharp gebraucht, das Perspektive, 3D-LUTs, Spitzlichter und
Masken nicht direkt kann. Preis: jede bearbeitete Aufnahme liegt zweimal auf dem Server.

**Fotos, die nur auf dem Gerät liegen:** Die App schreibt die Kopie (mit Rezept-XMP) in die
Gerätegalerie; die Immich-App sichert beide wie jedes andere Foto. Gestapelt wird, sobald
beide auf dem Server sind — die Prüfsumme im XMP ordnet sie zu. Bis dahin stehen beide kurz
nebeneinander.

**Zu prüfen:** ob Immich Gesichter und Suchtreffer gestapelter, nicht vorne liegender Assets
ausblendet oder doppelt zählt.

## Die Galerie

Lokal über **`photo_manager`** (Apache-2.0; dieselbe Bibliothek nutzt Immichs App), Server
über einen schmalen Immich-Client (s. Projektplan). Zusammengeführt über die Prüfsumme: Ein
Gerätefoto, dessen Prüfsumme der Server kennt, ist gesichert. Das ist der größte Einzelposten —
Thumbnails, Blättern durch Zehntausende Bilder, Zwischenspeicher — und die Voraussetzung dafür,
mehrere Bilder zu wählen und allen ein Preset zu geben.

**Andere Bibliotheken später:** Die App könnte auch andere selbst gehostete Bibliotheken
ansprechen (etwa PhotoPrism, das ebenfalls keinen richtigen Editor hat) — langfristig oder
durch die Community. Heute keine Abstraktion dafür, aber eine saubere Naht: alle
Server-Aufrufe in `server/`, und **Immich-Typen verlassen dieses Modul nicht**; Galerie und
Editor arbeiten mit einem eigenen `Foto`-Modell. Das XMP-Rezept ist ohnehin backend-neutral.
Offen wäre je Backend nur, wie dort Original und Kopie verknüpft werden.

## Funktionen, nach Aufwand eingeteilt

Vorbild ist der Bearbeiten-Bereich von Google Fotos (Stand 09/2026), ohne dessen
Cloud-KI.

**Stufe 1 — reine Rechnung.** Ein Shader, ein Rezept-Eintrag. Der Kern.

| Funktion | Umsetzung |
|---|---|
| Zuschneiden, Drehen, Spiegeln, Gerade ausrichten | Affin-Transformation, freie Winkel |
| Perspektive | Vier-Punkt-Homographie |
| Helligkeit, Kontrast, Weißpunkt, Schwarzpunkt, Ton | Tonwertkurve aus wenigen Parametern |
| Spitzlichter, Schatten | tonwertabhängige Anhebung/Absenkung |
| Sättigung, Wärme, Färbung | Farbmatrix |
| Blautöne | farbtonselektive Sättigung/Helligkeit (HSL) |
| Vignettierung | radiale Abdunklung |
| Scharfzeichnen | Unscharfmaske |
| Filter | 3D-LUT — eigene Looks, nicht fremde nachmessen |
| Stift, Textmarker, Text | Vektoren im Rezept |

**Stufe 2 — klassische Bildverarbeitung.** Kein Modell, aber mehr als eine Formel.

| Funktion | Umsetzung |
|---|---|
| Pop | lokaler Kontrast (großer Radius, geringe Stärke) |
| Rauschen entfernen | Bilateral- oder Guided-Filter; ein Modell erst, wenn das nicht reicht |
| Bester Bildausschnitt | Auffälligkeitskarte (Saliency) + Drittelregel |
| Hautton | Farbbereich um Hauttöne — grob ohne Modell, gut mit Personenmaske |
| Ultra HDR | Gain-Map erhalten und skalieren (s. unten) |

**Stufe 3 — braucht ein Modell.** Fast alles davon ist *eine* Fähigkeit: **Freistellen**.

| Funktion | braucht |
|---|---|
| Hintergrund weichzeichnen | Personen-/Motivmaske (+ optional Tiefe) |
| Himmel-Effekt | Himmelsmaske + Look |
| Portraitbeleuchtung | Gesicht + Tiefe/Normalen |
| Radierer, Retusche | Maske per Antippen + Inpainting |
| Verschieben | Maske + Inpainting + Einsetzen — nur angenähert; zuletzt |
| Unscharfes scharf stellen | Entschärfungs-Modell, auf dem Handy schwer; zuletzt |

„In anderer App öffnen" liefert eine Datei ohne Rezept und ohne Stapel zurück — weglassen
oder nur als „Kopie exportieren" anbieten.

## Masken statt Ebenen

Nach dem Muster von Lightroom Mobile: **keine Ebenen, sondern lokale Anpassungen** — eine
Maske plus ein eigener Satz derselben Regler. Maskenquellen: Pinsel, linearer und radialer
Verlauf, mit Stufe 3 „Motiv", „Himmel", „Person".

**Retusche hat dieselbe Form:** Maske plus Pixel-Flicken statt Reglerwerten. Zwei Rezept-Arten
— `local` (Maske + Regler) und `patch` (Maske + Flicken) —, und jedes KI-Werkzeug ist nur ein
weiterer Weg, eine Maske zu erzeugen.

**Gespeichert wird das Ergebnis des Modells, nicht sein Aufruf.** Pinsel und Verläufe sind
Vektoren und passen klein ins XMP; KI-Masken und Flicken verkleinert als eingebettetes PNG.
Wie groß ein Rezept mit mehreren Flicken wird, ist am ersten Prototyp zu messen.

## Presets

Ein Preset ist **ein Rezept ohne Geometrie und ohne Masken** — Regler, Kurve, Look. Zuerst in
der App gespeichert; später auf dem Server abgelegt, ohne Schemaänderung (etwa als kleine
Datei in einem eigenen Album). Wichtiger als das Speichern ist das **Anwenden auf viele Bilder
auf einmal** — gehört in den ersten Wurf.

## KI ohne Cloud-Dienst

| Ort | Vorteil | Nachteil |
|---|---|---|
| **Auf dem Gerät, offene Modelle** (ONNX Runtime / TFLite) | offline, kein Dienst, überall gleich | App wird größer (Modelle ~10–200 MB, besser nachladbar) |
| **KI des Betriebssystems** | nichts mitzuliefern | Android: ML Kit lädt Modelle über die Google Play-Dienste — ausgeschlossen; iOS: Vision-Freistellung lokal, aber nur dort |
| **Server-ML** (z. B. Immich-ML) | starke Modelle | nur nach Upload und bei laufendem Server — unterwegs nicht verlässlich |

**Gewählt:** auf dem Gerät mit offenen Modellen, beim ersten Gebrauch geladen. Offen: ob
MediaPipe zulässig ist — Code von Google, aber Apache-2.0, vollständig lokal, ruft keinen
Dienst auf.

Kandidaten, **Lizenzen jeweils vor Übernahme prüfen** (noch nicht nachgesehen):

| Zweck | Kandidat | Lizenz (ungeprüft) |
|---|---|---|
| Person freistellen | MediaPipe Selfie/Interactive Segmenter | Apache-2.0 |
| Objekt per Antippen | MobileSAM / EfficientSAM | Apache-2.0 |
| Himmel | Segmentierung mit Klasse „Himmel" (ADE20K) | je nach Modell |
| Inpainting | MI-GAN (für Mobilgeräte gebaut) oder LaMa | MIT bzw. Apache-2.0 |
| Tiefe | Depth Anything V2 **Small** | Apache-2.0 — Base/Large sind CC-BY-NC, nicht verwendbar |

## Ultra HDR

Neuere Android-Kameras (etwa Pixel) schreiben JPEGs mit **Gain-Map** (`hdrgm`). Eine Stichprobe
an echten Pixel-Fotos zeigte beides — mit und ohne Gain-Map. Die Regel: **Wer neu kodiert,
verliert die Gain-Map**, wenn er sie nicht ausdrücklich mitnimmt. Weil jede Bearbeitung eine
neu kodierte Kopie ist, muss die App sie übertragen.

## Grundlagen und Vorbilder

| Projekt | Lizenz | Beitrag |
|---|---|---|
| [T8RIN/ImageToolbox](https://github.com/T8RIN/ImageToolbox) | Apache-2.0 | Algorithmen-Vorlage: GPU-Filter, Freistellen mit vielen Modellen auf dem Gerät, Spot-Healing, freies Drehen, Perspektive, Stapelverarbeitung; FOSS-Variante ohne Google. Kotlin — portieren, nicht einbinden. Modell-Lizenzen einzeln prüfen (`MlKit` ausgeschlossen, RMBG von BRIA vermutlich nicht frei) |
| [burhanrashid52/PhotoEditor](https://github.com/burhanrashid52/PhotoEditor) | MIT | Vorlage für Zeichnen, Text, Rückgängig |
| [open-noodle/gallery](https://github.com/open-noodle/gallery) | AGPL-3.0 | Community-Fork von Immich: erweitern, ohne sich festzulegen; eine Spec je Feature. Deren Editing-Spec nennt Farbanpassungen und den mobilen Editor *Out of Scope* |
| [haavardnk/immich-edit](https://github.com/haavardnk/immich-edit) | AGPL-3.0-only | RAW-Entwickler, server-gerendert (Rust + `wgpu`); Lektüre |
| [dev-nick421/immich-swipe](https://github.com/dev-nick421/immich-swipe) | **keine** | Bedienmuster; nur lesen, nicht übernehmen |
| [IMG.LY Photo SDK](https://img.ly/products/photo-sdk/) | proprietär | **verworfen:** laut Anbieter typisch 600–2 000 $/Monat, proprietär, zu groß |

**Handy-Bibliotheken sind JPEG-Bibliotheken.** In einer gemessenen Bibliothek (13 660 Bilder
2025–2026, Pixel und Canon R7) waren 99,7 % JPEG und 0 % RAW. RAW kommt, wenn überhaupt,
zuletzt.

## Name und Marke

Repo `immich-editor`, in App und README **„Editor for Immich"**, bewusst generisch, bis sich
zeigt, ob das Projekt Resonanz findet.

- Die Marke „Immich" gehört FUTO. Laut Immich-FAQ werden Integrationen „typically approved,
  provided proper notification is given"; man darf nicht als offiziell verbunden auftreten;
  Rückfragen an **questions@immich.app**.
- Immichs eigene Liste [awesome.immich.app](https://awesome.immich.app/) führt viele
  „Immich X"-Projekte; „immich-edit" und „Immich Companion" sind dort schon vergeben,
  `immich-editor` war es am 21.09.2026 nicht.
- **Vor dem öffentlichen Release:** Mail an questions@immich.app (Name, „inoffiziell,
  API-Client, verändert nichts am Server", Link). Kein Immich-Logo im App-Icon. Für die Stores
  prüfen, ob „Immich" im Titel stehen darf, sonst Titel ohne und „for Immich" in der
  Beschreibung.

## Projektplan

Entschieden am 21.09.2026: **AGPL-3.0** wie Immich; Vertrieb **zuerst als APK über GitHub
Releases**, später Google Play und App Store; Repo **privat, öffentlich ab dem ersten
Release**.

### Werkzeuge

| Was | Wofür | Hinweis |
|---|---|---|
| **Flutter SDK**, Kanal stable | Framework, bringt Dart mit | nicht unter „Programme" installieren |
| **JDK** in der Version, die `flutter doctor` verlangt | Gradle-Build für Android | ändert sich mit dem Android-Gradle-Plugin |
| **Android SDK**: cmdline-tools, platform-tools, eine Plattform, build-tools | Bauen, `adb` | per Android Studio oder cmdline-tools |
| **VS Code** + Erweiterungen *Flutter* und *Dart* | Entwickeln | |
| **echtes Gerät per USB-Debugging** | Testen | besser als ein Emulator: echte Galerie, echte Kamera-JPEGs |

**Android Studio ist nicht nötig**, aber der bequemste Weg, das SDK einzurichten und einen
Emulator zu haben. **iOS baut nur auf macOS mit Xcode** — bis zum App Store übernimmt das ein
macOS-Runner in GitHub Actions.
*Abnahme:* `flutter doctor` ohne Fehler für Android; `flutter run` startet auf dem Gerät.

### Repository

- `LICENSE` AGPL-3.0 ab dem ersten Commit. Übernommener Apache-/MIT-Code bekommt seine
  Herkunft in eine `NOTICE`-Datei; Code aus Immich (AGPL) darf übernommen werden.
- `.gitignore` enthält vom ersten Tag an Signierschlüssel und `.env` — ein Geheimnis, das einmal
  im Git war, bekommt man nicht wieder heraus.
- Eine Spec je Feature unter `specs/`.

### Aufbau

| Baustein | Inhalt | Abhängigkeit |
|---|---|---|
| `server/` | Immich-Client für neun Endpunkte, Immich-Typen bleiben hier | `http`; Token in `flutter_secure_storage` |
| `gallery/` | Gerätefotos + Server-Assets, über die Prüfsumme zusammengeführt | `photo_manager` |
| `editor/` | Rezept-Modell, Vorschau per Fragment-Shader | keine |
| `export/` | volle Auflösung rendern, JPEG kodieren, EXIF übernehmen, XMP einfügen | JPEG-Kodierer offen |
| `stapeln/` | lokal entstandene Kopien nach dem Backup dem Original zuordnen | — |

**Die neun Endpunkte** (geprüft gegen `open-api/immich-openapi-specs.json`, Spec 3.2.0):
`POST /auth/login` (alternativ API-Schlüssel), `POST /search/metadata`,
`GET /assets/{id}/thumbnail`, `GET /assets/{id}/original`, `POST /assets` (Pflichtfelder
`assetData`, `fileCreatedAt`, `fileModifiedAt`), `POST /stacks`, `GET /albums?assetId=…`,
`PUT /albums/{id}/assets`, `GET /server/version`. Von Hand statt generiert — neun Endpunkte
sind weniger Code als ein Client für die ganze API. Beim Anmelden die Server-Version prüfen und
bei unbekannter Hauptversion warnen.

**Rezept-Format:** JSON mit Versionsnummer (`v: 1`) im XMP unter eigenem Namensraum, dazu die
Prüfsumme des Originals. Ab dem ersten Release ein Versprechen: spätere Fassungen lesen ältere.

**Getestet wird mit einem eigenen Immich-Benutzer**, damit Versuchskopien und -stapel nicht in
einer echten Bibliothek landen.

### Bauen auf GitHub

- **`ci.yml`** bei jedem Push und Pull Request: `flutter pub get`,
  `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`,
  `flutter build apk --debug`. Flutter-Version im Workflow fest eingetragen.
- **`release.yml`** bei einem Tag `v*`: Signierschlüssel aus Repository-Secrets
  (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
  `ANDROID_KEY_PASSWORD`) zur Laufzeit nach `android/key.properties`,
  `flutter build apk --release --split-per-abi` plus Universal-APK, mit SHA-256-Prüfsummen an
  ein GitHub-Release.

**Der Signierschlüssel ist das Wertvollste im Projekt:** einmal lokal mit `keytool` erzeugt, im
Passwortmanager und in einer Sicherung, auf GitHub nur als Secret. Wer ihn verliert, kann keine
Updates mehr ausliefern, die sich über die installierte App legen.

**Für später schon heute richtig:** keine Google-Play-Dienste, kein Firebase. Das hält F-Droid
offen; Google Play nimmt die App trotzdem (`flutter build appbundle`, Play App Signing). Für iOS
ein dritter Job auf einem macOS-Runner (`flutter build ios --no-codesign`), damit der iOS-Teil
nicht unbemerkt bricht.

### Meilensteine

0. **Werkzeuge, Gerüst, CI.** Leeres Flutter-Projekt, beide Workflows, Signierschlüssel.
   *Abnahme:* ein Tag `v0.0.1` erzeugt auf GitHub eine signierte APK, die sich installieren lässt.
1. **Speicherweg ohne Editor.** Anmelden, ein Server-Foto laden, nur die Helligkeit ändern, als
   Kopie mit Rezept-XMP hochladen, stapeln, Zeit/Ort/Alben übernehmen.
   *Abnahme:* In Immichs App steht die Bearbeitung vorn im Stapel, am selben Platz in Timeline
   und Karte; die über `/original` wieder geladene Kopie ist Byte für Byte die hochgeladene.
2. **Galerie lokal + Server, Mehrfachauswahl, Stufe-1-Regler, Presets.**
   *Abnahme:* 20 Bilder wählen, ein eigenes Preset anwenden, 20 Stapel entstehen — auch für ein
   Foto, das nur auf dem Gerät lag, sobald die Immich-App es gesichert hat.
   → **erstes Release, Repo wird öffentlich.**
3. **Stufe 2 und Zeichnen.**
4. **Lokale Anpassungen** mit Pinsel und Verläufen (`local`).
   *Abnahme:* ein Himmel lässt sich mit einem Verlauf abdunkeln, ohne das Motiv zu berühren.
5. **Freistellen und Radierer auf dem Gerät** (`patch`).
   *Abnahme:* ein angetipptes Objekt verschwindet im Flugmodus.

Meilenstein 1 zuerst, weil er die eine Annahme prüft, an der alles hängt: dass Immich Kopie,
Stapel und XMP so behandelt wie beschrieben.

### Offen

- **JPEG-Kodierer:** Dart-eigene Kodierung ist für 12-Megapixel-Bilder vermutlich zu langsam,
  eine native Bibliothek eine Abhängigkeit mehr — in Meilenstein 1 messen.
- **Zustandsverwaltung:** in Meilenstein 1 ohne Framework; Immichs App nutzt Riverpod.
- **Gain-Map:** spätestens bevor Fotos mit Gain-Map bearbeitet werden.
- **Ken Burns** gehört nicht in den Editor: Eine Bearbeitung gehört zum Foto, ein Zoom oder
  Schwenk zum Slide einer Story. Den Render-Code darf eine Story-App mitnutzen.
