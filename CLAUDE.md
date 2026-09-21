# Arbeitsanweisung für Agenten

**Editor for Immich** — eine eigenständige Flutter-App (Android + iOS), die über die Immich-API
Fotos bearbeitet: lokal und auf dem Server, nicht-destruktiv. Das Konzept steht in
[specs/0001-editor.md](specs/0001-editor.md), die Begründungen in
[docs/DECISIONS.md](docs/DECISIONS.md). Vor jeder Arbeit **STATUS, ROADMAP und die Spec lesen.**

## Unverrückbar

- **Immich wird nicht verändert.** Kein Server-Fork, keine Schemaänderung, kein Eingriff in
  Backup oder Bildverwaltung. Die App schreibt nur neue Assets und Stapel über die öffentliche
  API (D-1, D-2).
- **Getestet wird ausschließlich mit einem eigenen Immich-Testbenutzer**, nie mit der echten
  Bibliothek des Besitzers. Zugangsdaten nur in einer lokalen `.env` (ist in `.gitignore`).
- **Keine Google-Play-Dienste, kein Firebase, kein Cloud-Dienst** für Bildverarbeitung (D-6).
- **Lizenz AGPL-3.0** (D-3). Vor jeder neuen Abhängigkeit die Lizenz nachsehen und in
  [docs/LICENSES.md](docs/LICENSES.md) eintragen — zuerst nach Copyleft und nach
  nicht-kommerziellen Modellgewichten fragen.
- **Geheimnisse nie ins Git:** Signierschlüssel, `key.properties`, `.env`. Ein Geheimnis, das
  einmal committet war, bekommt man nicht wieder heraus — dann rotieren, nicht löschen.
- **Immich-Typen verlassen `server/` nicht**; Galerie und Editor arbeiten mit eigenen Modellen.

## Arbeitsweise

- In Meilensteinen aus [docs/ROADMAP.md](docs/ROADMAP.md), in ihrer Reihenfolge. Ein Meilenstein
  ist fertig, wenn seine Abnahme nachweislich erfüllt ist — gemessen, nicht angenommen.
- Das kleinste, das die Abnahme erfüllt. Keine Abstraktion auf Vorrat.
- Nicht-triviale Logik (Rezept-Format, XMP, Stapeln, Prüfsummen) bekommt einen Test.
- **Doku nach der Rollenteilung** in der README (*Documentation*): jede Aussage hat genau einen
  Besitzer. Erledigtes verlässt die ROADMAP, das Ergebnis geht mit Datum und Messweg in
  DECISIONS, der Ist-Stand wird in STATUS überschrieben. Danach `python doccheck.py`.
- Doku-Sprache Deutsch (E3 offen), README englisch.
- **Commits:** Dateien einzeln benennen, nie `git add -A`; die Nachricht sagt, was jetzt anders
  ist. Pushen auf `origin` (privat) ist erlaubt; Tags und Releases nur nach Rückfrage.

## Umgebung

- Windows, Projekt unter `<Projektordner>`. Shells: PowerShell und Git Bash.
- Remote: `https://github.com/Construxz/immich-editor.git` (privat bis zum ersten Release, D-4).
- Werkzeuge: siehe README, *Development*. Installationen, die Administratorrechte, Käufe oder
  Konten brauchen, übernimmt der Besitzer — vorher fragen, nicht selbst anstoßen.
