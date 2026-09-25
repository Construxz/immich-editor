# 0001 — Editor for Immich: Umfang und Aufbau

**Stand 21.09.2026.** Das Konzept der App. Entscheidungen samt Begründung stehen in
[DECISIONS.md](../docs/DECISIONS.md) ([englisch](../docs/DECISIONS.en.md)), Meilensteine in
[ROADMAP.md](../docs/ROADMAP.md) ([englisch](../docs/ROADMAP.en.md)),
Lizenzen in [LICENSES.md](../docs/LICENSES.md).

## Ziele

1. **Umfang und Bedienung wie der Editor in Google Fotos** — einfach, kein Snapseed, kein
   Lightroom.
2. **Dazu, was Google fehlt:** lokale Anpassungen mit Masken (keine Ebenen) und eigene Presets,
   die sich auf viele Bilder zugleich anwenden lassen.
3. **Alles, was geht, auf dem Gerät gerechnet**, ohne Cloud-Dienst (D-6).
4. **Eine eigenständige Flutter-App** für Android (iOS nicht, D-14), mit eigener Galerie über lokale Fotos
   **und** den Immich-Server; Bearbeiten ohne Umweg über Teilen, Mehrfachauswahl inklusive (D-1).
5. **Immich bleibt unverändert** — kein Server-Fork, keine Schemaänderung, kein Eingriff in
   Backup oder Bildverwaltung.

| | Immich-App | Editor for Immich | Immich-Server |
|---|---|---|---|
| Rolle | Bibliothek und Backup | Auswählen, Bearbeiten, Presets | Speicher und Anzeige |
| sieht | alle Fotos | lokale Fotos und Server-Assets über die API | Original, Kopie, Stapel |
| schreibt | Backups | bearbeitete Kopien und Stapel über die API | — |

## Speicherweg

Warum dieser Weg und nicht Immichs eigenes `asset_edit`: D-2.

1. **Die App rendert das fertige Bild auf dem Gerät** und legt es als **neues Asset** an.
2. **Das Rezept reist im Bild mit** — als XMP in einem eigenen Namensraum, so wie Lightroom
   (`crs:`) und darktable ihre Entwicklungseinstellungen schreiben: alle Einstellungen und die
   Prüfsumme des Originals. Immich verändert hochgeladene Dateien nicht.
3. **Kopie und Original werden gestapelt**, die Kopie vorn (`POST /api/stacks`). Immichs
   Timeline zeigt die Bearbeitung, das Original liegt im Stapel.
4. **Die Kopie erbt Aufnahmezeit, Ort und Alben** des Originals, damit sie in Timeline, Karte und
   Alben an derselben Stelle steht.
5. **Erneut bearbeiten:** Original laden, Rezept aus der Kopie lesen, weiterbearbeiten, neue
   Kopie an den Stapel, alte Kopie in den Papierkorb (dort umkehrbar).

**Fotos, die nur auf dem Gerät liegen:** Die App schreibt die Kopie (mit Rezept-XMP) in die
Gerätegalerie; die Immich-App sichert beide wie jedes andere Foto. Gestapelt wird, sobald beide
auf dem Server sind — die Prüfsumme im XMP ordnet sie zu. Bis dahin stehen beide kurz
nebeneinander.

**HDR:** Die Kopie behält die Gain-Map des Originals (Ultra HDR, D-16); Tonwert-Änderungen wirken
auf SDR- und HDR-Darstellung gleich, Geometrie (Zuschneiden, Drehen, Perspektive) wirkt mit
derselben Rechnung auf Bild und Gain-Map. Die Vorschau zeigt HDR, wie Google Fotos (D-17).
Die Kopie ist **Standard-Ultra-HDR** (`hdrgm`-XMP, ISO 21496-1, MPF), kein eigenes Format —
Immich zeigt sie in HDR, sobald es Ultra HDR darstellt (D-19). **Abschaltbar** in den Einstellungen („HDR"): dann SDR-Vorschau und Kopien ohne Gain-Map.

**Beim Neustapeln** löst Immich den alten Stapel des Originals auf; die bisherige Kopie stünde
dann lose in der Timeline — deshalb geht sie in den Papierkorb (D-23).

**Zu prüfen:** ob Immich Gesichter und Suchtreffer gestapelter, nicht vorne liegender Assets
ausblendet oder doppelt zählt.

## Galerie

Lokal über `photo_manager`, Server über einen schmalen Immich-Client (s. Aufbau).
Zusammengeführt über die Prüfsumme: Ein Gerätefoto, dessen Prüfsumme der Server kennt, ist
gesichert. Das ist der größte Einzelposten — Thumbnails, Blättern durch Zehntausende Bilder,
Zwischenspeicher — und die Voraussetzung dafür, mehrere Bilder zu wählen und allen ein Preset zu
geben.

**Andere Bibliotheken später** (etwa PhotoPrism, das ebenfalls keinen richtigen Editor hat),
langfristig oder durch die Community. Heute keine Abstraktion dafür, aber eine saubere Naht:
alle Server-Aufrufe in `server/`, und **Immich-Typen verlassen dieses Modul nicht**; Galerie und
Editor arbeiten mit einem eigenen `Foto`-Modell. Das XMP-Rezept ist ohnehin backend-neutral.
Offen wäre je Backend nur, wie dort Original und Kopie verknüpft werden.

## Bedienung

Aufbau und Gesten wie der Bearbeiten-Modus von Google Fotos (Android, Stand 09/2026; der
Besitzer hat Bildschirmfotos als Vorlage gezeigt, sie liegen nicht im Repo). Dunkler
Hintergrund, das Bild füllt die Mitte, alle Bedienelemente unten.

- **Galerie, oben rechts:** ⋮-Menü mit Einstellungen (HDR an/aus) und Abmelden.
- **Oben:** Schließen (×), Rückgängig und Wiederholen, rechts die Hauptschaltfläche
  **„Speichern"** — die App speichert immer als Kopie — mit einem ⋮-Menü daneben (etwa
  „Als Preset sichern", „Zurücksetzen").
