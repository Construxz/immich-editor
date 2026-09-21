# Roadmap

**Hier steht nur Offenes**, jeweils mit Abnahme. Erledigtes verlässt die Datei; das Ergebnis
steht in [DECISIONS.md](DECISIONS.md), die Geschichte im `git log`.

⬜ nicht gebaut · 🔶 gebaut, nicht belastbar geprüft

## Meilensteine

**M2. Galerie lokal + Server, Mehrfachauswahl, Stufe-1-Regler, Presets.** ⬜
Teile, in dieser Reihenfolge:
- ⬜ Nativer Renderer (AGSL) mit HDR-Vorschau als native Ansicht; Export über denselben Renderer;
  `minSdk 34` (D-17, D-18).
- ⬜ Zuschneiden, Drehen, Spiegeln, Geraderichten — Gain-Map wird mittransformiert.
- ⬜ Stufe-1-Regler (Spec, *Funktionen*).
- ⬜ Editor in der Bedienung der Spec (*Bedienung*, nach Google Fotos); Einstellung „HDR".
- ⬜ Zeitgrenzen und verständliche Fehler bei Netzwerkanfragen.
- ⬜ Galerie: Gerätefotos und Server, über die Prüfsumme zusammengeführt, Stapel nur einmal;
  Blättern durch große Bibliotheken; Mehrfachauswahl.
- ⬜ Presets: speichern, auf viele Bilder anwenden; Gerätefotos später stapeln (Spec, *Speicherweg*).

*Abnahme:* 20 Bilder wählen, ein eigenes Preset anwenden, 20 Stapel entstehen — auch für ein
Foto, das nur auf dem Gerät lag, sobald die Immich-App es gesichert hat. Auf dem Pixel zeigt die
Vorschau eines Ultra-HDR-Fotos HDR, auch nach Zuschneiden und Drehen, und die Kopie ist Ultra
HDR mit passender Gain-Map; mit „HDR" aus entstehen SDR-Kopien.
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
