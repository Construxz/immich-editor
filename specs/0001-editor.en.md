# 0001 — Editor for Immich: Scope and Structure

*English translation of [0001-editor.md](0001-editor.md) (German). If they differ, the German file is authoritative.*

**As of 2026-09-21.** The concept of the app. Decisions and their reasoning are in
[DECISIONS.en.md](../docs/DECISIONS.en.md) ([German](../docs/DECISIONS.md)), milestones in
[ROADMAP.en.md](../docs/ROADMAP.en.md) ([German](../docs/ROADMAP.md)),
licenses in [LICENSES.en.md](../docs/LICENSES.en.md).

## Goals

1. **Scope and handling like the editor in Google Photos** — simple, no Snapseed, no
   Lightroom.
2. **Plus what Google lacks:** local adjustments with masks (no layers) and custom presets
   that can be applied to many images at once.
3. **Everything that can be is computed on the device**, without a cloud service (D-6).
4. **A standalone Flutter app** for Android (not iOS, D-14), with its own gallery over local photos
   **and** the Immich server; editing without a detour via sharing, multi-select included (D-1).
5. **Immich stays unchanged** — no server fork, no schema change, no interference with
   backup or photo management.

| | Immich app | Editor for Immich | Immich server |
|---|---|---|---|
| Role | Library and backup | Selecting, editing, presets | Storage and display |
| sees | all photos | local photos and server assets via the API | original, copy, stack |
| writes | backups | edited copies and stacks via the API | — |

## Storage path

Why this path and not Immich's own `asset_edit`: D-2.

1. **The app renders the finished image on the device** and creates it as a **new asset**.
2. **The recipe travels inside the image** — as XMP in its own namespace, the way Lightroom
   (`crs:`) and darktable write their development settings: all settings and the
   checksum of the original. Immich does not modify uploaded files.
3. **Copy and original are stacked**, the copy in front (`POST /api/stacks`). Immich's
   timeline shows the edit, the original sits in the stack.
4. **The copy inherits capture time, location and albums** of the original, so that it sits in the
   same place in timeline, map and albums.
5. **Editing again:** load the original, read the recipe from the copy, keep editing, add the new
   copy to the stack, move the old copy to the trash (reversible there).

**Photos that exist only on the device:** The app writes the copy (with recipe XMP) to the
device gallery; the Immich app backs up both like any other photo. They are stacked as soon as both
are on the server — the checksum in the XMP matches them up. Until then both sit briefly
side by side.

**HDR:** The copy keeps the gain map of the original (Ultra HDR, D-16); tonal changes act
the same on SDR and HDR rendering, geometry (crop, rotate, perspective) acts with
the same computation on image and gain map. The preview shows HDR, like Google Photos (D-17).
The copy is **standard Ultra HDR** (`hdrgm` XMP, ISO 21496-1, MPF), not a custom format —
Immich shows it in HDR as soon as it renders Ultra HDR (D-19). **Can be switched off** in the settings ("HDR"): then SDR preview and copies without a gain map.

**When restacking,** Immich dissolves the original's old stack; the previous copy would
then stand loose in the timeline — which is why it goes to the trash (D-23).

**To be checked:** whether Immich hides or double-counts faces and search hits of stacked assets
that are not in front.

## Gallery

Local via `photo_manager`, server via a slim Immich client (see *Structure*).
Merged via the checksum: a device photo whose checksum the server knows is
backed up. This is the largest single item — thumbnails, scrolling through tens of thousands of images,
caching — and the prerequisite for selecting several images and giving all of them a
preset.

**Other libraries later** (such as PhotoPrism, which also has no proper editor),
long-term or through the community. No abstraction for it today, but a clean seam:
all server calls in `server/`, and **Immich types do not leave this module**; gallery and
editor work with their own `Foto` model. The XMP recipe is backend-neutral anyway.
The only open question per backend would be how original and copy are linked there.

