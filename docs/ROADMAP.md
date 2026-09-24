# Roadmap

**Hier steht nur Offenes**, jeweils mit Abnahme. Erledigtes verlässt die Datei; das Ergebnis
steht in [DECISIONS.md](DECISIONS.md), die Geschichte im `git log`.

⬜ nicht gebaut · 🔶 teilweise gebaut oder nicht belastbar geprüft

## Meilensteine

**M2. Galerie lokal + Server, Mehrfachauswahl, Stufe-1-Regler, Presets.** 🔶
Gebaut und geprüft: nativer Renderer mit HDR-Vorschau, Geometrie samt Gain-Map, zwölf Regler,
Editor nach Google Fotos, Gerätefotos und Online-Fotos, eine Zeitleiste über Gerät und Server,
Bibliothek, Betrachter mit Stapeln, Aussehen der Immich-App, Presets, Code auf Englisch, Deutsch und Englisch in der App, Kopien schneller öffnen, Serverfotos mit lokalem Original lokal, Stapeln im Hintergrund, Betrachter über Monate und mit HDR, Geräteordner, Noodle als Server, Filter, Optimieren, Betrachter wie Google Fotos (D-17 bis D-70). Offen, in dieser
Reihenfolge:
- ⬜ **Noodle:** bei Noodle anfragen, ob ihr Editor das Rezept-Format übernimmt (D-27, D-56).
- 🔶 **Regler kalibrieren nach Google Fotos** (Befund Besitzer, D-71: bei ±100 viel schwächer,
  etwa „Schatten"; „Optimieren" kaum sichtbar). Testtafel `tool/testchart.py` (132 Felder mit
  bekannten Werten) liegt auf dem Pixel in `Pictures/Testtafel`; der Besitzer speichert in Google
  Fotos je Regler −100 und +100 und „Optimieren" als Kopien, ich lese sie aus und passe die
  Formeln in `Renderer.kt` an. *Abnahme:* je Regler bei ±100 auf der Tafel höchstens 10 % Abstand
  zu Google (Graustufen und Farbfelder), „Optimieren" in derselben Größenordnung.
- ⬜ **„Anpassen" zweistufig wie Google:** Übersicht der runden Knöpfe (mit unseren Punkten für
  Verändertes); ein Tipp öffnet die Reglerzeile: darüber die Kategorien zum Wechseln, links die
  Zahl, Striche bis zum Wert gefüllt (jeder 50er länger, erreicht gelb, sonst grau),
  Zurücksetzen, „Fertig" zurück zur Übersicht.
- ⬜ **Meine Presets:** bearbeiten und umbenennen, eine Seite „Meine Presets", sichern und laden
  als `.json` je Preset auf dem Telefon (Vorstufe der Idee „Presets teilen").
- ⬜ Perspektive (Vier-Punkt).
- ⬜ Zeitleiste ohne Netz: Immichs Monatsliste merken (D-55 — ohne Netz bleibt sie leer).
- ⬜ HDR im Betrachter auch für reine Server-Fotos (Original laden, nach Einstellung „Mobile Daten").
- ⬜ Blättern durch eine große Bibliothek messen (Bildraten auf dem Pixel, der Besitzer wischt —
  per `adb` scrollt dort nichts, D-50).

*Abnahme* — erfüllt bis auf das Urteil des Auges zum HDR (D-40, D-54): 20 Bilder wählen, ein eigenes Preset anwenden, 20 Stapel entstehen — auch für ein
Foto, das nur auf dem Gerät lag, sobald die Immich-App es gesichert hat. Auf dem Pixel zeigt die
Vorschau eines Ultra-HDR-Fotos HDR, auch nach Zuschneiden und Drehen, und die Kopie ist Ultra
HDR mit passender Gain-Map — libvips (`uhdrload`) erkennt sie (D-19); mit „HDR" aus entstehen
SDR-Kopien.
→ erstes Release; Repo wird öffentlich (D-4), vorher Mail an Immich (D-5) und die Doku ins
Englische übersetzt (D-15) — dabei DECISIONS straffen (1175 Zeilen, `doccheck`-Richtwert 600).

**M3. Stufe 2 und Zeichnen.** ⬜
Pop, Rauschen, bester Bildausschnitt, Hautton; Stift, Textmarker, Text.
*Abnahme:* ein eigener Look mit Pop und Entrauschen lässt sich als Preset auf 20 Bilder anwenden.

**M4. Lokale Anpassungen.** ⬜
Pinsel, linearer und radialer Verlauf (`local`).
*Abnahme:* ein Himmel lässt sich mit einem Verlauf abdunkeln, ohne das Motiv zu berühren.

**M5. Freistellen und Radierer auf dem Gerät.** ⬜
Stufe 3 (`patch`), Modelle nach D-6.
*Abnahme:* ein angetipptes Objekt verschwindet im Flugmodus.

## Ideen, nicht geplant

- **Presets und Filter teilen** wie Lightroom Mobile (Besitzer, 24.09.2026): als Datei (`.cube`,
  Rezept-JSON) oder über einen öffentlichen Server, auf dem man Presets benannt hochlädt,
  bewertet und herunterlädt — in der App. Ein eigenes Projekt; ausgeklammert (D-62).

## Offene Entscheidungen

**E4. MediaPipe zulässig?** ⬜ Siehe D-6.
*Abnahme:* entschieden vor M5.
