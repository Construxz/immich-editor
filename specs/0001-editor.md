# 0001 — Editor for Immich: Umfang und Aufbau

**Stand 21.09.2026.** Das Konzept der App. Entscheidungen samt Begründung stehen in
[DECISIONS.md](../docs/DECISIONS.md), Meilensteine in [ROADMAP.md](../docs/ROADMAP.md),
Lizenzen in [LICENSES.md](../docs/LICENSES.md).

## Ziele

1. **Umfang und Bedienung wie der Editor in Google Fotos** — einfach, kein Snapseed, kein
   Lightroom.
2. **Dazu, was Google fehlt:** lokale Anpassungen mit Masken (keine Ebenen) und eigene Presets,
   die sich auf viele Bilder zugleich anwenden lassen.
3. **Alles, was geht, auf dem Gerät gerechnet**, ohne Cloud-Dienst (D-6).
4. **Eine eigenständige Flutter-App** für Android und iOS, mit eigener Galerie über lokale Fotos
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

**HDR:** Der Export muss eine vorhandene Gain-Map übertragen (D-8).

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

## Funktionen, nach Aufwand eingeteilt

Vorbild ist der Bearbeiten-Bereich von Google Fotos (Stand 09/2026), ohne dessen Cloud-KI.

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
| `editor/` | Rezept-Modell, Vorschau per Fragment-Shader | keine |
| `export/` | volle Auflösung rendern, JPEG kodieren, EXIF übernehmen, XMP und Gain-Map einfügen | Kodierer offen (E1) |
| `stapeln/` | lokal entstandene Kopien nach dem Backup dem Original zuordnen | — |

**Die neun Endpunkte** (geprüft gegen die OpenAPI-Spezifikation 3.2.0): `POST /auth/login`
(alternativ API-Schlüssel), `POST /search/metadata`, `GET /assets/{id}/thumbnail`,
`GET /assets/{id}/original`, `POST /assets` (Pflichtfelder `assetData`, `fileCreatedAt`,
`fileModifiedAt`), `POST /stacks`, `GET /albums?assetId=…`, `PUT /albums/{id}/assets`,
`GET /server/version`. Von Hand statt generiert — neun Endpunkte sind weniger Code als ein
Client für die ganze API. Beim Anmelden die Server-Version prüfen und bei unbekannter
Hauptversion warnen.

**Rezept-Format:** JSON mit Versionsnummer (`v: 1`) im XMP unter eigenem Namensraum, dazu die
Prüfsumme des Originals. Ab dem ersten Release ein Versprechen: spätere Fassungen lesen ältere.

**Getestet wird mit einem eigenen Immich-Benutzer**, damit Versuchskopien und -stapel nicht in
einer echten Bibliothek landen.

## Nicht in dieser App: Ken Burns

Eine Bearbeitung gehört zum Foto, ein Zoom oder Schwenk zum Slide einer Story — dasselbe Foto
kann in zwei Stories verschieden bewegt werden. Das gehört in eine Story-App; den Render-Code
darf sie mitnutzen.
