# Entscheidungen und Befunde

Eine Entscheidung oder ein Befund je Eintrag, mit Datum, Begründung und — bei Befunden — wie
gemessen wurde. **Neue Einträge oben anfügen.** Was noch zu tun ist, steht in
[ROADMAP.md](ROADMAP.md), was jetzt gilt in [STATUS.md](STATUS.md), das Konzept in
[specs/0001-editor.md](../specs/0001-editor.md).

---

## 2026-09-25 · D-77: Nach einem Netzfehler neue Verbindung; Gerätefotos auch ohne Server

Befund des Besitzers (25.09.2026, Pixel, direkt nach einem Android-Update): Die Galerie blieb
leer, auch das Profilbild, dann kam „Server nicht erreichbar". Erst nach mehrmaligem Schließen und
Öffnen lud sie wieder.

**Aus dem Logcat des Pixels** (per `adb` gelesen, `logcat -b all` seit dem Neustart um 09:50;
kein Absturzbericht in `dumpsys dropbox`):
- Android hat die App um 09:52:48 selbst geöffnet, gleich nach dem Neustart (Prozess 9968). Das
  WLAN war seit 09:52:26 geprüft online, der Mobilfunk meldete sich um 09:52:51 neu.
- „Schließen und Öffnen" brachte bis 10:05 immer **denselben Prozess** zurück (nur
  `wm_on_resume`). Erst das Wegwischen um 10:05:39 beendete ihn, und der neue Prozess erreichte
  den Server.
- Unsere Fehlermeldungen standen nicht im Log, deshalb bleibt die genaue Ursache offen.

**Ursache (Schluss, nicht gemessen):** Der Client hält **eine** Keep-alive-Verbindung für den
ganzen Prozess (D-23). „Nochmal" in der Galerie lud über denselben Client. Eine Verbindung, die
beim Wechsel zwischen den Netzen hängen bleibt, lässt dann jede weitere Anfrage scheitern, bis der
Prozess endet. Das passt zu „erst ein neuer Prozess half".

**Gebaut:**
- `Immich._await`: Nach einem Netzfehler (Zeitüberschreitung, Socket, abgebrochene Verbindung)
  benutzt die nächste Anfrage einen **neuen Client**. Das geschieht höchstens alle 5 s, weil
  parallele Anfragen wie Miniaturen gemeinsam scheitern. Der alte Client schließt sich erst nach
  3 min, wenn seine Anfragen vorbei sind.
- Netzfehler stehen jetzt im Logcat (`flutter`: `Immich: …`), damit ein Bericht sie zeigt.
- Die Galerie lädt von selbst neu, wenn die App nach einem Serverfehler wieder in den
  Vordergrund kommt.
- Ohne Server zeigt die Zeitleiste die Gerätefotos aus dem letzten Abgleich weiter, mit einem
  Hinweis und „Nochmal" darüber, statt einer leeren Fehlerseite.

**Geprüft** 25.09.2026 im Emulator:
- App im Flugmodus gestartet: Hinweis „Server unreachable: Failed host lookup", darunter die
  Gerätefotos. Im Logcat stehen die Ursachen.
- Flugmodus aus, App in den Hintergrund und zurück, **ohne** „Nochmal": Die Zeitleiste lädt mit
  Server.

Den Fall „hängende Verbindung nach einem Update" kann ich nicht nachstellen. Ob er behoben ist,
zeigt erst der nächste Neustart auf dem Pixel, dann mit Log. `flutter analyze` sauber,
`flutter test` grün. App-Version `0.1.0-dev.77`.

---

## 2026-09-25 · D-76: Pop nur 0 … 100, Leiste springt zum Regler, Zoom im Editor

Befunde des Besitzers auf dem Pixel mit `0.1.0-dev.75`:
- **Pop hat bei Google kein Minus** (0 = aus, 100 = voll). Jetzt geht das Lineal für Pop von 0
  bis 100 (`oneSided` in `recipe.dart`). Der Renderer nimmt weiter −1 … 1 an, falls ein Rezept
  das enthält.
- **Die Kategorienleiste sprang nicht zum gewählten Regler**, wenn man von den Knöpfen kam; aus
  der Leiste heraus ging es. Ursache: Die Leiste war eine `ListView`, die nur Sichtbares baut.
  Pop ganz rechts gab es beim Öffnen also noch nicht, und `ensureVisible` fand nichts. Jetzt baut
  sie alle 13 Einträge.
- **Kein Pinch-Zoom im Editor.** Den gab es bisher nicht; die Vorschau ist eine native Ansicht
  ohne Gesten. Jetzt erkennt Flutter die Geste über dem Bild (Pinch und Verschieben 1 … 4×,
  Doppeltippen setzt zurück) und schickt Maßstab und Verschiebung an die native Ansicht
  (`zoom`). Die zeichnet ihr Vorschaubild damit, deshalb ist das Bild bei starkem Zoom nur so
  scharf wie die Vorschau (≤ 2048 px). Beim Zuschneiden ist der Zoom aus, beim Schließen wird er
  zurückgesetzt.

**Geprüft** 25.09.2026 im Emulator: Von den Knöpfen zu Pop steht „Pop" gelb in der Mitte der
Leiste. Das Lineal beginnt bei 0, nach unten gezogen bleibt es bei 0, nach oben geht es bis 100.
Den Pinch-Zoom konnte ich im Emulator **nicht** auslösen: `adb input` kennt nur einen Finger, und
Mehrfinger-Ereignisse per `sendevent` (mit `adb root`) kamen auf keinem der elf virtuellen
Touchscreens an. Die Prüfung macht der Besitzer auf dem Pixel. `flutter analyze` sauber,
`flutter test` grün.

**Befund:** Nach schnellem Wischen am Lineal (drei Züge in drei Sekunden) zeigte die Vorschau im
Emulator in 3 von 12 Fällen nur einen Streifen des Bildes, bei Pop wie bei der Vignette; langsam
verstellt 0 von 12. Das gehört wohl zu den leeren Bildern aus D-73 (ROADMAP). App-Version
`0.1.0-dev.76`.

---

## 2026-09-25 · D-75: Pop — lokaler Kontrast mit Guided Filter, kein Relief

Wunsch des Besitzers: Pop nutzt er oft. Sein Eindruck von Googles Pop 100 auf der Testtafel war
„wie eine Normalmap": Jedes Feld bekomme rechts und unten einen Schlagschatten, das Bild wirke
reliefartig.

**Messweg.** Google-Kopien mit Pop 100 von sechs Kamerafotos des Besitzers (`DCIM/Camera`,
25.09.2026: die fünf aus D-74 und ein weiteres; nur im Arbeitsordner). Dazu eine zweite Tafel
(`python tool/testchart.py pop`: 80 einzelne Quadrate in 30/90/170/230 auf Grau 128, jede Kante in
jeder Richtung gleich oft), in Google mit Pop 100 (`popchart~2`) und laut Besitzer Pop 50
(`popchart~3`). Googles Änderung der Luminanz wurde per Regression zerlegt: in lokalen Kontrast
(Bild minus Weichzeichnung), die Ableitungen nach x und y (das wäre ein Relief) und eine Tonkurve.

**Befunde:**
- **Kein Relief.** Die Ableitungen erklären auf der Tafel und auf allen sechs Fotos höchstens
  0,4 % zusätzlich. Auf der Pop-Tafel werden die Ränder links und rechts gleich behandelt. Oben und
  unten gibt es um etwa 4 Stufen verschiedene Säume, deren Vorzeichen aber mit der Graustufe
  wechselt, also keine Lichtrichtung. Der plastische Eindruck kommt vom lokalen Kontrast: Ein
  Quadrat 90 auf 128 wird zu 54, eines mit 170 zu 213, dazu Säume an den Kanten.
- **Kantenerhaltend.** Mit einem Guided Filter als Basis erklärt das Modell 45–80 % der Änderung,
  mit einem gewöhnlichen Gauß-Weichzeichner weniger. Mit festen Werten für alle Fotos (Radius 2 %
  der langen Kante, eps 0,01, Detail × 2,31) sind es 30–67 %. Mehrere Maßstäbe, das Detail im
  logarithmischen Raum oder eine Verstärkung abhängig von der Helligkeit bringen nur wenige
  Prozentpunkte.
- **Farbe** steigt um 0–14 % (Mittel etwa 8 %). Die Tonkurve ist vernachlässigbar.
- **Pop 50 (`popchart~3`) wirkt stärker als Pop 100:** Das Quadrat 90 wird zu 34 statt zu 54. Die
  Kopien sind entweder vertauscht, oder Pop 50 kam auf die Pop-100-Kopie. Auf der ersten Tafel
  (`~33`/`~34`) war 50 halb so stark wie 100, deshalb gilt Pop hier linear im Wert.