- **Unten, zuunterst:** die Bereiche als waagerecht scrollende Reiter, der aktive als Pille
  hervorgehoben. Reihenfolge: **Presets** (bei Google „Vorschläge"), **Zuschneiden**,
  **Anpassen**, **Filter**, später **Markieren** (M3) und **Lokal** (M4).
- **Darüber die Werkzeuge des Bereichs**, ebenfalls waagerecht scrollend:
  - *Anpassen:* runde Symbol-Schaltflächen mit Beschriftung — Helligkeit, Kontrast,
    Weißpunkt, Spitzlichter, Schatten, Schwarzpunkt, Sättigung, Wärme, Färbung, Blautöne,
    Vignettierung, Schärfe. Ein veränderter Regler ist am Symbol erkennbar.
  - *Presets* und *Filter:* kleine Vorschaubilder des aktuellen Fotos mit Namen darunter.
- **Ein Regler** ersetzt die Werkzeugzeile, sobald ein Werkzeug gewählt ist: ein
  Skalen-Lineal mit Strichen, Nullpunkt in der Mitte, der Wert darüber; Doppeltippen setzt auf 0
  zurück.
- **Zuschneiden:** das Bild mit Eck-Anfassern; darüber Seitenverhältnis (Menü: Frei,
  Original, Quadrat, 5:4, 4:3, 3:2, 16:9 und die Hochformate), Spiegeln, 90° drehen; darunter
  ein Winkel-Lineal zum Geraderichten (±45°) und „Zurücksetzen".
- **Vergleichen:** Gedrückthalten auf dem Bild zeigt das Original.

## Funktionen, nach Aufwand eingeteilt

Vorbild ist der Bearbeiten-Bereich von Google Fotos (Stand 09/2026), ohne dessen Cloud-KI.

**Stufe 1 — reine Rechnung.** Ein AGSL-Shader, ein Rezept-Eintrag. Der Kern.

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
| Ultra HDR | Gain-Map erhalten und skalieren |

**Stufe 3 — braucht ein Modell.** Fast alles davon ist *eine* Fähigkeit: **Freistellen**.
Modell-Kandidaten und ihre Lizenzen: [LICENSES.md](../docs/LICENSES.md).

| Funktion | braucht |
|---|---|
| Hintergrund weichzeichnen | Personen-/Motivmaske (+ optional Tiefe) |
| Himmel-Effekt | Himmelsmaske + Look |
| Portraitbeleuchtung | Gesicht + Tiefe/Normalen |
| Radierer, Retusche | Maske per Antippen + Inpainting |
| Verschieben | Maske + Inpainting + Einsetzen — nur angenähert; zuletzt |
| Unscharfes scharf stellen | Entschärfungs-Modell, auf dem Handy schwer; zuletzt |

„In anderer App öffnen" liefert eine Datei ohne Rezept und ohne Stapel zurück — weglassen oder
nur als „Kopie exportieren" anbieten.

## Masken statt Ebenen

Nach dem Muster von Lightroom Mobile: **keine Ebenen, sondern lokale Anpassungen** — eine Maske
plus ein eigener Satz derselben Regler. Maskenquellen: Pinsel, linearer und radialer Verlauf,
mit Stufe 3 „Motiv", „Himmel", „Person".

**Retusche hat dieselbe Form:** Maske plus Pixel-Flicken statt Reglerwerten. Zwei Rezept-Arten —
`local` (Maske + Regler) und `patch` (Maske + Flicken) —, und jedes KI-Werkzeug ist nur ein
weiterer Weg, eine Maske zu erzeugen.

**Gespeichert wird das Ergebnis des Modells, nicht sein Aufruf.** Pinsel und Verläufe sind
Vektoren und passen klein ins XMP; KI-Masken und Flicken verkleinert als eingebettetes PNG. Wie
groß ein Rezept mit mehreren Flicken wird, ist am ersten Prototyp zu messen.

## Presets

Ein Preset ist **ein Rezept ohne Geometrie und ohne Masken** — Regler, Kurve, Look. Zuerst in der
App gespeichert; später auf dem Server abgelegt, ohne Schemaänderung (etwa als kleine Datei in
einem eigenen Album). Wichtiger als das Speichern ist das **Anwenden auf viele Bilder auf
einmal** — gehört in den ersten Wurf.

## Aufbau

| Baustein | Inhalt | Abhängigkeit |
|---|---|---|
| `server/` | Immich-Client für neun Endpunkte; Immich-Typen bleiben hier | `http`; Anmeldedaten in `flutter_secure_storage` |
| `gallery/` | Gerätefotos + Server-Assets, über die Prüfsumme zusammengeführt | `photo_manager` |
| `editor/` | Rezept-Modell und Bedienung (Flutter); Renderer für Vorschau und Export nativ in Android — AGSL-Shader, Bildfläche als native Ansicht im HDR-Fenster (D-17) | keine |
| `export/` | volle Auflösung rendern, JPEG kodieren, EXIF übernehmen, XMP und Gain-Map einfügen | Systemkodierer über einen Plattformkanal (D-13) |
| `stacking/` | lokal entstandene Kopien nach dem Backup dem Original zuordnen | — |

**Die Endpunkte** (geprüft gegen die OpenAPI-Spezifikation 3.2.2): `POST /auth/login`,
`GET`, `PUT` und `DELETE /stacks/{id}` (Mitglieder, Hauptfoto, auflösen — im Betrachter), `GET /map/reverse-geocode` (Ort eines
Gerätefotos), `POST /assets/bulk-upload-check` (was vom Gerät schon gesichert ist, D-36), `POST /albums`
(Album „Editor for Immich"), `GET /server/storage` (Speicherplatz ohne Kontingent), `GET /users/me` und `GET /users/{id}/profile-image` (Profilbild wie in der Immich-App),
`GET /server/version`, `GET /timeline/buckets` und `GET /timeline/bucket` (Galerie, mit
`withStacked` — ein Stapel zählt einmal), `GET /assets/{id}` (Details, Prüfsumme, Stapel),
`GET /assets/{id}/thumbnail` (auch `size=preview` als erstes Bild im Editor), `GET /assets/{id}/original` (auch als Teilabruf), `POST /assets`
(Pflichtfelder `assetData`, `fileCreatedAt`, `fileModifiedAt`), `POST /search/metadata` (nur
nach Prüfsumme), `POST /stacks`, `DELETE /assets` (Papierkorb), `GET /albums?assetId=…`,
`PUT /albums/{id}/assets`. Von Hand statt generiert — ein Dutzend Endpunkte sind weniger Code
als ein Client für die ganze API. Beim Anmelden die Server-Version prüfen und bei unbekannter
Hauptversion warnen.

**Rezept-Format:** JSON mit Versionsnummer (`v: 1`) im XMP unter eigenem Namensraum
`https://github.com/Construxz/immich-editor/ns/1.0/` (Präfix `ife`): `ife:recipe` trägt das JSON
(bisher `{"v":1,"brightness":…,"contrast":…,"geometry":{"quarterTurns":0…3,"flip":…,"angle":−45…45,"crop":[x,y,b,h]}}`;
Regler `brightness`, `contrast`, `whitePoint`, `blackPoint`, `highlights`, `shadows`,
`saturation`, `warmth`, `tint`, `blueTones`, `vignette`, `sharpness`, `pop`, je −1 … 1 und nur, wenn
≠ 0 — die Rechnung steht in `Renderer.kt`; `filter` als `{"id":"warm@1","strength":0 … 1}`, nur
wenn Stärke > 0 — die ID nennt einen eingebauten Look samt Version, ein geänderter Look bekommt
eine neue ID (D-62); Geometrie nur, wenn sie etwas ändert — Reihenfolge: Vierteldrehungen im
Uhrzeigersinn, Spiegeln in der gedrehten Ansicht, Geraderichten mit Zoom ohne leere Ecken,
Zuschnitt 0 … 1 im gedrehten Rahmen; alles nach dem Aufrichten gemäß EXIF), `ife:originalSha1` die SHA-1 des Originals in Base64,
wie Immich sie als `checksum` führt. Ab dem ersten Release ein Versprechen: spätere Fassungen lesen ältere.

**Getestet wird mit einem eigenen Immich-Benutzer**, damit Versuchskopien und -stapel nicht in
einer echten Bibliothek landen.

## Nicht in dieser App: Ken Burns

Eine Bearbeitung gehört zum Foto, ein Zoom oder Schwenk zum Slide einer Story — dasselbe Foto
kann in zwei Stories verschieden bewegt werden. Das gehört in eine Story-App; den Render-Code
darf sie mitnutzen.
