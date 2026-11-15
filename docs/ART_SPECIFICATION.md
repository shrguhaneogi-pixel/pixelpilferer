# Pixel Pilferer — Art, Animation, and Audio Specification

## 1. Executive Summary & Aesthetic Pillar

- **Game Title:** PIXEL PILFERER
- **Visual Style:** High-clarity retro-modern 2D pixel art. Crisp contours, saturated jewel-tone chromatic elements, deep midnight slate backdrops, and mechanical sci-fi archaeology motifs.
- **Rendering Resolution:** 640x360 native canvas (16:9 aspect ratio).
- **Pixel Grid:** Strictly 16x16 integer pixel tiles with nearest-neighbor texture filtering and integer viewport scaling. Subpixel transforms, bilinear filtering, and float jitter are strictly prohibited.
- **Target Platform Compatibility:** Godot 4.7.2 stable (`gl_compatibility` renderer, Web single-thread, Windows Desktop).

---

## 2. Palette Architecture & Color Values

The palette leverages a dark midnight/obsidian baseline so that interactive puzzle elements (Pip's glove, chromatic blocks, active energy sockets, open portal vortex) command immediate visual hierarchy.

### A. Environment & Structural Baseline
| Token | Hex | RGB | Usage |
| :--- | :---: | :---: | :--- |
| `P_BLACK` | `#080811` | `(8, 8, 17)` | Outlines, deepest tile seams, drop shadows |
| `P_MIDNIGHT` | `#0f0d24` | `(15, 13, 36)` | UI panels, backdrop clears |
| `P_DEEP_BLUE` | `#181435` | `(24, 20, 53)` | Secondary shadows, inner sockets |
| `P_FLOOR_BASE` | `#14122a` | `(20, 18, 42)` | Traversable floor tile body |
| `P_FLOOR_ACC` | `#1c193a` | `(28, 25, 58)` | Floor tile bevels and corner rivets |
| `P_WALL_DARK` | `#1e1a3c` | `(30, 26, 60)` | Solid wall masonry base |
| `P_WALL_LIGHT`| `#41376e` | `(65, 55, 110)` | Wall top highlights and brick seams |
| `P_VOID` | `#04040a` | `(4, 4, 10)` | Impassable void chasm |
| `P_VOID_STAR` | `#322d5a` | `(50, 45, 90)` | Subtle cosmic stardust in void |

### B. Chromatic Fragments & Sockets
Every chromatic fragment pairs a unique hue with a distinct interior rune silhouette to guarantee 100% colorblind accessibility and instantaneous shape recognition:

| Color | Hex (Mid / Hi / Shadow) | Geometric Rune | Invariant Rule |
| :--- | :---: | :---: | :--- |
| **Neutral** | `#b4b9c8` / `#dce1f0` / `#6e7382` | **Diamond** (`◆`) | Fits neutral sockets (`S`) or bridges voids |
| **Cyan** | `#00e5ff` / `#b4faff` / `#008cb4` | **Triangle** (`▲`) | Activates cyan socket (`1`) |
| **Amber** | `#ffb703` / `#ffe682` / `#be6e00` | **Square** (`■`) | Activates amber socket (`2`) |
| **Magenta** | `#ff007f` / `#ff96c8` / `#b40050` | **Circle** (`●`) | Activates magenta socket (`3`) |
| **Emerald** | `#06d6a0` / `#a0ffdc` / `#008c64` | **Cross** (`✚`) | Activates emerald socket (`4`) |

---

## 3. Chapter Environmental Motifs

Each chapter features environmental styling tailored to its pedagogical narrative without altering tile geometry:

1. **Chapter 0 (Tutorial & Demo): Neon Night**
   - Palette: Midnight blue, cool stone, electric cyan street markers.
   - Narrative: Training proving grounds for glove synchronization.
2. **Chapter 1: The Stolen Street**
   - Palette: Muted weathered stone (`#1e1a3c`), warm amber streetlights (`#ffb703`), soft cyan conduits.
   - Narrative: Derelict mechanical avenues where fragments block ancient alleyways.
3. **Chapter 2: The Broken Bridges**
   - Palette: Deep oceanic navy (`#0f172a`), turquoise skyway guide rails (`#06b6d4`), ethereal void stardust.
   - Narrative: Fractured causeways above the bottomless expanse.
4. **Chapter 3: The Forgotten Vault**
   - Palette: Obsidian violet (`#2e1065`), metallic slate (`#475569`), glowing amber conduit circuits.
   - Narrative: Subterranean vaults guarded by sleeping neutral power sockets.
5. **Chapter 4: The Chromatic Core**
   - Palette: Full spectrum brilliance. Rich gold, radiant cyan, vivid magenta, emerald energy streams.
   - Narrative: The central engine of the world restored to full luminance.

---

## 4. Character Design: Pip & The Pixel Glove

### Silhouette & Visual Hierarchy
- **Dimensions:** 16x16 base sprite, centered on cell.
- **Hood & Cloak:** Heavy indigo cloak (`#231e46`) with layered hood (`#322a5f`).
- **Face:** Completely shrouded in deep shadow (`#0c0a16`) with an expressive glowing horizontal visor slit (`#00e5ff`).
- **Pixel Glove:** Right gauntlet charged with cyan plasma emitter (`#00e5ff`) with white core highlight (`#ffffff`).
- **States & Animations:**
  - **Idle:** Subtle 1.2-second vertical sine bobbing ($\pm 1$ pixel) when stationary.
  - **Facing (4 Directions):** Frame 0 (South), Frame 1 (East), Frame 2 (North), Frame 3 (West).
  - **Carrying:** Fragment floats cleanly above Pip's head ($y = -12\text{px}$) with gentle levitation pulse.
  - **Steal:** Glove snaps forward; 8 particles converge inward; carried block pops in with `TRANS_BACK`.
  - **Place:** Carried fragment drops into glove; block materializes with bouncy cell landing and dust burst.
  - **Invalid Bump:** Rapid 80ms directional bump recoil against wall/block.
  - **Victory:** Joyful 2-frame upward hop when entering open exit vortex.

---

## 5. Tile & Entity Graphic Specifications

| Object | Dimensions | Frame Count | Visual Characteristics |
| :--- | :---: | :---: | :--- |
| **Floor** | 16x16 | 1 | Dark stone pavers with subtle corner rivets and mortar seams. |
| **Wall** | 16x16 | 1 | Heavy dual-layer masonry bricks with illuminated top bevel edge. |
| **Void** | 16x16 | 1 | Abyssal darkness with distant sparkling micro-stars. |
| **Bridge** | 16x16 | 1 | Solid reinforced planks framed by cyan safety guide rails. |
| **Blocks** | 16x16 | 5 (by color) | 3D beveled cubes with metallic rim, inner face, and tactile geometric runes. |
| **Sockets** | 16x16 | 10 (5 colors x 2 states) | Inactive: Recessed circular metallic cup with unlit colored guide notch.<br>Active: Radiant circular conduit flooded with core white plasma. |
| **Exit Portal** | 16x16 | 2 states | Locked: Stone archway with barred doorway and padlock sigil.<br>Open: Radiant swirling cyan vortex with concentric energy rings. |

---

## 6. Procedural Audio Synthesis Architecture

All sound effects and ambient tracks are synthesized procedurally via Python standard library (`wave`, `struct`, `math`), producing 16-bit 44.1kHz linear PCM WAV files.

### Sound Effects Catalog
1. `sfx_step.wav` (0.04s): Soft micro-tap with rapid decay; keeps rapid movement unobtrusive.
2. `sfx_steal.wav` (0.14s): Quadratic upward frequency sweep (300Hz to 1900Hz) with crisp glove snap.
3. `sfx_place.wav` (0.12s): Resonant mechanical bass thud (240Hz down to 60Hz) with sharp latch click.
4. `sfx_bump.wav` (0.08s): Low square-wave buzz (100Hz) indicating blocked action or invalid boundary.
5. `sfx_undo.wav` (0.12s): Fast flutter down-chirp (1400Hz to 400Hz) communicating loss-free rewind.
6. `sfx_socket.wav` (0.35s): Radiant C-Major arpeggio triad (C5, E5, G5, C6) with lingering harmonic tail.
7. `sfx_exit_open.wav` (0.45s): Low rising resonant drone culminating in an open portal hum.
8. `sfx_win.wav` (0.65s): Triumphant 5-note melodic fanfare (C5, E5, G5, B5, C6).
9. `sfx_ui_click.wav` (0.04s): Crisp 800Hz menu blip for tactile button responses.
10. `sfx_chapter_restored.wav` (1.00s): Majestic 7-note restoration chord sequence for chapter completions.
11. `music_ambient.wav` (12.0s): Loopable retro synth ambient soundscape with soft sine-wave arpeggio pads.

---

## 7. Accessibility & Motion Standards

1. **Reduced Motion Mode:**
   - Immediately bypasses all tween interpolations (snaps player and blocks to cells instantly).
   - Disables particle generation (`CPUParticles2D.emitting = false`).
   - Disables idle breathing and carried-block levitation bobbing.
   - Eliminates all camera screen shake.
2. **Audio Balancing:**
   - Independent sliders for Master, SFX, and Music.
   - Linear-to-decibel conversion with safe clamping preventing audio clipping (`db = linear_to_db(clamp(vol, 0.0001, 1.0))`).
   - Full mute capability for discrete play.
3. **High-Contrast Readability:**
   - High-contrast geometric runes on blocks ensure color is never the sole differentiating factor.
   - Clear visual differentiation between traversable bridges and impassable voids.