**Gebaut:**
- Neuer Regler `pop` (−1 … 1, Rezept-Format in der Spec) in „Anpassen" vor der Vignette.
- `Pop.kt` rechnet den Guided Filter auf einer Kopie mit höchstens 512 px (laufende Summen, O(n))
  und legt die Koeffizienten a und b als Halbfloat-Bitmap ab (Extended sRGB, damit der Shader sie
  unverändert liest). Der Renderer legt sie mit derselben Geometrie über das Bild („Fast Guided
  Filter"), deshalb stimmen Vorschau und Export überein.
- Im Shader direkt nach dem Schärfen: `L + 1,31 · pop · (L − (a·L + b))` auf alle Kanäle, dazu
  Sättigung + 0,07 · pop.
- Ein negativer Wert nimmt lokalen Kontrast weg. Google hat nur 0 … 100.

**Ergebnis** (GPU im Emulator, 768 px, mittlere Änderung in Stufen):

| Foto | Google | wir | Abstand zu Google |
|---|---|---|---|
| Pilz | 18,9 | 11,7 | 54 % |
| Abendhimmel | 3,4 | 3,2 | 98 % |
| Dunst | 9,2 | 6,4 | 72 % |
| Haus | 10,5 | 11,5 | 87 % |
| Wald | 11,2 | 10,1 | 82 % |
| neues Foto | 10,0 | 9,4 | 89 % |

Die Stärke stimmt, Pixel für Pixel trifft es Google nur mäßig. Das ist bei lokalen Filtern zu
erwarten, weil schon ein etwas anderer Radius die Säume verschiebt. Im Ausschnitt bei doppelter
Größe (Haus, Pilz, Wald) hat unser Pop denselben Charakter: klarere Struktur, keine Säume. Google
ist bei Pilz und Wald kräftiger, mit dunkleren Schatten und satterem Rot.

**Geprüft** 25.09.2026: `PopTest` (JVM, 2: eine glatte Fläche ist ihre eigene Basis, eine
starke Kante bleibt in der Basis, feine Struktur geht ins Detail). `RendererTest`
`popRaisesFineDetailFlatStays` (GPU, 3 von 3). `flutter analyze` sauber, `flutter test` 28 grün.
Nebenbei behoben: `optimizedKeys` kannte die Sättigung aus D-74 nicht, daher blieb sie stehen,
wenn man „Optimieren" ausschaltete. App-Version `0.1.0-dev.75`.

---

## 2026-09-25 · D-74: „Optimieren" nach Google Fotos abgestimmt

Befund D-71: „Optimieren" ist kaum sichtbar. Nach D-73 wirkte es auf dunkle Fotos dagegen viel
zu stark: Es zog den Median auf mindestens 0,35, und die Helligkeit ist jetzt kräftig.

**Messweg.** Der Besitzer hat in Google Fotos von fünf eigenen Kamerafotos „Optimieren" als
Kopie gespeichert (`DCIM/Camera/PXL_…~2.jpg`, 25.09.2026): Pilz im Wald, Abendhimmel, warmer
Dunst, Haus in der Sonne, dunkler Wald im Gegenlicht. Die Fotos liegen nur zum Messen im
Arbeitsordner, nicht im Repo. Unsere Seite: `SOURCE=foto.png bash tool/chartdump.sh … optimize
'{}'`, also unser Optimize und der Renderer im Emulator. Verglichen werden Median, 1. und
99. Perzentil der Helligkeit, R/B und G über fast graue Pixel (lineares Licht, wie Optimize) und
die mittlere Buntheit, dazu die mittlere Änderung in Stufen.

**Was Googles „Optimieren" macht:** Es hebt den Median etwa ein Viertel des Weges (in Blenden)
Richtung 0,6. Das sind 0,26 bis 1,0 Blenden, beim Abendhimmel 0,47, beim gut belichteten Pilz
0,26. Es gibt etwa 10–15 % mehr Buntheit. Starke Farbstiche korrigiert es bis R/B ≈ 1,1 und
G ≈ 1,0–1,04 (Dunst 1,47 → 1,14), blaue Stunde (0,77 → 0,80) und leicht warme Fotos lässt es
stehen. Weiß und Schwarz bewegt es kaum.

**Gebaut** (`Optimize.kt`):
- Helligkeit: Median um ein Viertel des Weges in Blenden Richtung 0,6, statt 70 % des Weges bis
  mindestens 0,35.
- Weißpunkt: ein Viertel des Weges statt der Hälfte.
- Weißabgleich: Bereich R/B 0,8 … 1,1 und G 0,95 … 1,04 statt 1,0 … 1,25 und 0,95 … 1,1.
- Sättigung +0,1, außer bei grauen oder schon kräftigen Fotos (mittlere Buntheit 0,02 … 0,2).

Damit gilt der Satz aus D-70 „ein gut belichtetes, neutrales Foto bekommt nichts" nicht mehr.
Wie bei Google bekommt es eine leichte Anhebung.

| Foto | Änderung Google | unsere vorher / jetzt | Abstand zu Google vorher / jetzt |
|---|---|---|---|
| Pilz | 6,9 | 4,7 / 8,6 | 3,9 / 2,9 |
| Abendhimmel | 8,4 | 32,0 / 20,2 | 23,6 / 12,0 |
| Dunst | 7,3 | 4,5 / 4,6 | 6,5 / 6,1 |
| Haus | 11,0 | 8,4 / 14,0 | 4,4 / 3,7 |
| Wald | 16,7 | 34,1 / 20,4 | 17,3 / 4,7 |

(Mittel über alle Pixel in 8-Bit-Stufen, 512 px.) Die Stärke liegt damit in derselben
Größenordnung wie bei Google. Übrig bleiben drei Unterschiede:
- Den Abendhimmel lässt Google bewusst dunkler als den ähnlich dunklen Wald. Median und
  Perzentile unterscheiden die beiden nicht, und fünf Fotos reichen nicht, um das sicher
  einzustellen.
- Den Dunst korrigieren wir nur auf R/B 1,21, weil die Verschiebung im hellen Himmel schwächer
  wirkt.
- Google gibt dem Wald mehr lokalen Kontrast und hält die Schatten satt. Das kann ein globaler
  Regler nicht, es gehört zu Pop/Dynamisch (ROADMAP).

**Geprüft** 25.09.2026: die Tabelle oben, und im Bildvergleich (Original, Google, wir) liegen alle
fünf sichtbar nah an Google. `OptimizeTest` (6, grün) an die gemessenen Grenzen angepasst: Ein
neutrales Foto bekommt nur Helligkeit ≤ 0,1, ein warmer Abend (R/B 1,2) nur Wärme −0,15 … 0, ein
Blaustich Wärme > 0,2. App-Version `0.1.0-dev.74`.

---

## 2026-09-24 · D-73: Regler nach Google Fotos kalibriert

Befund D-71 (Besitzer): unsere Regler wirken bei ±100 viel schwächer als bei Google Fotos.

**Messweg.** Der Besitzer hat in Google Fotos auf dem Pixel (24.09.2026, 22:59–23:12) vom
unveränderten `Pictures/Testtafel/testchart.png` (`tool/testchart.py`, 132 Felder) je Regler
−100 und +100 als Kopie gespeichert (`testchart~4.jpg` … `~29.jpg`, sRGB, 1200 × 1600, JPEG).
Die Nummern hat er zugeordnet, die Richtung ist an der Wirkung geprüft (jeweils zuerst −100).
Unsere Seite: `tool/chartdump.sh` rendert die Tafel im Emulator durch `Renderer.kt` auf der GPU.
`python tool/readchart.py --distance unsere.png google.jpg` gibt das Mittel von |unser − Google|
über alle Felder und Kanäle aus, **relativ zu Googles eigener Änderung** der Tafel. Das
JPEG-Rauschen liegt bei 0,2 Stufen (Kopien, die das SDR-Bild nicht ändern: Ultra HDR, „Scharf
stellen"). Die Formeln wurden an einem Python-Nachbau des Shaders angepasst (Nelder-Mead, Abstand
zur GPU ≤ 0,6 Stufen), das Ergebnis ist auf der GPU gemessen.

**Was Google rechnet** und was deshalb jetzt in `Renderer.kt` steht:
- **Tonregler** biegen die Luminanz L (Rec. 709 auf den sRGB-Werten) und tragen die Farbe als
  c − L mit, nicht je Kanal (je Kanal lagen Schatten und Spitzlichter bei 45 %, so bei 4 %).
  Schatten +: `L + 2,66 · L · (1 − L)^4,46`, Spitzlichter: `L + 1,64 · L^4,53 · (1 − L)`, beide
  gleich auf alle Kanäle. Schwarzpunkt −: `L + 0,16 · (1 − L)^2,07`, +: `L − 0,50 · (1 − L)^1,63`.
  Weißpunkt +: Verstärkung × 1,33, die abschneidet, −: `L − 0,22 · L^1,98`. Helligkeit:
  Belichtung im linearen Licht, −2,4 / +2,8 Blenden, nach oben mit weicher Schulter. Kontrast:
  Potenzkurven beiderseits von 0,356, Schwarz und Weiß bleiben (bisher wanderte Schwarz bei −100
  auf 77). Die Buntheit skaliert je Regler mit einem eigenen Faktor (0,68 … 1,5).
- **Sättigung −** mischt zum Grau der *linearen* Luminanz (Rot 178 → 82). **+** hebt matte
  Farben stärker als gesättigte: × (1 + 1,27 · (1 − (max − min))).
- **Wärme und Färbung** sind keine Verstärkung im linearen Licht, sondern eine Verschiebung in
  sRGB, am stärksten in den Mitteltönen (`L^1,55 · (1 − L)^1,19`). Schwarz und Weiß bleiben, an
  gesättigten Farben ist sie kaum zu sehen. Grau 133 wird bei Wärme +100 zu 172/127/72.
- **Blautöne** wirken auf Cyan bis Azur (184° ± 58°), nicht auf Reinblau, als Sättigung bei
  gleichem Maximum.
- **Vignette** ist rund in Pixeln, nicht elliptisch wie bei uns bisher. Die Stärke verschiebt vor
  allem, wo sie beginnt (100: ab 0,24 der halben Diagonale, 50: ab 0,31), die Tiefe bleibt
  (0,95 / 0,90).

Gemessen ist nur ±100 (Vignette 100 und 50). Dazwischen gehen Faktoren und Exponenten glatt von
der Mitte zum Rand; die Vignette unter 50 ist geschätzt.

| Regler | vorher −100 / +100 | nachher −100 / +100 |
|---|---|---|
| Helligkeit | 47 % / 36 % | 2 % / 7 % |
| Kontrast | 413 % / 68 % | **26 % / 16 %** (2,1 / 3,0 Stufen) |
| Weißpunkt | 36 % / 40 % | 3 % / 4 % |
| Schwarzpunkt | 39 % / 41 % | 4 % / 7 % |
| Spitzlichter | 96 % / 55 % | 5 % / 8 % |
| Schatten | 65 % / 59 % | 4 % / 5 % |
| Sättigung | 18 % / 45 % | 4 % / **13 %** |
| Wärme | 76 % / 77 % | 6 % / 6 % |
| Färbung | 91 % / 90 % | 5 % / 6 % |
| Blautöne | 126 % / 116 % | 11 % / **32 %** (1,2 Stufen) |
| Vignette 100 / 50 | 35 % / – | 5 % / 7 % |

Die Abnahme (≤ 10 %) ist damit für 8 von 11 Reglern erfüllt. Noch nicht erfüllt:
- **Kontrast:** Auf Grau passt die Kurve, der Rest liegt in gesättigten Farben. Google dunkelt bei
  −100 etwa Rot 255 auf 227 ab. Freie Luminanz-Gewichte, Oklab und Mischformen kamen nicht unter
  26 %.
- **Sättigung +:** Grün wird zu stark.
- **Blautöne +:** Google dunkelt Azur ab und dreht es leicht zu Blau. Auch ein Modell mit Drehung
  und Abdunkeln blieb bei 28 %.

**Nur bei Google**, nicht gebaut (Befund): Ton (`~10`/`~11`), Hautton (`~26`/`~27`, nur
Hauttöne, 2,7 Stufen), Pop (`~33`/`~34`), Dynamisch (`~3`), Ultra HDR (`~8`/`~9`, das SDR-Bild
bleibt, nur eine Gain-Map), Scharfzeichnen (`~32`), Scharf stellen (`~35`), Porträtlicht „Licht
angleichen" (`~36`/`~37`). „Licht hinzufügen" hat der Besitzer weggelassen, weil es Gesichter
erkennt. Einen Schärfe-Regler hat Google nicht, unserer bleibt.

**Optimieren** spiegelt die neuen Formeln: Schwarzpunkt, Weißpunkt und Helligkeit sind direkt
aufgelöst, der Weißabgleich per Bisektion auf dem mittleren grauen Pixel. Es bleibt zielgesteuert,
wirkt auf Fotos also so stark wie vorher, und „kaum sichtbar" (D-71) ist damit **nicht behoben**.
Auf der Tafel setzt es nichts, weil sie voll ausgesteuert und neutral ist. Googles „Optimieren"
ändert sie im Mittel um 4,8 Stufen, „Dynamisch" um 10,4. Vergleichen lässt sich das nur an echten
Fotos.

**Rezept** bleibt `v: 1`: Die Spec verspricht Rückwärts-Kompatibilität erst ab dem ersten
Release. Gespeicherte Testkopien und eigene Presets wirken beim erneuten Öffnen stärker.

**Befund im Emulator:** Der Renderer liefert ab und zu ein leeres, durchsichtiges Bild. Beim
Tafel-Rendern waren es 4 von etwa 30, bei `RendererTest` fallen 1–3 von 13 Tests je Lauf zufällig,
auch mit dem Stand vor dieser Änderung. Einzeln wiederholt ist jeder Test grün. Auf den Fence des
`ImageReader`-Bildes zu warten half nicht. Bei vielen Renderings in einem Lauf stürzte der
Emulator zweimal ab. Auf dem Pixel ist es nicht beobachtet; ob auch eine gespeicherte Kopie leer
werden kann, ist offen.

**Geprüft** 24.09.2026: die Tabelle oben (GPU im Emulator). `RendererTest` hat einen Test mehr,
`matchesGooglePhotosOnGray`: zehn Graupunkte aus den Google-Kopien auf ±5 Stufen. Alle 14 Tests
sind einzeln dreimal grün. `OptimizeTest` ist grün; die Schwelle für die Färbung sank von 0,2 auf
0,1, weil die neue Färbung stärker wirkt. App-Version `0.1.0-dev.73`.

---

## 2026-09-24 · D-72: „Anpassen" zweistufig wie Google Fotos

Wunsch des Besitzers (D-71, mit Bildschirmfotos von Google Fotos): erst die Knöpfe; ein Tipp
öffnet den Regler, darüber die Kategorien zum Wechseln, links die Zahl, Striche bis zum Wert
gefüllt (jeder 50er länger, erreicht gelb, sonst grau), Zurücksetzen, „Fertig" eine Stufe höher —
alles unten, und mit unseren Punkten für Verändertes. Gebaut:
- „Anpassen" zeigt ohne gewählten Regler nur die runden Knöpfe (mit Punkt, wenn verändert).
- Gewählt: Kategorienleiste (die gewählte gelb, in die Mitte gescrollt, Punkt bei veränderten),
  darunter `Ruler` als **Pille** (`pill: true`): Zahl links (gelb, sobald ≠ 0), Striche von 0 bis
  zum Wert gelb, jeder 10. Strich (= 50) lang, rechts Zurücksetzen; darunter „Fertig" (gelb)
  statt der Reiter. Doppeltippen auf das Lineal setzt weiter auf 0.
- Das Winkel-Lineal beim Zuschneiden und die Filterstärke bleiben wie bisher.

**Geprüft** 24.09.2026 im Emulator (Bildschirmfotos): Übersicht mit Knöpfen und Reitern;
„Shadows" → Leiste, Pille, „Done"; gezogen bis 100 — alle Striche bis zum Wert gelb, der 50er
lang, Punkt an „Shadows"; Zurücksetzen → 0, Punkt weg; „Done" → Übersicht mit Reitern.
App-Version `0.1.0-dev.72`.

---

## 2026-09-24 · D-71: „Optimieren" als Schalter und in der Mehrfachauswahl; Presets-Leiste

Befund des Besitzers auf dem Pixel (Vergleich mit Google Fotos, 24.09.2026): „Optimieren" zeigt
nicht, ob es an ist; eigene Presets standen hinter „Sichern" — unlogisch; „Optimieren" fehlt in
der Mehrfachauswahl. Zudem: Regler wirken bei ±100 viel schwächer als bei Google, „Anpassen"
soll zweistufig wie bei Google werden, Presets bearbeiten und sichern (→ ROADMAP).

Gebaut:
- **Schalter:** „Optimieren" rechnet einmal je Foto; gewählt (auch für Bildschirmleser,
  `Semantics.selected` an allen runden Knöpfen), solange die Regler genau seine Werte tragen; ein
  Tipp auf den gewählten setzt diese Regler auf 0.
- **Leiste:** Optimieren, Sichern │ eigene Presets (senkrechter Trenner).
- **Mehrfachauswahl:** im Auswahlblatt oben „Optimieren — für jedes Foto einzeln berechnet",
  darunter die Presets; ohne eigene Presets kein Abbruch mehr. Jedes Foto bekommt „Optimieren"
  aus seinem Original (`optimize` mit Bytes, nativ dieselben Schritte wie die Vorschau des
  Editors: ≤ 2048 px, dann 256 px). `withOptimized` und `optimizedKeys` in `recipe.dart`, von
  Editor und Mehrfachauswahl benutzt (Test).

**Geprüft** 24.09.2026 im Emulator: Schalter an → gewählt, „Speichern" aktiv; aus → nicht
gewählt, nichts zu speichern; wieder an. Mehrfachauswahl `optimize-dunkel.jpg` und
`optimize-blau.jpg` → Rezepte **gleich** denen aus dem Editor (D-70): Weißpunkt 1,0 / Helligkeit
0,39 und Weißpunkt 0,16 / Wärme 0,33 / Färbung 0,07. Befund dabei: Zwei Kopien, die ich per
Mehrfachauswahl „optimierte", wurden als Originale behandelt (`… .edit (1).edit.jpg`) — die
Testfotos tragen kein EXIF-Datum, und das Gerät findet das Original über Prüfsumme **und**
Aufnahmezeit; Kamerafotos haben das Datum. App-Version `0.1.0-dev.71`.

---

## 2026-09-24 · D-70: „Optimieren"

Nach der ROADMAP (Idee des Besitzers, D-62): erster Eintrag unter „Presets", wie „Automatisch"
bei Google Fotos; setzt nur vorhandene Regler, danach unter „Anpassen" veränderbar, Rückgängig
nimmt es zurück. `Optimize.kt` liest die Vorschau des Editors auf 256 px verkleinert, die
Formeln spiegeln `Renderer.kt`:
- **Schwarz-/Weißpunkt:** die dunkelsten und hellsten 0,5 % halb zum Rand — ein flaues, gutes
  Foto bleibt nah, ein dunkles bekommt den vollen Ausschlag.
- **Helligkeit:** nur wenn der Median (nach dem Spreizen) außerhalb 0,35 … 0,6 liegt, zu 70 %.
- **Wärme/Färbung:** über fast graue Pixel (Helligkeit 0,15 … 0,9, Farbabstand < 0,2; mindestens
  5 % des Bildes), im linearen Licht, **nur außerhalb eines natürlichen Bereichs** — R/B 1,0 …
  1,25, G 0,95 … 1,1 des Rot-Blau-Mittels — bis an dessen Rand. Befund beim Abstimmen: reine
  Grauwelt (erster Wurf, gedämpft) hätte das gute, warme Testfoto um Wärme −0,38 gekühlt.

Ein zweiter Tipp rechnet von 0 aus, nicht obendrauf. Setzt es nichts: Hinweis „Das Foto ist
schon ausgewogen".

**Geprüft** 24.09.2026: JVM-Test `OptimizeTest` (6: neutral → nichts, dunkel → heller, Blau-
und Grünstich, warmer Abend bleibt warm, bunte Farben bleiben). Abnahme im Emulator mit dem
Testfoto B (SDR) und zwei daraus gerechneten Fassungen (zwei Blenden dunkler; Blaustich R
× 0,8, B × 1,25 linear), in der App optimiert und gespeichert, Werte aus den Kopien (Median der
Helligkeit, R/B über graue Pixel):

| Testbild | Rezept | Median | R/B |
|---|---|---|---|
| gut | Weißpunkt 0,12 | 0,368 → 0,375 | 1,22 → 1,21 |
| zu dunkel | Weißpunkt 1,0, Helligkeit 0,39 | 0,183 → 0,304 | 1,03 → 1,13 |
| blaustichig | Weißpunkt 0,16, Wärme 0,33, Färbung 0,07 | 0,363 → 0,371 | 0,90 → 0,96 |

Grenzen: Der Weißpunkt-Regler spreizt höchstens 15 % — das dunkle Bild erreicht den Median des
Originals (0,37) nicht ganz; die Wärme holt den Blaustich bis neutral (R/B 1,0 in den grauen
Pixeln), nicht zurück zur ursprünglichen Wärme. Die Filter (D-62) passen dem Besitzer „erstmal
so" (24.09.2026). App-Version `0.1.0-dev.70`.

