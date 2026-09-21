# Roadmap

**Hier steht nur Offenes**, jeweils mit Abnahme. Erledigtes verlässt die Datei; das Ergebnis
steht in [DECISIONS.md](DECISIONS.md), die Geschichte im `git log`.

⬜ nicht gebaut · 🔶 gebaut, nicht belastbar geprüft

## Meilensteine

**M1. Speicherweg ohne Editor.** ⬜
Anmelden, ein Server-Foto laden, nur die Helligkeit ändern, als Kopie mit Rezept-XMP hochladen,
stapeln, Aufnahmezeit/Ort/Alben übernehmen. Prüft die eine Annahme, an der alles hängt (D-2).
Mit einem eigenen Immich-Testbenutzer.
*Abnahme:* In Immichs App steht die Bearbeitung vorn im Stapel, am selben Platz in Timeline und
Karte; die über `/original` wieder geladene Kopie ist Byte für Byte die hochgeladene.

**M2. Galerie lokal + Server, Mehrfachauswahl, Stufe-1-Regler, Presets.** ⬜
*Abnahme:* 20 Bilder wählen, ein eigenes Preset anwenden, 20 Stapel entstehen — auch für ein
Foto, das nur auf dem Gerät lag, sobald die Immich-App es gesichert hat.
→ erstes Release; Repo wird öffentlich (D-4), vorher Mail an Immich (D-5).

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

**E1. JPEG-Kodierer.** ⬜ Dart-eigene Kodierung ist für 12-Megapixel-Bilder vermutlich zu
langsam, eine native Bibliothek eine Abhängigkeit mehr.
*Abnahme:* in M1 an einem echten Kamerafoto gemessen, Wahl in DECISIONS.

**E2. HDR-Gain-Map übertragen.** ⬜ Siehe D-8.
*Abnahme:* ein Foto mit Gain-Map ist nach der Bearbeitung weiter HDR — vor M2.

**E3. Sprache der Specs.** ⬜ Deutsch oder Englisch fürs öffentliche Repo.
*Abnahme:* entschieden vor M2.

**E4. MediaPipe zulässig?** ⬜ Siehe D-6.
*Abnahme:* entschieden vor M5.

**E5. iOS-Build in der CI.** ⬜ Ein Job auf einem macOS-Runner
(`flutter build ios --no-codesign`), damit der iOS-Teil nicht unbemerkt bricht.
*Abnahme:* der Job läuft grün, bevor iOS-Nutzer zum Ziel werden.
