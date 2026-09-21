# Editor for Immich

An open-source mobile photo library and editor for Immich.

> **Unofficial.** This project is not affiliated with, endorsed by, or connected to Immich
> or FUTO. "Immich" is a trademark of FUTO.

## Status

Planning. Nothing is built yet. The design lives in [`specs/`](specs/).

## Idea

[Immich](https://immich.app) is an excellent self-hosted photo library, but its editor only
crops, rotates and mirrors. This app adds the missing editing — the everyday tools of a phone
gallery editor, computed on the device — without touching the Immich server:

- Works on photos that are **only on the phone** and on photos that are **only on the server**.
- Edits are **non-destructive**: the app uploads an edited copy, stacks it in front of the
  original, and keeps the edit recipe inside the copy (XMP), so it can be re-edited later.
- No server fork, no database changes. Remove the app and you keep ordinary photos.

## License

[AGPL-3.0](LICENSE), like Immich itself.