---

## 2026-09-24 · D-69: Griff am Infobereich des Betrachters

Wunsch des Besitzers: Die Infos schließen wie bei Google Fotos an einem Griff, statt „auf gut
Glück" aufs Bild zu wischen. Gebaut: oben am Infobereich der Griff des Material-3-Blatts
(32 × 4 pt, `onSurfaceVariant` mit 40 %); der Bereich folgt dem Finger nach unten (wird
niedriger, das Foto größer), schließt ab 60 pt oder bei schnellem Zug (> 300 pt/s), sonst springt
er zurück. Für Bildschirmleser ein Knopf „Schließen".

**Geprüft** 24.09.2026 im Emulator: langsam 24 pt gezogen — Infos bleiben; 160 pt — Infos zu.
App-Version `0.1.0-dev.69`.

---

## 2026-09-24 · D-68: Blättern wie Google Fotos — Nachbarn vorgeladen, Platzhalter, Spalt

Befund des Besitzers: Man wischt schneller, als das nächste Foto lädt, und sieht kurz Schwarz;
bei Google Fotos sind vorige und nächste Seite schon geladen, beim Wischen liegt ein schmaler
schwarzer Spalt zwischen den Fotos, erst bei extrem schnellem Wischen kommt ein unscharfes Bild.
Gemessen 24.09.2026 auf dem Pixel (`0.1.0-dev.67`, Aufnahme wie D-67, 35 s, der Besitzer blätterte
etwa 5 Fotos je Sekunde): **71 Einbrüche**; im Einzelbild zeigt die hereinkommende Seite den
Ladekreis — ihr Foto lädt erst, wenn sie ins Bild kommt (`PageView` baut nur sichtbare Seiten).

Gebaut:
- `allowImplicitScrolling`: die Seite davor und danach bleiben gebaut, ihre Fotos laden vorher.
- Unter dem großen Bild ein kleines, das sofort da ist: bei Gerätefotos 160 px
  (`photo_manager`), bei Server-Fotos das Vorschaubild der Galerie (Platte, D-55; dafür
  `serverThumbnail` aus `tiles.dart` öffentlich). Ist man schneller als das große, sieht man das
  Foto unscharf statt Schwarz.
- Spalt 16 pt: jede Seite ist um den Spalt breiter als der Bildschirm (`OverflowBox`), das Foto
  um den halben Spalt eingerückt — in Ruhe füllt es die Breite, beim Wischen liegt Schwarz
  dazwischen.

**Geprüft** 24.09.2026 im Emulator: in Ruhe volle Breite; mitten im Wischen (Bildschirmfoto)
Spalt rechts und das nächste Foto schon geladen. Tests grün (27). Auf dem Pixel das Urteil des
Besitzers: „jetzt ist es top" (24.09.2026); damit gilt auch D-67 als bestätigt. App-Version
`0.1.0-dev.68`.

---

## 2026-09-24 · D-67: Betrachter flackert beim Blättern nicht mehr

Befund des Besitzers nach D-66: Beim schnellen Blättern flackert das Bild — erst Vorschau, kurz
schwarz, dann wieder da. Gemessen 24.09.2026 auf dem Pixel (`0.1.0-dev.66`): Bildschirm per
`adb shell screenrecord` aufgenommen (25 s, 540 × 1170), mit PyAV jedes Einzelbild ausgewertet —
ein Streifen der Bildmitte zu > 85 % schwarz, davor und danach nicht: **17 Einbrüche von 30 bis
120 ms in 9 s Blättern, einer je Wischer**; im Einzelbild ist die hereinkommende Seite schwarz,
die vorige noch zu sehen. Ursache (D-66): Die Markierung der Bildfläche (`GlobalKey`) wanderte
beim Seitenwechsel zur neuen Seite, und nur die aktuelle Seite bekam den Zoom-Rahmen — beides
lässt Flutter den Inhalt der Seite neu aufbauen; das Gerätefoto lädt dann neu
(`FutureBuilder`, `Image.memory`).

Geändert: Jede Seite hat ihre feste Markierung und immer denselben Rahmen (`Zoomed` mit
`ValueListenableBuilder`); die Seiten, die nicht vorn sind, hängen an `noZoom` (immer 1).

**Geprüft:** Widget-Test `zoom_test.dart` zählt, wie oft der Inhalt einer Seite entsteht — vorher
3 bei zwei Seiten und einem Wechsel, jetzt 2. Auf dem Pixel bestätigt mit D-68. App-Version
`0.1.0-dev.67`.

---

## 2026-09-24 · D-66: Eigener Zoom im Betrachter statt `InteractiveViewer`

Befund des Besitzers nach D-65: Wischen tadellos, aber Zwei-Finger-Zoom geht nicht mehr. Ursache
(im Widget-Test nachgestellt): Der erste Finger driftet, bevor der zweite landet; ab 18 px nimmt
ihn das Blättern, dem Zoom fehlt ein Finger. Und der zweite Finger erreicht die Seite gar nicht —
während eine Liste scrollt, schaltet Flutter die Berührungen ihrer Kinder ab (`Scrollable`,
`IgnorePointer`). Mit Schwellen ist der Wettlauf nicht zu lösen; vor D-65 gewann der Zoom den
ersten Finger meist, dafür stahl er die Wischer.

Gebaut: `PinchZoom` (`lib/gallery/zoom.dart`) umschließt die Seiten und arbeitet auf rohen
Berührungen (`Listener`), außerhalb des Gestenwettstreits: Die Seiten behalten jeden Wischer;
landet ein zweiter Finger, halten die Seiten an (eine begonnene Bewegung federt zurück) und der
Pinch zoomt, auch mit einem Finger, den das Blättern schon hatte. Gezoomt verschiebt ein Finger
(das Bild deckt die Fläche, kein schwarzer Rand), ungezoomt öffnet/schließt senkrechtes Wischen
auf dem Bild die Infos. Die Seite zeigt die Vergrößerung über `Zoomed`; nur die aktuelle Seite
zoomt, beim Blättern zurück auf 1. `InteractiveViewer` und die Schwelle aus D-65 sind raus.

**Geprüft** 24.09.2026: Widget-Test `zoom_test.dart` — ein Finger blättert, ein Pinch zoomt
(> 1,5×) auch nachdem der erste Finger 40 px in eine Seitenbewegung driftete, die Seite federt
zurück; hoch-/runterwischen meldet die Richtung. Emulator: Hochwischen öffnet die Infos, 3 von 3
schnellen Wischern über dem Bild blättern. Pinch auf dem Pixel: prüft der Besitzer. App-Version
`0.1.0-dev.66`.

---

## 2026-09-24 · D-65: Blättern im Betrachter — der Zoom nimmt keine Wischer mehr

Befund des Besitzers auf dem Pixel: Ohne Infos sträubt sich das Blättern, ein Wischer reicht
nicht, erst „halten und wischen"; läuft es einmal, geht es; mit offenen Infos flüssig.

Gemessen 24.09.2026 auf dem Pixel (`0.1.0-dev.65` mit vorübergehenden Logzeilen, `adb logcat`
nur gelesen, der Besitzer blätterte 90 s): **35 von 88 Wischern** nahm der `InteractiveViewer`
(Zoom) als Ein-Finger-Geste (`onInteractionStart`, etwa 0,1 s, keine Seite), 53 blätterten. Mit
aufliegender HDR-Ansicht (D-54) 20 geschluckt gegen 6 geblättert, ohne 15 gegen 47. Ursache:
Der Zoom nimmt einen Finger ab 36 px Bewegung (`kPanSlop`), das Blättern ab 18 px; kommen die
Bewegungen in groben Schritten an (bei nativer Ansicht offenbar öfter), überschreiten beide im
selben Ereignis, und der tiefer liegende Zoom gewinnt. Läuft die Seitenanimation, fängt das
Blättern den nächsten Wischer — daher „läuft es einmal, geht es". Mit offenen Infos wischt man
auf den Infos, außerhalb des Zooms. Im Emulator nachgestellt mit `adb`-Wischern von 120 ms:
über dem Bild blätterte keiner, über der Kopfzeile jeder.

Geändert: Solange nicht gezoomt ist, bekommt der Zoom `touchSlop` 60 (Ein-Finger-Schwelle
120 px statt 36); Zwei-Finger-Zoom (eigene Schwelle) und Hochwischen für die Infos bleiben.
Gezoomt gelten die normalen Schwellen zum Verschieben.

**Geprüft** 24.09.2026: Emulator — 4 von 4 schnellen Wischern über dem Bild blättern, kein
Zoom; hoch-/runterwischen öffnet und schließt die Infos. Pixel, der Besitzer blätterte 75 s:
**73 Seitenwechsel, 0 vom Zoom genommen** (3 davon bei aufliegender HDR-Ansicht). Die Logzeilen
sind wieder entfernt.

---

## 2026-09-24 · D-64: Betrachter zeigt Ultra HDR an; HDR-Knopf nur, wo es HDR gibt

Befund des Besitzers: In der Pixel-Kamera war „Ultra HDR" aus; mit einem Ultra-HDR-Foto wirkt der
Knopf (D-63). Wunsch: In den Infos sehen, ob ein Foto Ultra HDR ist, und bei anderen Fotos keinen
HDR-Knopf. Gebaut mit derselben Prüfung wie D-63 (Gain-Map des Originals auf dem Gerät, sobald
die Seite ruht): Die Infos hängen „Ultra HDR" an Auflösung und Größe, der Knopf im Betrachter
erscheint nur dann — auch wenn HDR aus ist, damit man es wieder einschalten kann. Reine
Server-Fotos gelten als unbekannt (kein Hinweis, kein Knopf), bis der Betrachter ihre Originale
lädt (ROADMAP). Galerie und Editor behalten ihren Knopf.

**Geprüft** 24.09.2026 im Emulator: `preset-10.edit.jpg` (Kopie mit Gain-Map, auf dem Gerät) —
„12.5 MP · 3072 × 4080 · 2.9 MB · Ultra HDR" und Knopf „HDR on"; das Original `preset-10.jpg`
(nur auf dem Server) — ohne Hinweis und ohne Knopf. App-Version `0.1.0-dev.64`.

---

## 2026-09-24 · D-63: Betrachter — HDR nur bei Gain-Map, Infos beim Blättern offen

Befund des Besitzers auf dem Pixel (`0.1.0-dev.62`): Der HDR-Knopf im Betrachter ändert nichts
Sichtbares, nur „wie Schärfen"; gezoomt gar nichts. Blättern geht nur Bild für Bild mit Pause.
Mit offenen Infos lässt sich nicht blättern.

Gemessen (per `adb` nur gelesen): Das Fenster unserer App stand im Betrachter auf Standard, nicht
HDR, Display `hdrSdrRatio 1.0`. Das gezeigte Foto und **alle 61 neuesten JPEGs** im Kameraordner
tragen keine Gain-Map (`grep -c hdrgm` auf dem Telefon, das Werkzeug gegengeprüft an einer
Ultra-HDR-Kopie: 12 Treffer) — die Kamera speichert zurzeit kein Ultra HDR, vermutlich ist dort
„Ultra HDR" aus. Der „Schärfe"-Unterschied war die native Ansicht (D-54), die auch SDR-Fotos in
voller Auflösung über Flutters 1440er-Vorschau legte; gezoomt verschwindet sie absichtlich. Sie
entstand über **jedem** ruhenden Foto und dekodierte es ganz — naheliegende Ursache der Pause
beim Blättern.

Geändert:
- Die native Ansicht nur noch bei Fotos **mit Gain-Map**. Geprüft nativ (`hasGainmap`):
  `ImageDecoder` auf 1/16 verkleinert — Android meldet die Gain-Map dabei wie in voller Größe.
  Ein Blick in den Dateikopf nach `hdrgm` reicht nicht: Dateien nach ISO 21496-1 tragen es erst
  im zweiten Bild (Testfoto `geraet-preset.jpg`: MPF bei Byte 638, `hdrgm` erst bei 2,4 MB; libvips
  liest es als Ultra HDR, Android erkennt dort keine Gain-Map — auch voll dekodiert nicht).
- Die native Ansicht erst, wenn die Seite **300 ms ruht** — schnelles Blättern erzeugt keine.
- **Infos in der Seite** statt als modales Blatt: hochwischen oder ⓘ öffnet sie unter dem Foto
  (höchstens 40 % der Höhe, scrollbar), runterwischen oder ⓘ schließt; sie bleiben beim
  Blättern offen und zeigen das jeweilige Foto — zum Vergleichen.
- Log `immich_editor: hdr window on/off`, um HDR auf dem Pixel mitzulesen.

**Geprüft** 24.09.2026 im Emulator: Gerätefotos mit Gain-Map melden `true`, Kopien ohne `false`;
nur bei ersteren „hdr window on", Knopf „aus" → „off", „an" → „on". Mit offenen Infos geblättert:
`preset-10` → `-09` → `-08` → `-07`, Infos wechseln mit. Befund dabei: Sehr schnelle
`adb`-Wischer (120 ms) über dem Bild blättern nicht, über der Kopfzeile schon — der
`InteractiveViewer` (Zoom) gewinnt den Gestenwettstreit, wenn die Bewegung in wenigen großen
Schritten ankommt; mit 400 ms blättert es. Ob das auf dem Pixel mit dem Finger stört, sagt der
Besitzer. Die Gain-Map-Prüfung dauert im Emulator 1,8 s je Foto (im Hintergrund, erst nach der
Ruhe). App-Version `0.1.0-dev.63`.

---

## 2026-09-24 · D-62: Filter (3D-LUT), eigene Looks

Abgestimmt mit dem Besitzer (24.09.2026): **eigene Looks** statt fremder LUTs; im Rezept nur
**ID und Stärke**; „Optimieren" wird der erste Eintrag unter „Presets" (wie „Automatisch" in
Google Fotos, dort vor „Zuschneiden"; nur „Optimieren", „Dynamisch" ist ihm zu stark) — ein
eigener Schritt. **Teilen** (Presets/LUTs als Datei, öffentlicher Server mit Bewerten) bleibt
eine Idee, nicht M2.

Befund Image Toolbox (Apache-2.0, 24.09.2026 im Quelltext): Die fest eingebauten 512×512-LUTs
heißen wie Photoshops „Color Lookup"-Vorgaben (Bleach Bypass, Candlelight, Drop Blues, Edgy
Amber, Fall Colors, Filmstock 50, Foggy Night, Kodak 5218) — vermutlich Adobes, nicht frei; das
nachgeladene Paket `ImageToolboxRemoteResources` hat keine Lizenz. Nur Amatorka stammt aus
GPUImage (BSD). Übernommen wird nichts.

