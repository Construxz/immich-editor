# Entscheidungen und Befunde

Eine Entscheidung oder ein Befund je Eintrag, mit Datum, Begründung und — bei Befunden — wie
gemessen wurde. **Neue Einträge oben anfügen.** Was noch zu tun ist, steht in
[ROADMAP.md](ROADMAP.md), was jetzt gilt in [STATUS.md](STATUS.md), das Konzept in
[specs/0001-editor.md](../specs/0001-editor.md).

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
