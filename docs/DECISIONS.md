# Entscheidungen und Befunde

Eine Entscheidung oder ein Befund je Eintrag, mit Datum, Begründung und — bei Befunden — wie
gemessen wurde. **Neue Einträge oben anfügen.** Was noch zu tun ist, steht in
[ROADMAP.md](ROADMAP.md), was jetzt gilt in [STATUS.md](STATUS.md), das Konzept in
[specs/0001-editor.md](../specs/0001-editor.md).

---

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
