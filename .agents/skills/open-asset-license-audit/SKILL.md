---
name: open-asset-license-audit
description: >-
  Comprehensive methodology and automated audit procedures for verifying, sourcing,
  cataloging, and attributing human-created open-source game assets (CC0, CC BY 4.0, MIT)
  in Godot 4.7 projects. Enforces strict zero-AI asset compliance, SHA-256 checksum tracking,
  licensing compatibility, and in-game attribution standards.
---

# Open-Source Asset & License Audit Skill

This skill governs the legal validation, acquisition, cataloging, integration, and continuous compliance testing of all external media assets (sprites, tilesets, backgrounds, fonts, SFX, music) used in **Pixel Pilferer: Rebound**.

---

## 1. Absolute Zero-AI Asset Mandate

Under the project development contract, **NO generative AI assets** may be utilized in the project.

### Forbidden Categories for AI Generation:
- Character sprites, animations, and portraits.
- Environment tilesets, autotiles, and backgrounds.
- Gameplay objects, mechanics sprites, and particle spritesheets.
- User interface icons, dialog boxes, and font glyphs.
- Audio sound effects, ambient loops, and musical tracks.
- Voice clips or vocal samples.

### Verification Criteria for Human-Authored Provenance:
1. **Established Human Author:** Assets must originate from known, established digital artists or sound designers (e.g., Kenney Vleugels, Buch, 0x72, GrafxKid, Juhani Junkala, SubspaceAudio).
2. **Repository/Store Provenance:** Sourced from reputable open asset repositories (Kenney.nl, OpenGameArt.org, itch.io) with verifiable publication timestamps, human author bios, and explicit open-source license declarations.
3. **Absence of AI Disclaimers:** Any asset containing tags or mentions of "AI-generated", "Midjourney", "Stable Diffusion", "DALL-E", "Suno", "Udio", or similar generative tools must be **immediately rejected**.
4. **Authentic Source Structure:** Assets should feature authentic human workflow artifacts (e.g., layered files, cleanly authored sprite grids, modular palettes, manual WAV synthesis/tracker origins).

---

## 2. Licensing Hierarchy & Compatibility Matrix

Every incoming asset must fall within approved open-source categories:

| License | Status | Requirements & Restrictions |
| :--- | :--- | :--- |
| **CC0 1.0 Universal** | **PREFERRED** | Public domain dedication. Attribution not legally required, but maintained in `docs/ASSET_MANIFEST.md` and `CREDITS.md` for ethical transparency. |
| **Public Domain** | **APPROVED** | Verified public domain dedication (US / International). |
| **CC BY 4.0 / CC BY 3.0** | **APPROVED** | Creative Commons Attribution. Requires clear, unedited copyright notice, author name, license link, and statement of changes in `CREDITS.md` and in-game UI. |
| **MIT / BSD-style** | **APPROVED** | Standard software/asset permissive license. Requires license text preservation in `assets/licenses/`. |
| **CC BY-SA 4.0 / 3.0** | **RESTRICTED** | Requires Share-Alike copyleft review. Reject if it creates virality risks for game source code. |
| **CC BY-NC / NC-SA** | **FORBIDDEN** | Non-Commercial clauses violate commercial release readiness. Immediate rejection. |
| **CC BY-ND** | **FORBIDDEN** | No-Derivatives clauses prevent resizing, palletizing, or adapting to Godot. Immediate rejection. |
| **All Rights Reserved** | **FORBIDDEN** | Commercial game rips, proprietary textures, unlicensed audio. Immediate rejection. |

---

## 3. Directory Layout & Organization

All approved assets must be placed within designated subdirectories under `assets/`:

```
assets/
├── characters/        # Character spritesheets, player poses, walk/jump cycles
├── tilesets/          # 16x16 environment tiles, platforms, walls, decorations
├── backgrounds/       # Parallax layers, skyboxes, backdrop textures
├── gameplay/          # Mechanics objects: springs, sockets, shards, doors, checkpoints
├── ui/                # UI frames, buttons, hearts, icons, hud elements
├── audio/
│   ├── sfx/           # Discrete WAV sound effects (jump, bounce, land, click)
│   └── music/         # OGG/WAV loopable background music tracks
├── fonts/             # TTF/OTF/BMFont licensed typography
└── licenses/          # Unmodified text copies of legal licenses (CC0-1.0.txt, CC-BY-4.0.txt)
```

---

## 4. Documentation Standards

### A. Asset Manifest (`docs/ASSET_MANIFEST.md`)
Every single file present in `assets/` must have an exact matching entry in the Asset Manifest table with:
- **Asset Identifier / Name**: Descriptive name of the asset.
- **Category**: Characters, Tilesets, Backgrounds, Gameplay, UI, Audio-SFX, Audio-Music, Fonts.
- **Author / Creator**: Real or official creator name.
- **Original Source URL**: Direct link to the repository/asset page.
- **License**: Exact license name (e.g., CC0 1.0, CC BY 4.0).
- **Attribution Required**: Yes / No (and required attribution string).
- **Local File Path**: Canonical path relative to project root.
- **SHA-256 Checksum**: 64-character hexadecimal SHA-256 hash computed on the clean file.
- **Status**: `APPROVED` | `REJECTED` | `PENDING`.

### B. Asset Selection Report (`docs/ASSET_SELECTION_REPORT.md`)
A formal review document detailing:
1. Executive Summary & Selection Gate decisions.
2. Character choice & animation capability review.
3. Environmental tileset cohesion across 4 game worlds.
4. Color palette compatibility and visual consistency.
5. Sound effects and music score selection rationale.
6. Provenance and anti-AI verification audit results.

### C. Project Credits (`CREDITS.md`)
Formal public-facing credits providing full legal attribution for every creator whose assets appear in the game.

---

## 5. Automated Audit Workflow

Run the automated asset audit tool to verify compliance:

```bash
python tests/test_asset_audit.py
```

### Checks Performed by Audit:
1. **File Inventory Verification:** Scans `assets/` recursively; flags any file not explicitly registered in `docs/ASSET_MANIFEST.md`.
2. **SHA-256 Integrity Verification:** Computes SHA-256 for each disk asset and verifies equality against `docs/ASSET_MANIFEST.md`.
3. **License Whitelist Verification:** Rejects any asset whose license is not in the approved whitelist (`CC0 1.0`, `CC BY 4.0`, `CC BY 3.0`, `MIT`, `Public Domain`).
4. **Approval Status Verification:** Confirms all files have status `APPROVED`.
5. **Attribution Cross-Check:** Ensures every asset requiring attribution (`CC BY`) has its creator credited in `CREDITS.md`.
6. **No Stale Import Files:** Confirms `.import` files belong to valid, manifest-tracked source files.