## Handling

Layout and gestures like the edit mode of Google Photos (Android, as of 2026-09; the
maintainer showed screenshots as a template, they are not in the repo). Dark
background, the image fills the middle, all controls at the bottom.

- **Gallery, top right:** ⋮ menu with Settings (HDR on/off) and Log out.
- **Top:** Close (×), Undo and Redo, on the right the main button
  **"Save"** — the app always saves as a copy — with a ⋮ menu next to it (such as
  "Save as preset", "Reset").
- **Bottom, lowest row:** the sections as horizontally scrolling tabs, the active one highlighted as a
  pill. Order: **Presets** (at Google "Suggestions"), **Crop**,
  **Adjust**, **Filters**, later **Markup** (M3) and **Local** (M4).
- **Above it, the section's tools**, also scrolling horizontally:
  - *Adjust:* round icon buttons with labels — Brightness, Contrast,
    White point, Highlights, Shadows, Black point, Saturation, Warmth, Tint, Blue tone,
    Vignette, Sharpen. A changed slider is recognizable by its icon.
  - *Presets* and *Filters:* small preview images of the current photo with the name below.
- **A slider** replaces the tool row as soon as a tool is selected: a
  scale ruler with tick marks, zero point in the middle, the value above; double-tap resets to 0.
- **Crop:** the image with corner handles; above it aspect ratio (menu: Free,
  Original, Square, 5:4, 4:3, 3:2, 16:9 and the portrait formats), Flip, rotate 90°; below it
  an angle ruler for straightening (±45°) and "Reset".
- **Compare:** press and hold on the image shows the original.

## Features, grouped by effort

The model is the edit section of Google Photos (as of 2026-09), without its cloud AI.

**Tier 1 — pure computation.** One AGSL shader, one recipe entry. The core.

| Feature | Implementation |
|---|---|
| Crop, rotate, flip, straighten | Affine transform, free angles |
| Perspective | Four-point homography |
| Brightness, contrast, white point, black point, tone | Tone curve from a few parameters |
| Highlights, shadows | tone-dependent lifting/lowering |
| Saturation, warmth, tint | Color matrix |
| Blue tone | hue-selective saturation/lightness (HSL) |
| Vignette | radial darkening |
| Sharpening | Unsharp mask |
| Filters | 3D LUT — our own looks, not measuring others' |
| Pen, highlighter, text | Vectors in the recipe |

**Tier 2 — classic image processing.** No model, but more than a formula.

| Feature | Implementation |
|---|---|
| Pop | local contrast (large radius, low strength) |
| Denoise | Bilateral or guided filter; a model only if that is not enough |
| Best crop | Saliency map + rule of thirds |
| Skin tone | Color range around skin tones — rough without a model, good with a person mask |
| Ultra HDR | Preserve and scale the gain map |

**Tier 3 — needs a model.** Almost all of it is *one* capability: **segmentation**.
Model candidates and their licenses: [LICENSES.en.md](../docs/LICENSES.en.md).

| Feature | needs |
|---|---|
| Blur background | Person/subject mask (+ optionally depth) |
| Sky effect | Sky mask + look |
| Portrait light | Face + depth/normals |
| Eraser, retouch | Mask by tap + inpainting |
| Move | Mask + inpainting + compositing — only approximate; last |
| Unblur | Deblurring model, hard on a phone; last |

"Open in another app" returns a file without recipe and without stack — leave it out or
offer it only as "Export copy".

## Masks instead of layers

Following the pattern of Lightroom Mobile: **no layers, but local adjustments** — a mask
plus its own set of the same sliders. Mask sources: brush, linear and radial gradient,
with tier 3 "Subject", "Sky", "Person".

**Retouching has the same shape:** mask plus pixel patch instead of slider values. Two recipe kinds —
`local` (mask + sliders) and `patch` (mask + patch) —, and every AI tool is just one
more way to produce a mask.