Gebaut:
- **Acht Looks** — Lebendig, Warm, Kühl, Film, Verblasst, Schwarzweiß, Noir, Sepia — rechnet
  `tool/make_luts.py` als `.cube` (17³, je 100 KB) nach `android/app/src/main/assets/luts/`.
  Die ID trägt eine Version (`warm@1`); ein geänderter Look bekommt eine neue ID, alte Rezepte
  bleiben gleich.
- **Renderer:** `Lut.kt` liest `.cube` und legt die Tabelle als Streifen (17 Scheiben
  nebeneinander) an; der AGSL-Shader rechnet trilinear — Rot und Grün filtert die GPU, Blau
  mischt er zwischen zwei Scheiben. Der Filter liegt **nach den Reglern, vor der Vignette**, mit
  `mix` nach der Stärke. Unbekannte ID (Rezept einer neueren App): ohne Filter statt Fehler.
- **HDR:** Der Filter wirkt wie die Regler auf das SDR-Bild, die Gain-Map bleibt. Bei
  einkanaliger Gain-Map (Pixel) bleibt Schwarzweiß auch in HDR grau; eine dreikanalige könnte
  Farbe zurückbringen — nicht geprüft, kein Testbild.
- **Rezept:** `"filter":{"id":"bw@1","strength":0.8}`, nur wenn Stärke > 0. **Presets** nehmen
  den Filter mit; ein Preset ohne Filter entfernt ihn.
- **Editor:** Reiter „Filter" nach „Anpassen" (Spec, *Bedienung*): „Kein Filter", dann die Looks
  als runde Vorschaubilder des Fotos (192 px, ein Ring markiert die Wahl); gewählt erscheint das
  Lineal für die Stärke 0 … 100.
- Vorschaubilder in **einem** GPU-Durchgang, alle Looks als Kacheln nebeneinander: einzeln
  gerechnet dauerten sie im Emulator 9,5 s (je Look etwa 1 s, fast alles für den Aufbau von
  `HardwareRenderer` und `ImageReader`; Einlesen einer LUT 50–150 ms), gemeinsam **2,7 s** ab dem
  Wechsel auf den Reiter (Log `editor: filters after`), einmal je Editor-Sitzung.

**Geprüft** 24.09.2026 im Emulator, Testbenutzer: `preset-11` (Ultra HDR, nur auf dem Server)
mit „Warm" — Mittelwert des Bildes R/G/B 99/91/91 → 100/88/83; mit „Schwarzweiß" gespeichert:
`preset-11.edit.jpg` im Kameraordner, Rezept `{"v":1,"filter":{"id":"bw@1","strength":1.0}}`,
libvips (`uhdrload`) erkennt Ultra HDR, Gain-Map einkanalig (697×926), SDR-Bild ohne Farbe
(größter Kanalabstand 0). Tests: 24 Flutter (neu Filter im Rezept und im Preset), 12 JVM (neu
`.cube` lesen, die acht Looks vollständig, Schwarzweiß grau), 13 auf der GPU (neu Schwarzweiß
und halbe Stärke, Warm, unbekannte ID). App-Version `0.1.0-dev.62`.

---

## 2026-09-24 · D-61: Geräteordner nach App

Wunsch des Besitzers: Obsidian legt Bilder in vielen Anhang-Ordnern ab, jeder erscheint einzeln;
besser für eine ganze App sagen „nicht zeigen" oder nur bestimmte Unterordner, mit Icon und Namen
der App. Befund auf dem Pixel (`content query`, `owner_package_name`): Android merkt sich je Bild
die App, die es anlegte — Google Kamera 9.347, eine Kamera-Begleit-App 3.148, Google Fotos 2.235,
System (Screenshots) 964, WhatsApp 902, Obsidian (`md.obsidian`) 70, 467 ohne (per Kabel oder
Sync kopiert).

Gebaut: nativ `folderOwners` (je Ordner die App, die mindestens 60 % seiner Bilder anlegte, sonst
keine) und `appInfo` (Name, Icon als PNG). Damit Android fremde Apps zeigt, im Manifest
`<queries>` für Apps mit Startsymbol — nicht die breite Berechtigung „alle Apps abfragen".
Einstellungen → Geräteordner → Bibliothek hat oben „Ordner | Apps": „Apps" zeigt jede App mit
Icon, Namen und „3 Ordner · 1 ausgeblendet", ein Auge für alle ihre Ordner, aufgeklappt jeden
Ordner mit eigenem Auge; Ordner ohne klare App unter „Andere und unbekannte". Es schreibt in
dieselbe Ausblendliste wie das Auge der Ordneransicht (D-59). Die Bibliothek selbst gruppiert
nicht — ausgeblendete Ordner fehlen dort schon. App-Version `0.1.0-dev.61`.

**Geprüft** 24.09.2026 auf dem Pixel: Die App liest die Herkunft und bekommt Namen und Icons —
Bimostitch Pro, Camera Connect, ChatGPT, Day One, eBay, Fotos (4 Ordner), Fotoscanner,
Instagram, Kamera (2 Ordner) … alphabetisch. Obsidian liegt weiter unten; per `adb` scrollt dort
nichts (D-50) — den Obsidian-Fall prüft der Besitzer.

---

## 2026-09-24 · D-60: Geräteordner auf zwei Seiten

Wunsch des Besitzers: „Unter ‚Fotos' zeigen" und „Bibliothek" nicht auf einer langen Seite
(auf dem Pixel 62 Ordner je Liste), sondern eine Ebene tiefer getrennt. Einstellungen →
Geräteordner zeigt zwei Einträge, jeder öffnet seine Liste; der Hinweistext steht oben, der Titel
in der Leiste. App-Version `0.1.0-dev.60`.

**Geprüft** 24.09.2026 im Emulator: Übersicht mit beiden Einträgen; „Bibliothek" öffnet Sortierung
und Liste mit Auge, Stecknadel, Griff (Test15 angepinnt oben).

---

## 2026-09-24 · D-59: Geräteordner anpinnen, anordnen, ausblenden

Wunsch des Besitzers: Lieblingsordner oben anpinnen, die übrigen selbst anordnen, was nicht
angepinnt oder angeordnet ist, darunter alphabetisch oder nach Aktualität; Ausblenden im selben
Menü. Einstellungen → Geräteordner → **Bibliothek**: je Zeile vorn ein Auge (zu: Zeile
ausgegraut, Ordner nicht in der Bibliothek), hinten eine Stecknadel und ein Griff zum Verschieben;
darüber die Wahl „Rest: neueste zuerst / A–Z". Die Reihenfolge rechnet `arrangeFolders`
(getestet): angepinnt, dann angeordnet, dann der Rest. Wer einen Ordner zieht, ordnet alles
darüber mit an; bisher Angeordnetes und Angepinntes behält seinen Platz (`orderAfterMove`,
getestet). Gespeichert unter `pinnedFolders`, `folderOrder`, `folderSort`, `hiddenFolders`.

Abweichung vom Wunsch: Die Zielstelle zeigt Flutters `SliverReorderableList` als Lücke, das
gezogene Element trägt einen Rahmen in der Akzentfarbe — keine farbige Linie. Dafür scrollt die
Liste beim Ziehen mit (62 Ordner auf dem Pixel); eine Linie hieße, das Ziehen samt Mitscrollen
selbst zu bauen.

**Geprüft** 24.09.2026 im Emulator (20 Ordner): Test15 angepinnt → steht oben; Test13 per Auge
ausgeblendet → ausgegraut, fehlt in der Bibliothek; Test12 am Griff hinter Test5 gezogen →
Bibliothek „Test15, Camera, Privat, Screenshots, Test1 … Test5, Test12, Test6 …".

---

## 2026-09-24 · D-58: HDR-Knopf überall, abschaltbar

Wunsch des Besitzers: den HDR-Umschalter in Galerie, Betrachter und Editor; nur wenn er in den
Einstellungen abgeschaltet ist, nirgends — ein erster Schritt zu anpassbaren Knöpfen. Ein
gemeinsamer Zustand (`lib/hdr.dart`: `hdrOn`, `hdrButton`, beim Start gelesen wie die Sprache),
ein `HdrButton` für alle drei; der Editor hört auf den Zustand und schaltet den Renderer um.
Einstellungen → Bearbeiten: „HDR" und neu „HDR-Knopf anzeigen" (`hdrButton`).

**Geprüft** 24.09.2026 im Emulator: Galerie „HDR an" → Tipp → „HDR aus", der Betrachter zeigt
„aus", sein Tipp schaltet zurück, die Galerie zeigt wieder „an"; „HDR-Knopf anzeigen" aus → kein
Knopf in Galerie und Betrachter, wieder an → da.

---

## 2026-09-24 · D-57: Bibliothek springt beim Hochscrollen nicht mehr

Befund des Besitzers am Pixel: nach unten flüssig, nach oben springt die Liste — das angeschnittene
Vorschaubild hüpft ganz ins Bild. Ursache: Eine Ordnerzeile war beim Laden einzeilig und wurde
mit „30 Fotos · …" zweizeilig; beim Hochscrollen luden die Zeilen oberhalb neu, wuchsen und
schoben die Liste. Jetzt ist die Zeile von Anfang an zweizeilig (leere zweite Zeile) und bleibt
geladen, wenn sie aus dem Bild scrollt (`AutomaticKeepAliveClientMixin`) — auch das Zählen über
alle Fotos eines Ordners (Camera: 7.519) geschieht nur einmal. Auf dem Pixel installiert
(`0e967f9`); ob es flüssig ist, sagt der Besitzer.

---

## 2026-09-24 · D-54: HDR im Betrachter; Objektiv; M2-Abnahme HDR auf dem Pixel

Gebaut:
- **Betrachter:** Solange eine Seite ruht und nicht gezoomt ist, liegt über Flutters Bild eine
  native Ansicht (`HdrImageView`, `immich_editor/hdr`), die das lokale Original per
  `ImageDecoder` samt Gain-Map und EXIF-Drehung zeichnet; trägt es eine Gain-Map und ist „HDR"
  an, geht das Fenster auf HDR, beim Verlassen zurück (Zähler über alle solchen Ansichten, damit
  Editor und Betrachter sich nicht gegenseitig abschalten). Quelle: Gerätefotos, und Server-Fotos,
  deren Original auch auf dem Gerät liegt (Prüfsumme). Reine Server-Fotos bleiben SDR — der
  Betrachter lädt keine Originale.
- Befund beim Bauen: Entsteht die native Ansicht mitten im Wischen (`onPageChanged` feuert auf
  halbem Weg), bleibt die Seite zwischen zwei Fotos hängen (Hybrid Composition). Jetzt verschwindet
  sie mit dem Beginn des Wischens und kommt erst, wenn die Seite ruht (`ScrollEndNotification`).
- **HDR sanft hochfahren** (ab Android 15): `desiredHdrHeadroom` steigt in 0,5 s von 1 auf das
  Maximum des Displays, danach ohne Grenze — für Editor und Betrachter.
- **Objektiv** bei Gerätefotos: AndroidX `ExifInterface` statt der des Frameworks (liefert
  `LensModel`); schon über `photo_manager` in der App (LICENSES.md).

