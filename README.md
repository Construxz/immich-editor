# Editor for Immich

An open-source mobile photo library and editor for Immich.

> **Unofficial.** This project is not affiliated with, endorsed by, or connected to Immich
> or FUTO. "Immich" is a trademark of FUTO.

## Status

Planning. Nothing is built yet.

## Idea

[Immich](https://immich.app) is an excellent self-hosted photo library, but its editor only
crops, rotates and mirrors. This app adds the missing editing — the everyday tools of a phone
gallery editor, computed on the device — without touching the Immich server:

- Works on photos that are **only on the phone** and on photos that are **only on the server**.
- Edits are **non-destructive**: the app uploads an edited copy, stacks it in front of the
  original, and keeps the edit recipe inside the copy (XMP), so it can be re-edited later.
- No server fork, no database changes. Remove the app and you keep ordinary photos.

## Development

Required (planned, milestone M0):

- **Flutter SDK**, stable channel (includes Dart)
- **JDK** in the version `flutter doctor` asks for
- **Android SDK**: command-line tools, platform-tools, one platform, build-tools —
  Android Studio is optional, but the easiest way to install the SDK and an emulator
- **VS Code** with the *Flutter* and *Dart* extensions, or any Flutter-capable editor
- a **real device** with USB debugging — a real gallery beats an emulator
- iOS builds need **macOS with Xcode**

Signing keys and `.env` files never go into the repository (see `.gitignore`).

## Documentation

The project docs are in German. Every statement lives in exactly one file; the others link to it.

| File | owns | maintained by |
|---|---|---|
| [docs/STATUS.md](docs/STATUS.md) | what is true **now**: environment, repository, target API | overwriting |
| [docs/DECISIONS.md](docs/DECISIONS.md) | decisions and findings, with reasons and how they were measured | appending on top |
| [docs/ROADMAP.md](docs/ROADMAP.md) | what is **open**: milestones and open decisions, each with acceptance criteria | deleting what is done |
| [docs/LICENSES.md](docs/LICENSES.md) | register of dependencies, models and references with their licenses | adding entries |
| [specs/0001-editor.md](specs/0001-editor.md) | the concept: scope, storage path, gallery, features, structure | one spec per feature |
| [CLAUDE.md](CLAUDE.md) | working rules for coding agents: constraints, workflow, environment | editing when a rule changes |

Check the docs with `python doccheck.py` (standard library only): broken links, dead anchors,
duplicate item numbers, files without an owner entry.

## License

[AGPL-3.0](LICENSE), like Immich itself.