**What is stored is the model's result, not its invocation.** Brushes and gradients are
vectors and fit small into the XMP; AI masks and patches downscaled as an embedded PNG. How
large a recipe with several patches becomes is to be measured on the first prototype.

## Presets

A preset is **a recipe without geometry and without masks** — sliders, curve, look. First stored in the
app; later stored on the server, without a schema change (such as a small file in
a dedicated album). More important than storing is **applying to many images at
once** — belongs in the first release.

## Structure

| Module | Contents | Dependency |
|---|---|---|
| `server/` | Immich client for nine endpoints; Immich types stay here | `http`; credentials in `flutter_secure_storage` |
| `gallery/` | Device photos + server assets, merged via the checksum | `photo_manager` |
| `editor/` | Recipe model and UI (Flutter); renderer for preview and export native in Android — AGSL shader, image surface as a native view in the HDR window (D-17) | none |
| `export/` | render at full resolution, encode JPEG, carry over EXIF, insert XMP and gain map | System encoder via a platform channel (D-13) |
| `stacking/` | match locally created copies to the original after backup | — |

**The endpoints** (checked against the OpenAPI specification 3.2.2): `POST /auth/login`,
`GET`, `PUT` and `DELETE /stacks/{id}` (members, primary photo, dissolve — in the viewer), `GET /map/reverse-geocode` (location of a
device photo), `POST /assets/bulk-upload-check` (what from the device is already backed up, D-36), `POST /albums`
(album "Editor for Immich"), `GET /server/storage` (storage space without quota), `GET /users/me` and `GET /users/{id}/profile-image` (profile picture as in the Immich app),
`GET /server/version`, `GET /timeline/buckets` and `GET /timeline/bucket` (gallery, with
`withStacked` — a stack counts once), `GET /assets/{id}` (details, checksum, stack),
`GET /assets/{id}/thumbnail` (also `size=preview` as the first image in the editor), `GET /assets/{id}/original` (also as a range request), `POST /assets`
(required fields `assetData`, `fileCreatedAt`, `fileModifiedAt`), `POST /search/metadata` (only
by checksum), `POST /stacks`, `DELETE /assets` (trash), `GET /albums?assetId=…`,
`PUT /albums/{id}/assets`. Handwritten instead of generated — a dozen endpoints are less code
than a client for the whole API. On login, check the server version and warn on an unknown
major version.

**Recipe format:** JSON with a version number (`v: 1`) in the XMP under its own namespace
`https://github.com/Construxz/immich-editor/ns/1.0/` (prefix `ife`): `ife:recipe` carries the JSON
(so far `{"v":1,"brightness":…,"contrast":…,"geometry":{"quarterTurns":0…3,"flip":…,"angle":−45…45,"crop":[x,y,b,h]}}`;
sliders `brightness`, `contrast`, `whitePoint`, `blackPoint`, `highlights`, `shadows`,
`saturation`, `warmth`, `tint`, `blueTones`, `vignette`, `sharpness`, `pop`, each −1 … 1 and only if
≠ 0 — the computation is in `Renderer.kt`; `filter` as `{"id":"warm@1","strength":0 … 1}`, only
if strength > 0 — the ID names a built-in look including its version, a changed look gets
a new ID (D-62); geometry only if it changes something — order: quarter turns
clockwise, flip in the rotated view, straightening with zoom without empty corners,
crop 0 … 1 in the rotated frame; all after upright orientation according to EXIF), `ife:originalSha1` the SHA-1 of the original in Base64,
as Immich keeps it as `checksum`. From the first release on a promise: later versions read older ones.

**Testing uses a dedicated Immich user**, so that test copies and test stacks do not end up in
a real library.

## Not in this app: Ken Burns

An edit belongs to the photo, a zoom or pan to the slide of a story — the same photo
can be moved differently in two stories. That belongs in a story app; it may
share the render code.
