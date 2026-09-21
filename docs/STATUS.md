# Zustand — was jetzt gilt

**Diese Datei wird überschrieben, nicht fortgeschrieben.** Warum etwas so ist, steht in
[DECISIONS.md](DECISIONS.md), was noch fehlt, in [ROADMAP.md](ROADMAP.md).

Stand: 21.09.2026.

## Was es gibt

- **Kein Code.** Das Projekt ist in der Planung; Konzept in
  [specs/0001-editor.md](../specs/0001-editor.md).
- Lokales Git-Repository, Zweig `main`, **kein Remote**. Geplant: privat unter `Construxz`,
  öffentlich ab dem ersten Release (D-4).
- `LICENSE` (AGPL-3.0), `README.md`, `.gitignore` für Signierschlüssel und `.env`,
  `doccheck.py`.

## Entwicklungsumgebung

Auf dem Entwicklungsrechner (Windows) ist noch **nichts** davon installiert — geprüft
21.09.2026: kein `flutter`, kein `java`, kein Android-SDK, kein `adb`. Was gebraucht wird,
steht in der README unter *Development*; das Einrichten ist Teil von M0.

## Gegen welche Immich-Version geplant wird

Die neun Endpunkte der App sind gegen `open-api/immich-openapi-specs.json` in
`immich-app/immich`, Zweig `main`, Spec-Version **3.2.0** geprüft (21.09.2026).
