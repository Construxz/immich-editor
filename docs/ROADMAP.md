# Roadmap

**Hier steht nur Offenes**, jeweils mit Abnahme. Erledigtes verlässt die Datei; das Ergebnis
steht in [DECISIONS.md](DECISIONS.md), die Geschichte im `git log`.

⬜ nicht gebaut · 🔶 teilweise gebaut oder nicht belastbar geprüft

## Meilensteine

**M2. Galerie lokal + Server, Mehrfachauswahl, Stufe-1-Regler, Presets.** 🔶
Gebaut und geprüft: nativer Renderer mit HDR-Vorschau, Geometrie samt Gain-Map, zwölf Regler,
Editor nach Google Fotos, Server-Galerie nach Monaten, erneut bearbeiten, Speichern in 4 s
(D-17 bis D-23). Offen, in dieser Reihenfolge:
- ⬜ **Speichern auf dem Pixel nachprüfen:** Der Besitzer bekam mit einem älteren Stand „App
  reagiert nicht" (D-23). Der Emulator zeigt es nicht; auf dem Pixel läuft seit 21.09. abends `4448976`.
- 🔶 **Gerätefotos:** bearbeiten, Kopie in die Gerätegalerie, nach dem Backup stapeln — gebaut
  (D-26). Offen: eine Zeitleiste über Gerät und Server, über die Prüfsumme zusammengeführt
  (`POST /assets/bulk-upload-check`, Prüfsummen zwischengespeichert), mit Kennzeichen „gesichert";
  ein Serverfoto, das auch auf dem Gerät liegt, lokal bearbeiten (D-24); Vorgemerktes, das nie
  auf dem Server ankommt (Foto gelöscht, Backup aus), irgendwann verwerfen oder anzeigen.
- ⬜ **Presets:** Reiter „Presets" im Editor, speichern, auf eine Mehrfachauswahl anwenden.
- ⬜ **Noodle Gallery als Server** prüfen: gleiche API wie Immich 3.2.2, aber Hauptversion 5 —
  die App warnt dann beim Anmelden (`bekannteHauptversionen`). Gegen einen Noodle-Server testen
  und die Prüfung anpassen (D-27). Danach bei Noodle anfragen, ob ihr Editor das Rezept-Format
  übernimmt.
- ⬜ Filter (3D-LUT) mit Reiter „Filter"; Perspektive (Vier-Punkt); HDR-Spielraum sanft hochfahren
  (`setDesiredHdrHeadroom`, ab Android 15); Miniaturen auf der Platte zwischenspeichern; Blättern
  durch eine große Bibliothek messen.

*Abnahme:* 20 Bilder wählen, ein eigenes Preset anwenden, 20 Stapel entstehen — auch für ein
Foto, das nur auf dem Gerät lag, sobald die Immich-App es gesichert hat. Auf dem Pixel zeigt die
Vorschau eines Ultra-HDR-Fotos HDR, auch nach Zuschneiden und Drehen, und die Kopie ist Ultra
HDR mit passender Gain-Map — libvips (`uhdrload`) erkennt sie (D-19); mit „HDR" aus entstehen
SDR-Kopien.
→ erstes Release; Repo wird öffentlich (D-4), vorher Mail an Immich (D-5) und die Doku ins
Englische übersetzt (D-15).

**M3. Stufe 2 und Zeichnen.** ⬜
Pop, Rauschen, bester Bildausschnitt, Hautton; Stift, Textmarker, Text.
*Abnahme:* ein eigener Look mit Pop und Entrauschen lässt sich als Preset auf 20 Bilder anwenden.

**M4. Lokale Anpassungen.** ⬜
Pinsel, linearer und radialer Verlauf (`local`).
*Abnahme:* ein Himmel lässt sich mit einem Verlauf abdunkeln, ohne das Motiv zu berühren.

**M5. Freistellen und Radierer auf dem Gerät.** ⬜
Stufe 3 (`patch`), Modelle nach D-6.
*Abnahme:* ein angetipptes Objekt verschwindet im Flugmodus.

## Offene Entscheidungen

**E4. MediaPipe zulässig?** ⬜ Siehe D-6.
*Abnahme:* entschieden vor M5.
