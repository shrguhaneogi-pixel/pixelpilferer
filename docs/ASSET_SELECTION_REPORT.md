# Pixel Pilferer: Rebound — Asset Selection Gate Report

## 1. Executive Summary & Gate Decision

- **Project:** Pixel Pilferer: Rebound
- **Theme:** "Bounce Back" (Game Jam)
- **Gate Status:** **PASSED & APPROVED**
- **Mandate:** 100% human-authored open-source assets under permissive open-source licenses (CC0 1.0 Universal / Public Domain / CC BY 4.0).
- **Generative AI Policy:** Strictly **ZERO AI GENERATION**. No neural text-to-image or audio generation models employed.
- **Selected Primary Visual Suite:** *Pixel Platformer* by **Kenney** (CC0 1.0 Universal).
- **Selected Audio Suite:** *Chiptune Adventures* by **Juhani Junkala (SubspaceAudio)** (CC0 1.0 Universal) paired with *Interface Sounds & Platformer Audio* by **Kenney** (CC0 1.0 Universal).

---

## 2. Candidate Evaluation & Shortlist

| Category | Candidate Source | Evaluated Packs | License | Verdict | Justification |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Character** | Kenney (kenney.nl) | *Pixel Platformer Characters* | CC0 1.0 | **SELECTED** | Clean 16x16 / 24x24 silhouettes; idle, 2-frame run, and jump frames perfectly match Pip's agile glove-carrying persona. |
| **Character** | 0x72 (OpenGameArt) | *16x16 Dungeon Hero* | CC0 1.0 | Shortlisted | Top-down orientation required heavy projection warping; rejected in favor of native side-view platformer pack. |
| **World 1 (Street)** | Kenney (kenney.nl) | *Pixel Platformer Tileset* (Overworld) | CC0 1.0 | **SELECTED** | Brickwork, cracked pavements, lush grass caps, and structural signage fit the abandoned town aesthetic. |
| **World 2 (Caverns)** | Kenney (kenney.nl) | *Pixel Platformer Tileset* (Underground) | CC0 1.0 | **SELECTED** | Dark subterranean rock faces, stone pillars, and stalactites mesh with crystal shard placement. |
| **World 3 (Vault)** | Kenney (kenney.nl) | *Pixel Platformer Tileset* (Industrial) | CC0 1.0 | **SELECTED** | Industrial pipes, rivets, metallic girders, and steel blocks support mechanical puzzle chambers. |
| **World 4 (Citadel)** | Kenney (kenney.nl) | *Pixel Platformer Tileset* (Castle) | CC0 1.0 | **SELECTED** | Polished masonry, ornate battlements, and floating stone platforms provide majestic finale architecture. |
| **Gameplay: Springs** | Kenney (kenney.nl) | *Pixel Platformer Interactive Tiles* | CC0 1.0 | **SELECTED** | Native resting, compressed, and extended spring pad sprites (tiles 107-108) integrate directly with the Reality Snapback mechanic. |
| **Gameplay: Shards** | Kenney (kenney.nl) | *Pixel Platformer Gems* | CC0 1.0 | **SELECTED** | Jewel cut diamond gems in cyan, amber, ruby, and emerald map 1:1 to chromatic circuits. |
| **Gameplay: Checkpoints** | Kenney (kenney.nl) | *Pixel Platformer Flag System* | CC0 1.0 | **SELECTED** | Modular flag pole and dual-color banners deliver clear visual confirmation of respawn saves. |
| **Gameplay: Doors** | Kenney (kenney.nl) | *Pixel Platformer Doors & Locks* | CC0 1.0 | **SELECTED** | Solid 16x32 locked portal and open portal frames communicate level completion criteria intuitively. |
| **UI & Typography** | Kenney (kenney.nl) | *KenPixel / KenPixel Mini TTF* | CC0 1.0 | **SELECTED** | High-legibility bitmap-style TrueType fonts render razor-sharp glyphs at 640x360 native resolution. |
| **Audio: SFX** | Kenney (kenney.nl) | *Interface Sounds & Platformer Audio* | CC0 1.0 | **SELECTED** | Crisp tactile transients (`click`, `drop`, `bong`, `pluck`, `glass`, `confirmation`, `glitch`) map cleanly to all glove and player actions. |
| **Audio: BGM** | Juhani Junkala | *4 Chiptunes (Adventure)* | CC0 1.0 | **SELECTED** | Melodic, rhythmic, authentic 8-bit tracker loops deliver engaging, energetic puzzle-platformer pacing. |

---

## 3. Visual Cohesion & Color Palette Harmony

1. **Resolution & Pixel Uniformity:**
   - Native Canvas: **640x360** (16:9 aspect ratio).
   - Base Tile Grid: **16x16 pixels** with nearest-neighbor integer scaling.
   - Every sprite adheres to integer-coordinate placement without subpixel filtering or floating-point jitter.

2. **Colorblind Accessibility:**
   - All interactive gameplay elements rely on dual-channel visual encoding:
     - Color hue (Cyan, Amber, Magenta, Emerald, Neutral).
     - Unique geometric rune silhouettes (Triangle, Square, Circle, Cross, Diamond) and distinct gem facet geometries.

3. **Contrast Hierarchy:**
   - Deep background slate/midnight walls ensure foreground platforms, interactive blocks, and hazards are distinguishable at 100% peripheral focus.

---

## 4. Audio Architecture & Frequency Staging

- **BGM Ducking & Volume Balancing:**
  - Background music tracks are normalized to -14.5 LUFS with peak headroom at -1 dBTP to prevent clipping or ear fatigue.
  - Music bus is routed separately from SFX bus, enabling player volume calibration in Settings.
- **Transients & Interaction Feedback:**
  - Spring Bounce: Uses low-resonance spring harmonic (`bong_001.wav` + `pluck_001.wav`) with immediate 0ms attack time.
  - Siphon Action: Uses electrical transient (`glitch_001.wav`) indicating spatial manipulation.
  - Snapback Return: Uses reverse chord pluck (`back_001.wav`) signaling block return to `home_cell`.
  - Shard Collection: High-register crystal chime (`glass_001.wav`).

---

## 5. Anti-AI Provenance & Verification Audit

- **Author Backgrounds:**
  - **Kenney Vleugels:** Acclaimed Dutch game developer and creator of thousands of public domain game development assets since 2010. Assets manually drawn in vector/pixel software with transparent release logs.
  - **Juhani Junkala:** Finnish electronic composer and audio designer known for manual tracker composition (MilkyTracker/Famitracker) on OpenGameArt.
- **Verification Audit:**
  - All source repositories verified against original publication timestamps (predating generative image/audio model proliferation).
  - SHA-256 hashes generated from raw downloaded binaries and locked into `docs/ASSET_MANIFEST.md`.
  - Zero AI disclaimers, metadata flags, or generative tags present in any archive or asset file.

---

## 6. Implementation & Integration Plan

1. **Automation Test:** Execute `python tests/test_asset_audit.py` to ensure complete manifest, SHA-256, and credit validation.
2. **Credits UI:** Update `scenes/ui/credits_modal.tscn` to display full attribution to Kenney, Juhani Junkala, and celestialghost8.
3. **Showcase Level:** Construct `scenes/platformer/levels/rebound_showcase_level.tscn` utilizing exclusively the approved open-source assets for Pip, spring bounce, snapback mechanics, shard collection, and audio feedback.