**Geprüft** 24.09.2026 auf dem Pixel (Release `0e967f9`), Testfoto A (Ultra HDR) in einem
Ordner, den die Immich-App nicht sichert, danach gelöscht:
- Betrachter: Fenster `COLOR_MODE_HDR`, `currentHdrSdrRatio=4.99999` (desired 5).
- Editor: nach Drehen und Zuschnitt Quadrat weiter `COLOR_MODE_HDR`, Faktor 5. Gespeichert („Nur
  auf dem Gerät"): libvips 8.18.6 lädt die Kopie mit **`uhdrload`**, 3072 × 3072, Content-Boost
  4,6525 wie das Original (4,6525) — **Ultra HDR mit passender Gain-Map**. Mit „HDR aus" eine
  weitere Kopie: `jpegload`, kein `hdrgm` — **SDR**. Damit ist der HDR-Teil der M2-Abnahme bis auf
  das Urteil des Auges erfüllt.
- Infos (Emulator, dieselbe Datei): „Google Pixel 7 Pro / Pixel 7 Pro back camera 6.81mm f/1.85 /
  f/1,9 · 1/231 s · ISO 47 · 6,8 mm".
- Im Emulator: Wischen vor und zurück über mehrere Seiten ohne Hängen.

Stolperstein: Nach einem Neustart des `system_server` im Emulator (Grafik-Compositor meldete
„Binder buffer full") hing der Launcher; neu starten half. Der Emulator hat kein HDR — dort zeigt
`dumpsys` den Farbmodus nicht.

---

## 2026-09-24 · D-56: Noodle Gallery als Server — geprüft

Ein Noodle-Server lokal in Docker, ohne die Bibliothek des Besitzers zu berühren: Compose aus
Noodles Release `v5.7.0`, eigener Projekt- und Containername, ohne Machine-Learning-Dienst,
eigenes Datenbank-Passwort, Daten in `%USERPROFILE%\noodle-test` (STATUS). Admin und
Testbenutzer per API angelegt, ein Testfoto (Testfoto A, Ultra HDR) hochgeladen.

Befunde und Änderungen:
- Noodle meldet `/server/version` **5.7.0**; `/server/about` nennt `repository:
  open-noodle/gallery`. Die App warnte bisher bei jeder Hauptversion außer 3; jetzt gilt als
  bekannt: Immich 3 oder Noodle 5 (`isKnownServer`) — ein künftiges Immich 5 warnt weiter.
- Die App erlaubte kein unverschlüsseltes HTTP (Androids Vorgabe) — Server im Heimnetz ohne HTTPS
  gingen gar nicht. Wie die Immich-App (`usesCleartextTraffic="true"`, v3.2.2) jetzt erlaubt.

**Geprüft** 24.09.2026 im Emulator gegen Noodle (`http://10.0.2.2:2283`): Anmeldung ohne Warnung;
Zeitleiste mit dem Server-Foto und den Gerätefotos; Konto-Fenster mit Speicherplatz, „5.7.0" und
Adresse; Editor mit dem Original samt Gain-Map (HDR-Knopf); gedreht und direkt auf den Server
gespeichert → Betrachter mit Stapel Original + V1. Per API: Kopie vorn im Stapel, Rezept im XMP,
`hdrgm`, SHA-1 gleich. Danach wieder beim Immich-Testbenutzer angemeldet, Container angehalten.

---

## 2026-09-24 · D-55: Server-Miniaturen auf der Platte

Server-Miniaturen lädt die Galerie über den Keep-Alive-Client (`Immich.thumbnail`) und legt sie
in Androids Cache-Ordner (`cache/thumbnails`); die neuesten tausend bleiben im Speicher, damit
Flutters Bild-Cache sie wiedererkennt. Scrollt man zurück oder öffnet die App neu, kommen sie von
der Platte. Fehlgeschlagene Abrufe werden nicht gemerkt (neue Kopien bekommen ihre Miniatur erst
Sekunden nach dem Hochladen, D-31).

**Geprüft** 24.09.2026 im Emulator: nach dem Start 20 Dateien im Cache, die Galerie zeigt alle
Miniaturen. Grenze: Ohne Netz bleibt die Zeitleiste leer — sie braucht Immichs Monatsliste; das
merkt sich die App noch nicht.

---

## 2026-09-24 · D-53: Wartende Bearbeitungen einzeln zeigen

ROADMAP: Vorgemerktes, dessen Backup ausbleibt, obwohl die Datei da ist (Backup aus, Ordner nicht
gesichert), in den Einstellungen zeigen. Einstellungen → Stapeln listet jetzt jede wartende
Kopie mit Miniatur, Dateiname und Ordner („Kopie in Pictures/Privat/ — noch nicht in Immich");
× nimmt sie aus der Warteschlange, die Datei bleibt. Die Kopie findet die App über ihre Prüfsumme
in den gespeicherten Geräte-Prüfsummen.

**Geprüft** 24.09.2026 im Emulator: 7 wartende Kopien mit Ordnern, darunter `privat-test` aus dem
ungesicherten `Pictures/Privat`; × → „6 Bearbeitungen warten", die Datei liegt weiter im Ordner.

---

## 2026-09-24 · D-52: „Öffnen mit" wählbar; Geräteordner nach dem neuesten Foto

Entscheidungen des Besitzers:

1. **„In Immich öffnen"** lässt weiter Android wählen, mit „Nur diesmal" / „Immer" (auf dem Pixel
   verstehen Immich und Noodle Gallery `immich://`, D-50). Neu: Einstellungen → Speichern →
   „Bearbeitungen öffnen mit": „Android fragen" (Vorgabe) oder eine der Apps, die Android für
   `immich://` kennt (`queryIntentActivities`, dafür `<queries>` im Manifest). Eine feste App gilt
   auch, wenn in Android „Immer" auf eine andere gesetzt ist — so lässt sich ein falsches „Immer"
   in der App auflösen. Gespeichert unter `openWith`.
2. **Reihenfolge der Geräteordner** wie in der Immich-App: Nachgesehen in deren Quelltext
   (`v3.2.2`, `providers/infrastructure/album.provider.dart`): `localAlbumProvider` sortiert nach
   `SortLocalAlbumsBy.newestAsset` — der Ordner mit dem neuesten Foto zuerst; die empfundene
   „Wichtigkeit" (Camera, dann Screenshots) ist Aktualität. Übernommen für Bibliothek und
   Einstellungen. Das Datum stammt aus der Liste aller Fotos (neueste zuerst, wie die Zeitleiste);
   das erste Foto, das photo_manager je Ordner liefert, ist nicht verlässlich das neueste — der
   erste Versuch damit stellte Screenshots (22.09.) vor Camera (23.09.).

**Geprüft** 24.09.2026 auf dem Pixel (Release): Bibliothek „Camera, Screenshots, Telegram Images,
Camera Remote, WhatsApp …"; Einstellungen → Speichern → „Bearbeitungen öffnen mit" zeigt Android
fragen, Immich, Noodle Gallery; „Immich" gewählt, angezeigt, zurück auf „Android fragen".

---

## 2026-09-24 · D-51: Gerätefotos gleich beim Start

Befund des Besitzers am Pixel: Beim Öffnen stehen erst nur die Server-Stapel da, die Gerätefotos
kommen etwa 3 s später. **Gemessen** 24.09.2026 auf dem Pixel (17.490 Fotos, Profil-Build,
Zeitmarken): Gerätefotos erst nach **5,6–6,2 s** — alle Fotos auflisten 1,1–2,1 s, Prüfsummen-Datei
lesen < 0,1 s, `bulk-upload-check` in 18 Anfragen nacheinander **2,7–3,3 s**, alle Fotos ein
zweites Mal auflisten **1,1 s**.

Gebaut:
- `existing` stellt die Anfragen zu je 1.000 gleichzeitig.
- Der Abgleich nimmt die Liste des Prüfsummen-Laufs (`lastListed`) statt neu aufzulisten.
- Er merkt sich sein Ergebnis in `backup.json` (Gerätefotos nur hier mit Datum, Maßen, Ordner;
  dazu die Sets für die Wolken). Die Galerie zeigt diesen Stand sofort und ersetzt ihn, sobald der
  frische Abgleich da ist. Neue Fotos erscheinen nach dem Abgleich.

**Ergebnis** auf dem Pixel: frischer Abgleich nach **2,3–2,8 s**; der gemerkte Stand steht
**0,6–0,7 s** nach dem Antippen des App-Symbols (Log: `START` → Stand geladen), mit dem Erscheinen
des Fensters — auf dem Bildschirmfoto nach 1,5 s die ganze Zeitleiste mit den Kamerafotos.

---

## 2026-09-24 · D-50: Befund — „In Immich öffnen" auf dem Pixel

Geprüft 24.09.2026 auf dem Pixel des Besitzers (Release-Stand `cc669d6`, als Testbenutzer; die
Immich-App dort mit dem Hauptkonto, auf Wunsch des Besitzers nicht umgemeldet):

- Testfoto in `Pictures/EditorTest` (nicht gesichert), in der App gedreht, gespeichert → Frage
  „Bearbeitung in Immich öffnen?" → „In Immich öffnen": Kopie beim Testbenutzer archiviert, im
  Album „Editor for Immich".
- `immich://asset?id=…` löst Androids Auswahl aus: **Immich und Noodle Gallery** verstehen den
  Link beide. „Immich" gewählt → die Immich-App geht auf und zeigt ihre Zeitleiste; das Foto des
  Testbenutzers kann sie mit dem Hauptkonto nicht finden. Der Sprung trägt; ob sie das Foto
  öffnet, lässt sich erst mit demselben Konto prüfen.
- Danach aufgeräumt: Testordner auf dem Telefon gelöscht, Kopie beim Testbenutzer im Papierkorb.

Nebenbefunde: Die Bibliothek listet auf dem Pixel 62 Ordner in etwa 1 s (Camera ganz unten).
Wischen per `adb` scrollt dort weder Zeitleiste noch Bibliothek, Tippen wirkt — von Hand scrollt
die Liste (der Besitzer: im Debug-Build etwas holprig).

---

## 2026-09-24 · D-49: Befund — der erste Bildabgleich einer großen Bibliothek

Gemessen 24.09.2026 auf dem Pixel 7 Pro des Besitzers (17.490 Fotos), App-Stand `cc669d6` als
Debug-Build (die Prüfsummen rechnet Kotlin, Debug ändert daran nichts): `checksums.json`
beiseitegelegt, `dumpsys battery unplug`, `batterystats --reset`, App gestartet.

- Das Erklärfenster (D-39) erschien: „1.960 von 17.490 Fotos · fertig in etwa 4 Minuten".
- **Dauer: etwa 7½ Minuten** (12:05:30 Start bis 12:13:11 alle 17.490 in der Datei), im Mittel
  39 Fotos/s, ungleichmäßig (Stufen zu je 1000 zwischen 15 und 75 s) — die erste Schätzung war zu
  knapp, sie folgt dem Tempo der ersten Sekunden.
- **Akku: 10,4 mAh** für die App laut `batterystats` (Vordergrund 3 min, Hintergrund 4½ min),
  etwa 0,24 % von 4.370 mAh; die Anzeige blieb bei 95 %.
- Der Lauf ging weiter, als der Bildschirm ausging und die App nicht mehr vorn war.

Danach Release-Build wieder installiert; die neue Datei bleibt, die alte ist gelöscht.

**Anwenden:** Der erste Abgleich ist einmalig tragbar; kein Grund, ihn in WorkManager
auszulagern. Die Restzeit-Schätzung könnte das Tempo über ein längeres Fenster mitteln.

---

## 2026-09-24 · D-48: Welche Geräteordner unter „Fotos" und in der Bibliothek erscheinen

Befund des Besitzers am Pixel: Unter „Fotos" stand alles vom Gerät durcheinander — Screenshots,
Downloads, Messenger. Bei Google Fotos stehen dort die Kamerabilder. Gewünscht: wählen, welche
Ordner unter „Fotos" erscheinen, und Ordner aus der Bibliothek ausblenden.

- **Einstellungen → Geräteordner**: zwei Listen mit Häkchen, „Unter ‚Fotos' zeigen" (Vorgabe
  `DCIM/Camera/`) und „In der Bibliothek ausblenden". Ein Ordner ist sein relativer Pfad, wie ihn
  die App schon beim Speichern nutzt; gespeichert unter `photoFolders` und `hiddenFolders`.
- „Fotos" zeigt weiter alles vom Server (Immichs Zeitleiste) und vom Gerät nur, was in den
  gewählten Ordnern liegt und noch nicht gesichert ist. Die getrennte Ansicht „Gerät" bleibt
  vollständig.

**Geprüft** 24.09.2026 im Emulator: Ordner `Pictures/Screenshots` mit einem Foto ohne
EXIF-Datum angelegt — unter „Fotos" nicht zu sehen; Einstellungen zeigen Privat, Camera,
Screenshots, Camera angehakt. Screenshots unter „Fotos" an, Privat ausgeblendet → „Fotos" zeigt
das Foto oben, die Bibliothek nur Camera und Screenshots.

---

## 2026-09-23 · D-47: Im Betrachter über Monatsgrenzen wischen

Bisher endete das Wischen am Rand des Monats, aus dem man ein Server-Foto öffnete. Jetzt lädt der
Betrachter am Rand den Nachbarmonat nach (`more` in `ViewerPage`, `_openAcross` in der Galerie):
ältere Monate werden angehängt, neuere vorangestellt und die Seite um ihre Anzahl verschoben;
ein Monat nur mit Videos wird übersprungen. Zeitleiste und getrennte Server-Ansicht; die
Gerätefotos-Ansicht war schon durchgehend.

**Geprüft** 23.09.2026 im Emulator: erstes Foto im Oktober 2022 geöffnet, zeigt „30. Okt. 2022";
nach rechts → „3. Mai 2026", zurück → „30. Okt. 2022".

---

## 2026-09-23 · D-46: Stapeln im Hintergrund

ROADMAP: stapeln, ohne dass man die App öffnet. Über Androids **WorkManager** (Plugin
`workmanager`, MIT; AndroidX WorkManager, Apache-2.0; ohne Play-Dienste — [LICENSES.md](LICENSES.md)):

- Eine periodische Aufgabe (Androids Minimum 15 Minuten, nur mit Netz) ruft `stackPending` in
  einer Flutter-Engine ohne Activity. Eingeplant, sobald etwas in die Warteschlange kommt oder nach
  einem Lauf noch etwas wartet; abbestellt, wenn sie leer ist — ohne Wartendes läuft nichts.
- Ohne Activity gibt es keinen Renderer-Kanal (Prüfsummen) und keinen Löschdialog: Der
  Hintergrund stapelt nur. Lokale Kopien, die danach das Gerät verlassen sollen (D-28), merkt er
  sich (`deviceTrashLater`); beim nächsten Start fragt Android einmal für alle. Unerreichbares
  verwirft nur der Vordergrund (D-45).
- Vordergrund und Hintergrund können sich überschneiden (zwei Isolates); doppelt stapeln ist
  harmlos.

**Geprüft** 23.09.2026 im Emulator: App auf dem Home-Bildschirm, Backup der Kopie
`preset-11.edit (1).jpg` nachgestellt. Erzwingen (`cmd jobscheduler run -f -n
androidx.work.systemjobscheduler …`) lehnt WorkManager für periodische Arbeit ab („executed before
schedule"); der reguläre Lauf kam 14 Minuten nach dem Einplanen: `Worker result SUCCESS` nach
2,4 s, per API die Kopie vorn im Stapel mit `preset-11.jpg`, die ersetzte Kopie weg. Beim
nächsten Öffnen der App fragte Android, die lokale Kopie in den Papierkorb zu legen; danach war sie
vom Gerät. Stolperstein: `am force-stop` löscht die eingeplanten Aufgaben der App bis zum
nächsten Start (Wegwischen nicht).

---

## 2026-09-23 · D-45: Server-Fotos mit lokalem Original lokal bearbeiten; Unerreichbares verwerfen

Nach D-24 („Original liegt auf dem Gerät: die App bearbeitet die lokale Datei und fragt den
Server nichts") — bisher galt das nur für Fotos, die man vom Gerät aus öffnete.

- `loadPhoto` sucht die Prüfsumme des Originals — bei einer Kopie die aus ihrem Rezept — in den
  **gespeicherten** Geräte-Prüfsummen (`deviceIdWithChecksum`; rechnet nie, damit der Editor
  nicht auf einen Abgleich wartet). Bei einem Treffer lädt es die lokale Datei und nimmt sie nur,
  wenn ihre SHA-1 noch stimmt. Dann: volle Auflösung und HDR sofort, kein Vorschaubild vom
  Server, die Kopie geht in den Ordner des Originals und wird vorgemerkt — wie bei Gerätefotos.
- Ob ein Foto auf dem Gerät liegt, leitet `saveCopy` jetzt aus dem Foto ab (`folder`), nicht aus
  dem Einstieg. **Ersetzen** trifft auch den Zwilling einer Server-Kopie auf dem Gerät (über die
  Prüfsumme; Android fragt), der Server-Teil geht beim Stapeln in den Papierkorb.
- **Warteschlange:** Nach dem Stapeln fällt heraus, was nie ankommen kann — Kopie oder Original
  weder auf dem Server noch auf dem Gerät (`unreachable`, getestet). Es zählt nur ein
  Prüfsummen-Lauf, der nach dem Lesen der Warteschlange begann, sonst ginge eine eben gespeicherte
  Kopie verloren; ohne Zugriff auf die Fotos wird nichts verworfen. Eine Kopie, die da ist, aber
  nicht gesichert wird, wartet weiter.

**Geprüft** 23.09.2026 im Emulator: vordere Kopie des Stapels `geraet-preset` (Original auch auf
dem Gerät) geöffnet — Bild nach 1,4 s statt 2 s, gespeichert: `geraet-preset.edit (1).jpg` im
Kameraordner, kein Upload. Stapel `preset-11` (Original nur auf dem Server, alte Kopie auch als
Datei hier) → „Kopie ersetzen" → Android fragt, die alte Datei ist weg, die neue da. Warteschlange:
10 Einträge bleiben 10 (alle Kopien noch auf dem Gerät); `testfoto-a-lokal.edit.jpg` gelöscht →
9.

---

## 2026-09-23 · D-44: Eine Kopie öffnet in 2 s

ROADMAP: Eine ältere Kopie aus dem Betrachter zu öffnen dauerte „etwa 8 s". **Gemessen**
23.09.2026 im Emulator (Debug-Build, vom Tippen auf „Bearbeiten" bis zum Bild im Editor, von
außen über `adb`; dazu die Zeitmarke `editor: image after … ms` im Debug-Log): vorher
**2,5–2,9 s** (vordere Kopien 2,5 und 2,7 s, ältere Kopie V1 2,9 s) — die 8 s stammten aus einem
älteren Stand. Schritte einzeln gemessen: Details und Anfang je 0,1–0,5 s, Suche nach dem Original
0,1 s, **Immichs Vorschaubild etwa 1,1 s** — der größte Posten.

Gebaut (`loadPhoto` in `lib/editor/save.dart`):
- Details und Anfang der Datei gleichzeitig; bei einer Kopie Details und Vorschaubild des
  Originals gleichzeitig. Den Anfang des Originals lädt der Editor nicht mehr — er wurde nie
  gebraucht. Einstellungen und Presets lesen nebenher.
- Das Vorschaubild lädt gleich mit, sobald die Details sagen, dass der Name nicht nach Kopie
  aussieht (`.edit`). Nur eine Vermutung fürs Vorladen; ob es eine Kopie ist, entscheidet weiter
  das Rezept im XMP.
- Verworfen: das Vorschaubild immer vorab laden — der Download der Kopie verdrängte die übrigen
  Anfragen, Kopien brauchten dann 3,0–3,3 s. Ebenso ohne Wirkung: ruhende Verbindungen länger
  halten (Darts Vorgabe 15 s).
- Parallele Anfragen werden gestartet und einzeln abgewartet, damit ein Netzfehler als er selbst
  ankommt und nicht als `ParallelWaitError`.

**Ergebnis**, zwei Durchgänge: vordere Kopien **2,0–2,3 s**, ältere Kopie V1 **1,9–2,0 s**,
Original 1,8–2,0 s — Abnahme (< 3 s) erfüllt. Eine geöffnete Kopie wird weiter als Kopie erkannt
(⋮ „Zur gespeicherten Bearbeitung").

---

## 2026-09-23 · D-43: Anzeigesprache Deutsch und Englisch

Wunsch des Besitzers: die App international verständlich — Anzeigesprache nach dem Gerät,
zunächst Deutsch und Englisch, in den Einstellungen umstellbar.

- Flutters eigener Weg: `flutter_localizations` (SDK) und `intl`, beide BSD-3-Clause
  ([LICENSES.md](LICENSES.md)); Texte in `lib/l10n/app_en.arb` (Vorlage) und `app_de.arb`,
  147 Schlüssel, Mehrzahl als ICU-Plural; `flutter gen-l10n` erzeugt `AppLocalizations`.
- Einstellungen → **Sprache**: „Sprache des Geräts" (Vorgabe), Deutsch, English; gespeichert
  unter `language`, bleibt beim Abmelden erhalten. Andere Gerätesprachen bekommen Englisch.
- Widgets holen Texte über `AppLocalizations.of(context)` und bauen sich beim Umschalten neu auf;
  Code ohne Kontext (Fehlermeldungen, Speicherschritte) über `l10n` aus `lib/language.dart`.
- Datum, Monate, Wochentage und Zahlen über `intl` statt eigener deutscher Listen („Mi.,
  23. Sept. 2026 · 12:00", „f/1,9" bzw. „f/1.9").
- Im Emulator steht die App auf Deutsch (Einstellung), weil `tool/emu.sh` deutsche Texte sucht.

**Geprüft** 23.09.2026: Widget-Test — Testgerät englisch → „Log in", auf Deutsch gestellt →
„Anmelden" ohne Neustart; `fr` → Englisch. Im Emulator (Gerät Englisch): Galerie und
Konto-Fenster englisch („8 edits are waiting for the backup"); Einstellungen → Language → Deutsch
→ sofort deutsch, auch die Seite darunter; nach Neustart weiter deutsch; Betrachter-Infos mit
deutschem Datum und Dezimalkomma.

---

## 2026-09-23 · D-42: Code auf Englisch

Wunsch des Besitzers, damit die App international verständlich ist: alle Dateinamen,
Bezeichner und Kommentare im Code auf Englisch — Dart, Kotlin (auch der AGSL-Shader), Tests,
`tool/emu.sh` (`tap`, `shot`, `open_photo` …), `doccheck.py`. Die Doku bleibt bis zur Übersetzung
Deutsch (D-15); ältere Einträge hier nennen die alten Namen.

- Gespeichertes bleibt, damit bestehende Installationen (Pixel) nichts verlieren: die Schlüssel
  in `flutter_secure_storage` samt Werten (`hdr`, `mobil`, `online`, `zusammen`, `stapeln` mit den
  Feldern `kopie`, `original`, `alt`, `entfernen`), markiert mit `// persisted: do not rename`.
- Umbenannt, weil nie ausgeliefert: `abgleichErklaert` → `checksumsExplained`, das Feld `rezept`
  in `presets.json` → `recipe`. `pruefsummen.json` heißt `checksums.json`; die App benennt die
  alte Datei beim ersten Lesen um.
- Der Stapel-Typ heißt `PhotoStack` (nicht `Stack`, das ist Flutters Widget).
- Die Anzeigesprache folgt als Nächstes dem Gerät, Deutsch und Englisch, umstellbar (ROADMAP).

**Geprüft** 23.09.2026: `flutter analyze` ohne Befund, 18 Flutter- und 9 JVM-Tests grün; im
Emulator Galerie, Editor (Shader rendert, HDR-Knopf nach dem Original), Speichern als Kopie mit
Rezept und `hdrgm`, `checksums.json` aus der alten Datei umgezogen. Die Instrumented Tests
(`RendererTest`) sind übersetzt und kompilieren, liefen aber nicht (sie deinstallieren die App).

---

## 2026-09-23 · D-41: Der Nullpunkt der Lineale ist zu sehen

Wunsch des Besitzers: Die Null rastet mit kurzem Haptik-Feedback ein, war aber kaum zu sehen
(nur ein hellerer Strich). Jetzt ist sie in allen Linealen (Regler, Winkel) ein dicker
bernsteinfarbener Strich mit Punkt — anders als die blaue Mitte. Die Mitte wird zuerst
gezeichnet; steht der Regler auf 0, liegt die Null darüber und die Mitte leuchtet bernstein.

**Geprüft** 23.09.2026 im Emulator: Helligkeit 32 → Null links der Mitte sichtbar; auf 0
gezogen → eingerastet, Mitte bernsteinfarben.

---

## 2026-09-23 · D-40: Presets — im Editor sichern, auf eine Mehrfachauswahl anwenden

Gebaut nach der Spec (*Presets*: ein Rezept ohne Geometrie und ohne Masken):
- **Editor**, Reiter **„Presets"** vorn (Spec, *Bedienung*): „Sichern" fragt einen Namen und
  nimmt die veränderten Regler; ein Preset antippen setzt dessen Regler, Zuschnitt und Drehung
  bleiben; lange drücken löscht (mit Rückfrage). Namen statt Vorschaubildern — der Renderer
  rechnet nur ein Bild zugleich.
- Abgelegt in `presets.json` im App-Ordner, je Preset das Rezept-JSON (`v: 1`); nicht in
  `flutter_secure_storage`, das beim Abmelden geleert wird.
- **Galerie**: Mehrfachauswahl (langer Druck) → ✨ „Preset anwenden" → Preset wählen → Fortschritt
  „3 von 20 Fotos". Jedes Foto geht denselben Weg wie aus dem Editor: Die Lade- und Speicherlogik
  steckt jetzt in `lib/editor/speichern.dart` (`fotoLaden`, `kopieSpeichern`), Editor und
  Mehrfachauswahl rufen sie beide. Der native Export bekommt das Original als Bytes und braucht
  keine Editor-Sitzung mehr.
- Eine gewählte **Kopie dieser App** wird **ersetzt** (Original mit dem Zuschnitt der Kopie und
  den Reglern des Presets; die alte Kopie in den Papierkorb) — die Vorgabe aus D-31, ohne
  Rückfrage je Foto. Ein Fehler hält die übrigen nicht auf; die Meldung nennt die Zahl.

**Abnahme (M2) gemessen** 23.09.2026 im Emulator, Testbenutzer: Preset „Kontrast" gesichert;
20 Fotos gewählt — 19 vom Server (8 bearbeitete Stapel, 11 neue `preset-01` … `-11`) und
`geraet-preset.jpg`, das nur auf dem Gerät lag. Anwenden: **233 s** (etwa 12 s je Foto: Original
laden, rendern, in den Kameraordner, Vorgabe „übers Gerät", D-28); 20 Kopien, kein Fehler, jede
mit dem Rezept des Presets und `hdrgm`. Backup der Immich-App nachgestellt (Dateien unverändert per
`POST /assets`); nach dem Neustart der App über die Asset-IDs geprüft: **20 von 20 Kopien vorn im
Stapel mit ihrem Original**, auch `geraet-preset.edit.jpg`; ersetzte Kopien im Papierkorb.

---

## 2026-09-23 · D-39: Der erste Bildabgleich erklärt sich

Befund des Besitzers auf dem Pixel: Beim ersten Öffnen stand oben nur „6000/17400" neben dem
Profilbild — niemand weiß, was da läuft. Gewünscht und gebaut:
- Beginnt der Abgleich (D-36) zum ersten Mal, erklärt ein **Fenster „Bildabgleich"**: einmal je
  Foto eine Prüfsumme, um zu erkennen, was schon in Immich liegt (Wolken); nur beim ersten Mal,
  danach nur neue Fotos; hochgeladen wird nichts, an den Server gehen nur Prüfsummen. Darunter
  Balken, „200 von 1.211 Fotos" und die Restzeit nach dem bisherigen Tempo. Einmal je
  Installation (`speicher`-Schlüssel `abgleichErklaert`); das Fenster schließt sich, wenn der
  Abgleich fertig ist.
- **„Im Hintergrund"** minimiert es ins Profil: ein Fortschrittsring ums Profilbild wie Immichs
  Backup-Anzeige, im Konto-Fenster ein Abschnitt „Bildabgleich" mit Balken und Stand. Die Zahl in
  der Leiste entfällt.
- Ein Stand für alle drei: `abgleichStand` (`ValueNotifier`) in `pruefsummen.dart` statt des
  bisherigen Rückrufs.

**Geprüft** 23.09.2026 im Emulator: `pruefsummen.json` gelöscht, 400 bzw. 1.200 Kopien eines
Testfotos in `DCIM/Abgleichtest`. Erstes Öffnen → Fenster mit Erklärung und „0 von 411 Fotos",
nach dem Lauf von selbst zu. Zweiter Lauf (1.211 Fotos, kein Fenster mehr) → Ring ums Profilbild
wächst; Konto-Fenster „200 von 1.211 Fotos · fertig in etwa 2 Minuten"; nach dem Lauf sind Ring
und Abschnitt weg, `pruefsummen.json` hat 1.211 Einträge. Testfotos danach gelöscht.

---

## 2026-09-23 · D-38: Neben der Immich-App, ohne Verwechslungen; Immich als Quelle

Leitlinien des Besitzers:

1. **Zusammenarbeit mit der Immich-App.** Die App verändert keine vorhandenen Dateien auf dem
   Gerät, nur eigene Kopien (neue Dateien; gelöscht werden nur eigene Kopien, mit Rückfrage von
   Android). Mit der Immich-App teilt sie nichts außer dem Server; jede App führt ihre eigenen
   Prüfsummen (unsere in `pruefsummen.json` im App-Ordner). Weil Originale unverändert bleiben,
   muss keine App wegen der anderen neu einlesen — die Immich-App liest die Kopie wie ein neues
   Kamerafoto. Die Prüfsummen stimmen überein, weil beide die unveränderte Datei mit Ort lesen
   (`ACCESS_MEDIA_LOCATION`, D-26). Auf dem Server ändert die App Assets der Immich-App nicht,
   außer sie zu stapeln und in Alben zu legen.
2. **Immich als Informationsquelle**, so weit es keine Komplikationen macht: die öffentliche
   Server-API (Timeline, Stapel, EXIF und Ortsnamen, Speicherplatz, Nutzer,
   `bulk-upload-check`). Die Datenbank der Immich-App auf dem Handy ist nicht erreichbar
   (Android-Sandbox, kein ContentProvider) — deshalb eigene Prüfsummen (D-36; die Geräte-ID als
   Abkürzung hat der Besitzer verworfen: zu unsicher). Keine eigenen Kopien von Serverdaten, die
   Immich schon liefert.

**Anwenden:** Bevor die App etwas selbst rechnet oder speichert, in der API-Beschreibung
(`open-api/immich-openapi-specs.json`, Tag `v3.2.2`) nachsehen, ob Immich es liefert.

---

## 2026-09-23 · D-37: Alles wird hier bearbeitet — Immich ist Galerie und Backup

Vorschlag (Agent): reine Geometrie-Änderungen (Zuschneiden, 90° drehen, Spiegeln) über Immichs
`PUT /assets/{id}/edits` am Original speichern statt als Kopie — kein zweites Foto, wie Google
Fotos es bei umkehrbaren Änderungen hält. Entscheidung des Besitzers: **nein.** Jede Bearbeitung,
auch die Geometrie, entsteht in diesem Editor und wird wie alle anderen als Kopie mit Rezept
gespeichert (D-2); Immich bleibt Galerie und Backup, niemand soll zwischen zwei Editoren wechseln.

**Anwenden:** keine Wege über Immichs Bearbeitungsfunktionen vorschlagen; neue Werkzeuge gehören
ins Rezept.

---

## 2026-09-23 · D-36: Eine Zeitleiste über Gerät und Server; Ordner, die Immich nicht sichert

Entscheidungen des Besitzers (23.09.2026): Die Galerie zeigt wie die Immich-App **eine Zeitleiste**
mit Wolken für den Stand; getrennt nur per Einstellung. Gerätefotos gelten als gesichert, wenn der
Server ihre **Prüfsumme** kennt — wie in der Immich-App, nicht über die Geräte-ID. Fotos aus
Ordnern, die die Immich-App nicht sichert, lassen sich bearbeiten; danach **fragt** die App und
lädt auf Wunsch **archiviert** hoch, ins Album „Editor for Immich", und öffnet die Kopie in der
Immich-App. Die Ordner liegen im Reiter **„Bibliothek"**.

Gebaut:
- **Prüfsummen** nativ (`MainActivity`, eigener Faden, aus der Datei gestreamt, mit
  `setRequireOriginal`), zwischengespeichert in `pruefsummen.json` im App-Ordner mit dem
  Änderungszeitpunkt je Foto; neu gerechnet wird nur, was neu ist oder sich geändert hat
  (`abgleichen`, getestet). Abgleich mit dem Server über `POST /assets/bulk-upload-check` in Bündeln
  zu 1000 — liefert die Server-ID auch archivierter Fotos, nicht solcher im Papierkorb. Auch das
  Stapeln (D-26) gleicht jetzt so ab: eine Anfrage statt drei je Kopie.
- **Zeitleiste** „Fotos": die Monate des Servers plus die Fotos, die nur auf dem Gerät liegen, nach
  Aufnahmezeit gemischt (`fileCreatedAt` aus der Timeline). Wolke unten rechts wie Immichs
  `thumbnail_tile`: `cloud_off` nur Gerät, `cloud` nur Server, `cloud_done` beides. Solange
  Prüfsummen gerechnet werden, zeigt die Leiste den Fortschritt. Einstellungen → Ansicht: „Gerät und
  Server zusammen" aus → Reiter „Gerät", „Immich", „Bibliothek" wie vorher.
- **Bibliothek**: „Auf diesem Gerät", jeder Ordner mit Anzahl und wie viel gesichert ist; Ordner
  öffnen, Foto ansehen, bearbeiten.
- **Nicht gesichert** heißt: Weder das Original noch ein anderes Foto des Ordners (bis 200) liegt
  auf dem Server. Dann nach dem Speichern die Frage „Bearbeitung in Immich öffnen?"; bei Ja
  `POST /assets` mit `visibility: archive`, gegenprüfen, Album „Editor for Immich" (angelegt, wenn
  es fehlt), `immich://asset?id=…` — die Immich-App versteht den Link (`deep_link.service.dart`).
- Grenze: Archivierte Kopien stehen nicht in der Zeitleiste (wie in der Immich-App), nur im Album
  und im Ordner.

**Geprüft** 23.09.2026 im Emulator: Zeitleiste mit Server-Stapeln (Wolke), Gerätefotos (Wolke
durchgestrichen), dem gesicherten Testfoto-B-Stapel (Haken) und ohne Doppelte; Bibliothek „Camera ·
9 Fotos · 2 gesichert". Ordner `Pictures/Privat` angelegt, Foto bearbeitet → Frage → Kopie im
Ordner und auf dem Server archiviert (gleiche SHA-1), Album „Editor for Immich" mit 1 Foto; der
Sprung in die Immich-App ist nur auf dem Pixel prüfbar (Emulator ohne Immich-App → Meldung).

---

## 2026-09-23 · D-35: Aussehen der Immich-App, Bedienung aus Google Fotos

Leitlinie des Besitzers: Die App folgt dem **Design der Immich-App** — Farben, Schrift, Konto-Fenster,
Einstellungen —, übernimmt aber **Funktionen und entscheidende Bereiche aus Google Fotos**
(Editor schwarz mit Werkzeugen unten, D-22; Betrachter und Stapel, D-33, D-34).

Übernommen aus dem Quelltext der Immich-App (Tag `v3.2.2`, AGPL-3.0 wie diese App, D-3):
- **Theme** (`lib/thema.dart`): Markenfarbe `#4150AF` / dunkel `#ACCBFA`, entfärbte Flächen,
  Textgrößen, AppBar mit Titel in der Markenfarbe, Schrift **Google Sans** (SIL Open Font License
  1.1, in `fonts/GoogleSans/` mit `OFL.txt`). Editor und Betrachter: dasselbe Theme dunkel, Editor
  auf Schwarz.
- **Konto-Fenster** wie `ImmichAppBarDialog`: oben Schließen und Name, in einer Karte Profil
  (Avatar wie `UserCircleAvatar`, Immichs Avatarfarben), Speicherplatz (Kontingent des Nutzers,
  sonst `GET /server/storage`), App-Version, Server-Version, Server-Adresse; darunter wartende
  Bearbeitungen, Einstellungen, Abmelden (mit Rückfrage), unten Lizenzen. Nicht übernommen: Immichs
  Logo (Marke, D-5), Profilbild hochladen, App-Protokoll, „Speicher freigeben".
- **Einstellungen** wie `SettingsPage`: eine Karte je Bereich (Bearbeiten, Speichern, Netzwerk,
  Stapeln), darin Schalter wie `SettingsSwitchListTile`.
- App-Version über den Plattformkanal (`PackageManager`), keine neue Abhängigkeit.

**Geprüft** 23.09.2026 im Emulator: Galerie mit Titel links in der Markenfarbe; Konto-Fenster mit
„104,4 MiB von 10,0 GiB belegt", „0.0.1 build.1", „3.2.2", Server-Adresse, „6 Bearbeitungen warten
auf das Backup"; Einstellungen als Karten, Bereich „Speichern" mit Schalter.

---

## 2026-09-22 · D-34: Stapel im Betrachter wie Langzeitbelichtungen bei Google Fotos

Wunsch des Besitzers (Bildschirmfoto von Google Fotos als Vorlage): Oben Datum und Uhrzeit
(Ortszeit), darunter die Version des gezeigten Fotos; unter dem Bild die Miniaturen des Stapels,
Antippen zeigt das Mitglied. Reihenfolge fest: **Original, V1, V2 …** — Kopien nach ihrem
Entstehen (`createdAt`), das Hauptfoto mit Stern. ⋮ an der gewählten Miniatur: **„Als Hauptfoto
festlegen"** (`PUT /stacks/{id}`, nicht am Hauptfoto) und **„Dieses Foto behalten, den Rest
löschen"** (nach Rückfrage: die übrigen in Immichs Papierkorb, `DELETE /stacks/{id}` löst den
Stapel auf). Mehrfachauswahl wie bei Google entfällt — kein Bedarf (Besitzer).

**Geprüft** 22.09.2026 im Emulator am Stapel `testfoto-a-hdr` (Original + 2 Kopien): V1 als
Hauptfoto → Server meldet V1 vorn; Original behalten → beide Kopien im Papierkorb, kein Stapel
mehr, Datum weiter sichtbar. Danach Testdaten wiederhergestellt.

Zwei Fehler dabei: `setState(() => _x = future)` gibt den Future zurück, Flutter bricht ab — als
Block schreiben; nach „Rest löschen" lud die Seite den Stapel von der gelöschten Kopie aus —
jetzt vom gezeigten Foto.

---

## 2026-09-22 · D-33: Betrachter zwischen Galerie und Editor

Entscheidung des Besitzers: Fotos erst groß ansehen, dann bearbeiten; nach dem Speichern das
Ergebnis sehen. Teilen, Alben, Papierkorb und Karte bleiben bei der Immich-App.

Gebaut: Tippen auf eine Kachel öffnet den Betrachter — wischen durch die Fotos (Gerät: alle;
Server: bisher der Monat), zoomen bis 8×, bei Server-Stapeln unten die Mitglieder („Original",
„Bearbeitung", „Bearbeitung 2" — am Namen `.edit` erkannt), „Bearbeiten" öffnet den Editor mit
dem gezeigten Mitglied; der Editor gibt die neue Kopie zurück und der Betrachter zeigt sie.
Hochwischen zeigt Datum und Uhrzeit, Name, Megapixel, Maße, Größe, Kamera, Objektiv,
Belichtung, Ort — für Server-Fotos aus Immichs `exifInfo` (Ortszeit aus `localDateTime`, Ort als
Stadt und Land), für Gerätefotos aus Androids `ExifInterface` über den Plattformkanal (Ort als
Ortsnamen von Immichs `GET /map/reverse-geocode` — eigene Ortsdaten des Servers, kein fremder
Dienst; bloße Koordinaten zeigt die App nicht, sie sagen niemandem etwas (Besitzer); ISO steht
im Framework unter dem alten Namen `ISOSpeedRatings`). Keine neue Abhängigkeit.

Stolperstein: Hochwischen im `GestureDetector` erreicht die App nicht, der `InteractiveViewer`
nimmt die Geste; ausgewertet wird sie in dessen `onInteractionEnd`, nur ungezoomt.

**Geprüft** 22.09.2026 im Emulator: Server-Foto öffnen, Stapel mit drei Mitgliedern, Infos
(Google Pixel 7 Pro, f/1,9 · 1/231 s · ISO 47 · 6,8 mm, <Ort>), seitlich zum
nächsten Stapel; Bearbeiten → „Kopie ersetzen" → zurück im Betrachter mit der neuen Kopie;
Gerätefoto mit Infos aus dem EXIF.

---

## 2026-09-22 · D-32: Profilbild, Konto und eine Einstellungsseite

Befund des Besitzers: Eine Bearbeitung vom Gerät wurde gesichert, aber nie gestapelt. Ursache: Die
App war mit dem Testbenutzer angemeldet, die Immich-App mit seinem eigenen Konto — gestapelt wird
nur im Konto, in dem die App angemeldet ist (D-26). Das war nirgends zu sehen.

Deshalb, auf Wunsch des Besitzers nach dem Vorbild der Immich-App: oben rechts das Profilbild
(`GET /users/me`, `GET /users/{id}/profile-image`; ohne Bild die Initiale auf Immichs
`avatarColor`). Antippen zeigt Name, E-Mail, Server, wie viele Bearbeitungen aufs Backup warten
(mit dem Hinweis, dass die Immich-App mit diesem Konto sichern muss), „Abmelden" und
„Einstellungen". Die Einstellungen stehen auf einer eigenen Seite nach Abschnitten (Bearbeiten,
Speichern, Stapeln mit „Jetzt stapeln", Konto) statt im ⋮-Menü.

**Geprüft** 22.09.2026 im Emulator: Initiale „E" in Blau, Konto-Fenster mit „3 Bearbeitungen
warten auf das Backup", Einstellungsseite mit allen Schaltern.

---

## 2026-09-22 · D-31: Eine Kopie ersetzen oder daneben legen; Miniaturen neuer Kopien

Anlass: Rückmeldung des Besitzers (Pixel, Stand `4448976`). Speichern geht dort — das „App
reagiert nicht" des älteren Stands (D-23) tritt nicht mehr auf. Bei Google Fotos entstehen beim
Bearbeiten einer Kopie immer weitere Kopien, lose in der Galerie — unübersichtlich. Wer eine
Kopie ändert, will meist diese Kopie ändern.

Entscheidung: Wer eine Kopie öffnet (der Editor lädt das Original mit ihrem Rezept, D-23), wählt
beim Speichern **„Kopie ersetzen"** (die geöffnete geht in den Papierkorb, D-23) oder **„Als
weitere Kopie speichern"** (beide bleiben im Stapel). Eine Datei in Immich lässt sich nicht
ändern (D-1) — „ersetzen" heißt: neue Kopie vorn, alte in den Papierkorb, dort umkehrbar.
Bearbeitungen sind immer umkehrbar, weil das Original im Stapel liegt.

Befund zum Stapeln (Immich `v3.2.2`, `server/src/repositories/stack.repository.ts`, `create`):
`POST /stacks` führt einen bestehenden Stapel nur dann mit dem neuen zusammen, wenn dessen
**vorderes** Asset unter den `assetIds` ist; andernfalls wandert nur das genannte Asset um, die
übrigen bleiben zurück. Deshalb gibt die App jetzt `[neue Kopie, Original, bisher vordere]` —
alle Kopien bleiben in einem Stapel; das bisherige Löschen der vorderen Kopie (D-23) entfällt.

Schwarze Miniatur nach dem Speichern: Immich rechnet die Miniatur einer neuen Kopie erst Sekunden
nach dem Hochladen; die Kachel blieb nach dem Fehlschlag leer. Jetzt versucht sie es alle 2 s
erneut (höchstens zehnmal).

**Gemessen** 22.09.2026 im Emulator (direkt auf den Server): `testfoto-a-hdr` → „Als weitere
Kopie" → Stapel mit neuer Kopie vorn, Original, älterer Kopie; Miniatur sofort in der Galerie.
Die neue Kopie geöffnet → „Kopie ersetzen" → Stapel mit neuester Kopie, Original, älterer Kopie;
die ersetzte im Papierkorb.

---

## 2026-09-22 · D-30: Einstellung „Mobile Daten"

Nach D-24: Galerie (⋮) „Originale und Uploads über mobile Daten", Vorgabe an — Speichern soll
unterwegs ohne Umweg gehen. Ist sie aus und die Verbindung getaktet (Androids
`isActiveNetworkMetered`, per Plattformkanal, keine neue Abhängigkeit; braucht
`ACCESS_NETWORK_STATE`), lädt der Editor das Original nicht von selbst nach und fragt beim
Speichern einmal, wenn noch ein Original zu laden oder die Kopie direkt hochzuladen ist.
Miniaturen, Vorschaubilder und API-Aufrufe laufen immer; das Backup der Kopie auf dem Gerät regelt
die Immich-App selbst.

**Gemessen** 22.09.2026 im Emulator: Einstellung aus, WLAN aus (Mobilfunk, getaktet) → Editor
mit Vorschaubild, nach 15 s noch kein Original (kein HDR-Knopf); Speichern → Rückfrage;
„Trotzdem" → Kopie in voller Auflösung (3072 px breit).

---

## 2026-09-22 · D-29: Online-Fotos öffnen mit Immichs Vorschaubild; HDR nur im Bild

Der Editor lädt von einem Server-Foto zuerst nur Details, die ersten 64 KB (EXIF, Rezept-XMP —
genug, um eine Kopie zu erkennen) und Immichs Vorschaubild (`GET /assets/{id}/thumbnail?size=
preview`, schon aufgerichtet, ohne Gain-Map) und zeigt es sofort. Das Original lädt im
Hintergrund und ersetzt das Vorschaubild im Renderer, samt aktuellem Rezept (kein Aufblitzen);
erst dann gibt es HDR. Speichern wartet auf das Original („Original wird geladen …") — die Kopie
entsteht immer aus dem Original. Das Rezept ist auflösungsunabhängig, das Seitenverhältnis gleich.

**Gemessen** 22.09.2026 im Emulator (Debug-Build, `testfoto-a-hdr`, 4,6 MB): Bild im Editor nach
2,6 s, HDR-Knopf (Original da) nach 10,4 s; bisher kam das Bild erst mit dem Original. Sofort
gespeichert, bevor das Original da war → Kopie 3072 × 4080 mit `hdrgm`, MPF und Rezept.

**Befund des Besitzers** auf dem Pixel (22.09.2026): Der HDR-Knopf ändert nur das Bild; Leisten
und Knöpfe bleiben in normaler Helligkeit — wie gewollt (D-17, D-20).

---

## 2026-09-22 · D-28: Online-Fotos übers Gerät gesichert — gebaut

Nach D-25: Einstellung in der Galerie (⋮) „Bearbeitungen von Online-Fotos übers Gerät sichern",
Vorgabe an (`online` = `geraet`/`server`). Ist sie an, legt der Editor die Kopie eines reinen
Server-Fotos in den Kameraordner (`DCIM/Camera/`) und merkt sie mit ihrer Geräte-ID vor. Beim
Stapeln nach dem Backup (D-26) geht eine ersetzte Server-Kopie in Immichs Papierkorb, die lokale
Kopie in den des Geräts — für alle erledigten zusammen eine Rückfrage von Android.

Grenze: Die Immich-App sichert die Kopie nur, wenn der Kameraordner zum Backup gehört; sonst
bleibt sie auf dem Gerät und vorgemerkt.

**Gemessen** 22.09.2026 im Emulator: `testfoto-a-exif6` (nur auf dem Server, mit älterer Kopie)
bearbeitet → `testfoto-a-exif6.edit.jpg` im Kameraordner; Backup simuliert (Datei unverändert per
`POST /assets`); Aktualisieren → neue Kopie vorn im Stapel, alte Kopie im Papierkorb des
Servers, Rückfrage von Android, lokale Kopie weg.

---

## 2026-09-22 · D-27: Keine Server-Erweiterung; das Rezept-Format ist die Schnittstelle

Frage des Besitzers: eine abnehmbare Erweiterung für den Immich-Server, wie Noodle Gallery sie
anbietet, damit der Server die Bearbeitungen selbst versteht — und die auch mit Noodle läuft.

Befund (README von `open-noodle/gallery`, 22.09.2026): Noodle Gallery ist **kein Plugin,
sondern ein eigenes Server-Image** — ein Fork, der auf jede Immich-Version neu aufsetzt
(derzeit 3.2.2, eigene Versionsnummer `v5`). Abnehmbar ist es durch ein Skript, das seine
Tabellen und Spalten entfernt; die Datenbank bleibt mit Immich verträglich. Auf einem Server
läuft genau ein Image — eine Erweiterung „für Immich und Noodle" hieße, einen Patch auf beiden
Forks nach jeder Version nachzuziehen.

Entscheidung des Besitzers: **vorerst nicht**, der jetzige Weg (D-2) reicht. Begründung:
- Versteht der Server die Bearbeitung, muss er sie auch rendern (Miniaturen, Vorschau,
  Download) — ein zweiter Renderer in TypeScript/libvips, pixelgleich zum AGSL-Shader, mit
  Gain-Map; für Masken, 3D-LUTs und Radierer (M4, M5) kaum machbar. Genau das vermeidet D-2.
- Der Gewinn ist klein: Web, Immich-App und geteilte Alben zeigen die Bearbeitung schon, weil die
  Kopie vorn im Stapel liegt. Gespart würde vor allem der doppelte Speicherplatz.
- D-1 bliebe gültig: die App läuft mit jedem unveränderten Immich-Server.

Die Tür bleibt offen: Das Rezept steht versioniert als XMP (`ife:recipe`) in jeder Kopie, samt
Prüfsumme des Originals — eine spätere Server-Erweiterung, von uns, Noodle oder Immich, kann es
lesen. **Anwenden:** Das Rezept-Format stabil und dokumentiert halten (Spec, *Aufbau*); dass die
App auch gegen einen Noodle-Server läuft, steht in der ROADMAP.

---

## 2026-09-21 · D-26: Gerätefotos — bearbeiten ohne Server, stapeln nach dem Backup

Gebaut nach D-24:

- **Galerie** mit zwei Reitern unten, „Gerät" (`photo_manager`, neueste Aufnahme zuerst,
  Seiten zu 120) und „Immich" (wie bisher). Noch getrennt; eine Zeitleiste über beide steht in
  der ROADMAP.
- **Editor für Gerätefotos:** lädt die Datei vom Gerät, rechnet ihre SHA-1 selbst; speichert die
  Kopie (`<name>.edit.jpg`) in **denselben Ordner** mit **derselben Aufnahmezeit**
  (`DATE_TAKEN`) — so sichert die Immich-App sie mit, und sie steht neben dem Original.
- **Erneut bearbeiten** auf dem Gerät: Das Original einer Kopie findet sich über die
  Aufnahmezeit (gleiche Sekunde) und die SHA-1 aus dem Rezept-XMP. Die alte Kopie geht in den
  Papierkorb des Geräts; Android fragt dafür nach.
- **Stapeln später:** Jede lokale Kopie wird vorgemerkt (SHA-1 von Kopie, Original, ersetzter
  Kopie; in `flutter_secure_storage`). Beim Öffnen und Aktualisieren der Galerie sucht die App
  beide per Prüfsumme auf dem Server und stapelt wie beim direkten Speichern (`lib/stapeln/`).
- **`ACCESS_MEDIA_LOCATION` ist Pflicht.** Ohne sie liefert Android die Datei mit geschwärztem
  Ort: andere Bytes, eine SHA-1, die kein Backup trägt — und eine Kopie ohne GPS. Android erteilt
  sie ohne eigene Abfrage zusammen mit dem Fotozugriff.
- **Build:** `kotlin.incremental=false` in `android/gradle.properties` — Plugins liegen im
  Pub-Cache auf `C:`, der Build auf `M:`; Kotlins inkrementeller Cache scheitert daran
  („Could not close incremental caches").

**Gemessen** 21.09.2026 im Emulator (Testbenutzer): Testfoto B und Testfoto A mit angehängten
Nullbytes nach `DCIM/Camera` gelegt (nicht auf dem Server). Testfoto B bearbeitet → Kopie im
selben Ordner, gleiche `datetaken`; erneut geöffnet → Original mit Rezept; nochmals gespeichert →
alte Kopie im Papierkorb. Backup simuliert (beide Dateien unverändert per `POST /assets`
hochgeladen) → nach Ziehen zum Aktualisieren ein Stapel, Kopie vorn, Breitengrad in beiden.
Testfoto A (Ultra HDR) → Kopie mit `hdrgm`-XMP, MPF und Rezept.

**Anwenden:** Online-Fotos (D-25, Vorgabe „Gerät") nutzen denselben Weg.

---

## 2026-09-21 · D-25: Bearbeitung eines nur online liegenden Fotos — Einstellung, Vorgabe Gerät

Entscheidung des Besitzers zu E6: Der Nutzer wählt in den Einstellungen, der Besitzer selbst
neigt zu (b), deshalb ist (b) die Vorgabe.

- **(b) Gerät (Vorgabe):** Die Kopie geht wie bei Gerätefotos (D-24) in die Gerätegalerie, die
  Immich-App sichert sie, unsere App stapelt sie auf dem Server und entfernt die lokale Datei,
  sobald der Server sie hat (Prüfsumme, `POST /assets/bulk-upload-check`). Das Löschen aus der
  Gerätegalerie bestätigt Android beim Nutzer (`MediaStore.createDeleteRequest`).
- **(a) Server:** wie bisher (D-23) direkt hochladen, stapeln, gegenprüfen; auf dem Gerät bleibt
  nichts.

**Anwenden:** „Online-Fotos" (M2) baut beide Wege; Einstellung „Bearbeitungen von Online-Fotos:
Gerät / Server".

---

## 2026-09-21 · D-24: Wo bearbeitet und gespeichert wird — lokal vor Server, Netz nach Einstellung

Vorschlag und Entscheidung des Besitzers:

- **Original liegt auf dem Gerät** (gesichert oder nicht): Die App bearbeitet die lokale Datei
  und fragt den Server nichts. Die Kopie (mit Rezept-XMP) geht in die Gerätegalerie; die
  Immich-App sichert sie; unsere App stapelt auf dem Server, sobald Original und Kopie oben sind.
  Auf dem Gerät liegen beide ungestapelt nebeneinander, im Web als Stapel. Die App lädt eine
  solche Kopie nie selbst hoch — sonst entstünden Duplikate neben dem Backup.
- **Original liegt nur auf dem Server:** Der Editor öffnet sofort mit Immichs Vorschaubild; das
  Rezept ist auflösungsunabhängig. Das Original (volle Auflösung, Gain-Map) braucht es erst zum
  Speichern — Immich kann das Rezept nicht selbst rechnen (D-2), die fertige Kopie entsteht auf
  dem Gerät. Immichs Vorschaubilder tragen keine Gain-Map: HDR-Vorschau erst mit dem Original.
- **Netz:** Ob Originale und Uploads auch über mobile Daten laufen oder nur im WLAN, entscheidet
  der Nutzer in den Einstellungen.

Wohin die Bearbeitung eines *nur online* liegenden Fotos geht: D-25.

**Anwenden:** Galerie mit Gerätefotos (M2) baut darauf; Einstellungen „Mobile Daten" und
„Bearbeitungen lokaler Fotos: Gerät / direkt auf den Server".

## 2026-09-21 · D-23: Galerie über die Timeline; erneut bearbeiten; Speichern in 4 s

**Galerie:** `POST /search/metadata` kann Stapel nicht auf das vordere Bild reduzieren —
`withStacked:false` blendet *alle* gestapelten Bilder aus (Test: 1 statt 8 Einträge). Immichs
Timeline (`/timeline/buckets`, `/timeline/bucket`, `withStacked=true`) liefert je Stapel das
vordere mit Anzahl, monatsweise, so wie Immichs eigene App — 8 Einträge statt 15. Prüfsumme
und Dateiname lädt der Editor über `GET /assets/{id}` nach.

**Erneut bearbeiten** (Spec, *Speicherweg* 5): Trägt die geöffnete Datei ein Rezept dieser App,
öffnet der Editor das Original (Suche per Prüfsumme) mit diesem Rezept. Befund: Stapelt man ein
Original, das schon in einem Stapel liegt, neu, löst Immich den alten Stapel auf — die alte
Kopie steht danach lose in der Timeline (Test mit `POST /stacks`). Deshalb gehen beim Speichern
die geöffnete Kopie und die bisher vordere in den Papierkorb; die vordere nur, wenn ihr Anfang
(Teilabruf 64 KB, Server antwortet 206) ein Rezept dieser App trägt. Im Emulator geprüft: nach
dem Bearbeiten einer losen, älteren Kopie liegt genau eine aktive Kopie vorn im Stapel.

**Speichern war zu langsam** — der Besitzer brach auf dem Pixel ab, Android meldete „App
reagiert nicht". Gemessen im Emulator (Zeitmarken im Speicherweg): Rendern und Kodieren 0,5 s,
Hochladen 3,8 s, **Kopie zur Prüfung neu laden 7,9 s**, Stapeln/Alben/Papierkorb 2,4 s — gesamt
14,7 s. Vom PC dauern dieselben Anfragen 0,15 s (klein) bzw. 0,4 s (Download): Der Client baute
für jede Anfrage eine neue Verbindung auf. Jetzt: ein Keep-Alive-Client, und statt neu zu laden
vergleicht die App Immichs SHA-1 (beim Empfang berechnet) mit der eigenen (Android
`MessageDigest`) — gleich streng. Danach: 0,5 s + 3,0 s + 0,2 s + 0,3 s = **4,0 s**. Das
Dekodieren beim Öffnen lief auf dem Haupt-Thread und läuft jetzt im Hintergrund; ob damit die
ANR-Meldung verschwindet, ist auf dem Pixel noch zu prüfen.

Nebenbefund: D-22 nennt für den Speichertest „19 s" und die Werte einer anderen Kopie — an dem
Abend wurde zweimal gespeichert (20:03 Kontrast+Geometrie, 20:18 alle Regler durch
`adb`-Wischer über die Werkzeugleiste); untersucht wurde die von 20:03. Die Messwerte in D-22
gehören zu ihr, die 19 s zur zweiten.

**Anwenden:** Beim Prüfen nach dem Speichern die Kopie über ihre ID nehmen, nie „den ersten
Suchtreffer".

## 2026-09-21 · D-22: Stufe-1-Regler in einem Shader; Editor nach Google Fotos

Umsetzung: ein AGSL-Shader für alle zwölf Regler (Spec, Rezept-Format). Weißabgleich in
linearem Licht, Tonwerte in der wahrgenommenen Helligkeit; Schärfe als Unscharfmaske mit einem
Radius relativ zur Bildgröße, damit Vorschau und Export gleich aussehen; alle Regler 0 = Bild
unverändert. **Helligkeit ist jetzt eine Mittelton-Kurve** (γ = 2^−Wert), nicht mehr der
additive Versatz aus M1 (D-12) — vor dem ersten Release ist das Rezept-Format noch frei.

Wie geprüft: 11 Instrumented Tests auf der GPU des Emulators (`RendererTest`): neutral weicht
höchstens 2 von 255 ab; Helligkeit hebt Mitteltöne und lässt Schwarz; Kontrast spreizt;
Sättigung −1 ergibt Grau; Blautöne wirken aufs blaue Feld, nicht aufs orange; Wärme hebt Rot
und senkt Blau; Schatten, Spitzlichter, Weiß- und Schwarzpunkt, Vignette, Schärfe in ihre
Richtung; Geometrie tauscht Breite und Höhe. Im Emulator bearbeitet (Kontrast +0,39, 7,8°,
Zuschnitt), gespeichert: „Gespeichert und geprüft" nach 19 s, 2432×3333, `uhdrload`,
Gain-Map 552×757, Korrelation zum Bild 0,605 (gedreht −0,089).

Bedienung (Spec, *Bedienung*): schwarzer Editor, Reiter, runde Werkzeugknöpfe, Skalen-Lineal,
Zuschnittrahmen mit Anfassern (Abdunklung außen gemessen: Helligkeit 76 → 42),
Rückgängig/Wiederholen, Gedrückthalten zeigt das Original.

Befund beim Bauen: Lineal und Zuschnittrahmen rechneten jeden Zug vom Wert des letzten
Neuzeichnens aus — kommen mehrere Züge im selben Frame, ging Bewegung verloren (ein Zug über
86 px ergab 1° statt 8°). Beide führen jetzt während des Ziehens einen eigenen Wert.

**Anwenden:** Neue Regler kommen in `Renderer.REGLER`, den Shader und `werkzeuge` (Dart) — und
bekommen einen Test in `RendererTest`.

## 2026-09-21 · D-21: Geometrie für Bild und Gain-Map aus einer Rechnung; EXIF-Orientierung

Umsetzung: `Geometrie.kt` rechnet eine Matrix Quelle → Ausgabe (Vierteldrehungen, Spiegeln in
der gedrehten Ansicht, Geraderichten mit Zoom ohne leere Ecken, Zuschnitt). Das Bild bekommt sie
als Shader-Matrix auf der GPU, die Gain-Map dieselbe in ihrer eigenen Auflösung auf der CPU,
ihre HDR-Kennwerte bleiben. JVM-Tests prüfen Ecken, Drehsinn, Spiegeln, Zuschnitt und dass
Geraderichten keine leeren Ecken lässt.

Befund: `BitmapFactory` richtet nicht nach EXIF auf — anders als Flutters Dekoder, auf den sich
M1 verließ. Seit dem nativen Renderer (M2/1) wären hochkant gespeicherte, per EXIF gedrehte Fotos
quer herausgekommen, weil die Kopie Orientierung 1 trägt. Jetzt ist die EXIF-Orientierung die
Grund-Geometrie (`nachExif`), die Einstellungen des Nutzers kommen darauf.

Wie geprüft, im Emulator: das Testfoto A mit EXIF-Orientierung 6 (Pixel samt Gain-Map
unverändert) erscheint richtig gedreht; dazu eine Vierteldrehung, 4:3 und etwa 13°
Geraderichten, gespeichert: „Gespeichert und geprüft", 3072×2304, EXIF-Orientierung 1, vorn im
Stapel. Gain-Map der Kopie 697×523 (Seitenverhältnis 1,3327 zu 1,3333 des Bildes),
`gainmap-max-content-boost` 4,653 (libvips). Passt sie zum Bild? Korrelation Helligkeit ↔
Gain-Map, je auf 96×96: Original 0,745; Kopie **0,633**; Gegenprobe Gain-Map um 180° gedreht
−0,033, gespiegelt −0,071.

**Anwenden:** Jede neue Geometrie-Funktion (Perspektive, M2/M3) kommt in `Geometrie.kt` und wirkt
damit auf beide.

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
