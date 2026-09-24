# Roadmap

**Hier steht nur Offenes**, jeweils mit Abnahme. Erledigtes verlässt die Datei; das Ergebnis
steht in [DECISIONS.md](DECISIONS.md), die Geschichte im `git log`.

⬜ nicht gebaut · 🔶 teilweise gebaut oder nicht belastbar geprüft

## Meilensteine

**M2. Galerie lokal + Server, Mehrfachauswahl, Stufe-1-Regler, Presets.** 🔶
Gebaut und geprüft: nativer Renderer mit HDR-Vorschau, Geometrie samt Gain-Map, zwölf Regler,
Editor nach Google Fotos, Gerätefotos und Online-Fotos, eine Zeitleiste über Gerät und Server,
Bibliothek, Betrachter mit Stapeln, Aussehen der Immich-App, Presets, Code auf Englisch, Deutsch und Englisch in der App, Kopien schneller öffnen, Serverfotos mit lokalem Original lokal, Stapeln im Hintergrund, Betrachter über Monate (D-17 bis D-47). Offen, in dieser
Reihenfolge:
- ⬜ **Betrachter, Rest:** HDR im Betrachter; Objektiv bei Gerätefotos (das Framework-`ExifInterface` liefert `LensModel` nicht).
- ⬜ **Noodle:** bei Noodle anfragen, ob ihr Editor das Rezept-Format übernimmt (D-27, D-56).
- ⬜ Filter (3D-LUT) mit Reiter „Filter"; Perspektive (Vier-Punkt); HDR-Spielraum sanft hochfahren
  (`setDesiredHdrHeadroom`, ab Android 15); Miniaturen auf der Platte zwischenspeichern; Blättern
  durch eine große Bibliothek messen.

*Abnahme:* 20 Bilder wählen, ein eigenes Preset anwenden, 20 Stapel entstehen — auch für ein
Foto, das nur auf dem Gerät lag, sobald die Immich-App es gesichert hat. Auf dem Pixel zeigt die
Vorschau eines Ultra-HDR-Fotos HDR, auch nach Zuschneiden und Drehen, und die Kopie ist Ultra
HDR mit passender Gain-Map — libvips (`uhdrload`) erkennt sie (D-19); mit „HDR" aus entstehen
SDR-Kopien.
→ erstes Release; Repo wird öffentlich (D-4), vorher Mail an Immich (D-5) und die Doku ins
Englische übersetzt (D-15) — dabei DECISIONS straffen (743 Zeilen, `doccheck`-Richtwert 600).

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
