# Roadmap

**Hier steht nur Offenes**, jeweils mit Abnahme. Erledigtes verlässt die Datei; das Ergebnis
steht in [DECISIONS.md](DECISIONS.md), die Geschichte im `git log`.

⬜ nicht gebaut · 🔶 teilweise gebaut oder nicht belastbar geprüft

## Meilensteine

**M2. Galerie lokal + Server, Mehrfachauswahl, Stufe-1-Regler, Presets.** 🔶
Gebaut und geprüft: nativer Renderer mit HDR-Vorschau, Geometrie samt Gain-Map, zwölf Regler,
Editor nach Google Fotos, Gerätefotos und Online-Fotos, eine Zeitleiste über Gerät und Server,
Bibliothek, Betrachter mit Stapeln, Aussehen der Immich-App, Presets, Code auf Englisch, Deutsch und Englisch in der App, Kopien schneller öffnen, Serverfotos mit lokalem Original lokal, Stapeln im Hintergrund, Betrachter über Monate und mit HDR, Geräteordner, Noodle als Server, Filter, Optimieren, Betrachter wie Google Fotos, Regler und Optimieren nach Google kalibriert, Pop, ohne Server nutzbar (D-17 bis D-79). Offen, in dieser
Reihenfolge:
- ⬜ **Noodle:** bei Noodle anfragen, ob ihr Editor das Rezept-Format übernimmt (D-27, D-56).
- 🔶 **Regler kalibrieren nach Google Fotos:** 8 von 11 Reglern liegen bei ±100 unter 10 % zu
  Google (D-73), „Optimieren" in derselben Größenordnung (D-74). Offen:
  - Kontrast (26 % / 16 %), Sättigung + (13 %) und Blautöne + (32 %) unter 10 % bringen.
  - Leere Bilder des Renderers im Emulator, und Teilbilder in der Vorschau nach schnellem
    Wischen (D-76): Ursache finden und klären, ob Kopien betroffen sein können.
- 🔶 **Werkzeuge wie in Google Fotos** (Wunsch des Besitzers, 25.09.2026; Messungen an der
  Testtafel D-73). Pop ist gebaut (D-75); offen, in dieser Reihenfolge:
  - **Ton** (`~10`/`~11`).
  - **Hautton** (`~26`/`~27`): wirkt nur auf Hauttöne.
  - **Dynamisch** (`~3`): wohl lokale Tonwerte; D-74 zeigt, dass es auch in „Optimieren" steckt.
  - **Scharfzeichnen** (`~32`) und **Scharf stellen** (`~35`): Den Unterschied klärt erst eine
    Messung an einem echten Foto.
  - **Ultra HDR** (`~8`/`~9`): Das SDR-Bild bleibt, dazu kommt eine Gain-Map. Ziel: einem Foto
    ohne HDR nachträglich die Anmutung geben, als hätte die Kamera Ultra HDR aufgenommen.
  - **Porträtlicht „Licht angleichen"** (`~36`/`~37`): braucht Gesichtserkennung auf dem Gerät
    mit offenem Modell (D-6). „Licht hinzufügen" (virtuelle Lichtquelle) kommt danach.
  Nicht vorrangig: Entrauschen. Das von Google wirkt laut Besitzer eher wie ein Weichzeichner;
  der Maßstab sind KI-Entrauscher vom Desktop (Lightroom, Topaz).
- ⬜ **Meine Presets:** bearbeiten und umbenennen, eine Seite „Meine Presets", sichern und laden
  als `.json` je Preset auf dem Telefon (Vorstufe der Idee „Presets teilen").
- ⬜ Perspektive (Vier-Punkt).
- ⬜ Zeitleiste ohne Netz: Immichs Monatsliste merken (D-55 — ohne Netz bleibt sie leer).
- ⬜ HDR im Betrachter auch für reine Server-Fotos (Original laden, nach Einstellung „Mobile Daten").
- ⬜ Blättern durch eine große Bibliothek messen (Bildraten auf dem Pixel, der Besitzer wischt —
  per `adb` scrollt dort nichts, D-50).
- ⬜ **Sicherheit, Rest aus der Durchsicht** (D-78), vor dem ersten Release:
  - `android:allowBackup="false"`: Sonst kommt der Speicher von `flutter_secure_storage` in
    Geräte- und ADB-Backups. *Abnahme:* `adb backup` enthält keine App-Daten.
  - Fehlermeldungen: `Immich._ok` zeigt den ganzen Antworttext. Hinter einem Proxy kann das eine
    HTML-Seite mit internen Details sein. Nur Status und Immichs `message` zeigen, gekürzt
    auf etwa 200 Zeichen. *Abnahme:* Test mit einer HTML-Antwort.
  - CI: Alle `uses:` in `.github/workflows/` auf Commit-SHAs festlegen, den Tag als Kommentar
    dahinter. `release.yml` läuft mit `contents: write` und den Signier-Secrets.
    *Abnahme:* kein `@v…` mehr ohne SHA.
  - Redirects: Folgt `dart:io` einer Umleitung auf einen anderen Host samt
    `Authorization`-Header? *Abnahme:* mit einem Endpunkt gemessen, der per 302 umleitet. Geht
    der Header mit, nur Umleitungen auf denselben Host folgen.
  - Eine fremde Datei mit unserem XMP wählt über `originalSha1` selbst, welches eigene Foto als
    Original gilt, und landet bei einem Preset auf eine Auswahl (`applyPreset`, immer „ersetzen“)
    im Papierkorb. Wiederherstellbar, betrifft nur eigene Assets. Zu klären: ersetzen nur, wenn die
    Kopie schon mit dem Original gestapelt ist. *Abnahme:* Test mit einer untergeschobenen Kopie.

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
