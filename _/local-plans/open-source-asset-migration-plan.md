# PIXEL PILFERER: REBOUND — OPEN-SOURCE ASSET MIGRATION & LICENSING AUDIT PLAN

## Objective
Execute the Mandatory Open-Source Asset-First Development Contract for *Pixel Pilferer: Rebound* to replace all placeholder/generated assets with verified, human-created, openly licensed (CC0 1.0 / CC BY) assets across Characters, Environments (4 worlds), Gameplay mechanics (Reality Snapback spring, sockets, shards), UI, and Audio, ensuring zero generative AI usage, 100% legal compliance, automated audit verification, and a fully functional showcase level.

---

## Phase Breakdown

### Step 1: Create Workspace Skill `.agents/skills/open-asset-license-audit/SKILL.md`
- Adhere to `agy-customizations` specification.
- Detail audit procedures: license verification, AI-free provenance checks, SHA-256 hashing, manifest synchronization, and attribution enforcement.

### Step 2: Open-Source Asset Research & Sourcing
- Research reputable human-created CC0 and CC BY asset collections:
  - **Character & World 1-4 Tilesets:** Kenney (Kenney Pixel Platformer / 1-Bit / Scribble / Roguelike), Buch (OpenGameArt CC0 16x16 tiles), 0x72, or GrafxKid (CC0).
    - Specifically, Kenney's **Pixel Platformer** (CC0) provides 18x18 / 16x16 characters (including idle, walk/run, jump), tilesets for dirt/grass, industrial/mechanical, caverns, and gems/locks/keys/springs!
    - Kenney's **1-Bit Platformer Pack** (CC0) and **Tiny Dungeon / Town / Ski** (CC0).
    - Audio: Kenney's **Impact Sounds**, **Digital Audio**, **RPG Sounds**, and Juhani Junkala / SubspaceAudio retro chip music & SFX (all human-composed CC0).
- Download / unpack clean human-authored assets directly into structured directories:
  - `assets/characters/`
  - `assets/tilesets/`
  - `assets/backgrounds/`
  - `assets/gameplay/`
  - `assets/ui/`
  - `assets/audio/sfx/`
  - `assets/audio/music/`
  - `assets/fonts/`
  - `assets/licenses/`

### Step 3: Licenses & Provenance Documentation
- Create `assets/licenses/CC0-1.0.txt`, `assets/licenses/CC-BY-4.0.txt`, etc.
- Create `docs/ASSET_MANIFEST.md` with:
  - Asset Name, Author, Source URL, License, Attribution required/text, Local file path, In-game use, SHA-256 checksum, Status (APPROVED).
- Create `docs/ASSET_SELECTION_REPORT.md`:
  - Detailed justification of chosen asset packs, visual consistency, color palette coherence, animation frame analysis, audio mixing rationale, and strict verification that zero generative AI was employed.
- Create / Update `CREDITS.md`:
  - Full attribution for all authors in accordance with CC BY / CC0 requirements.

### Step 4: Automated Asset & License Audit Tooling
- Implement `tests/test_asset_audit.py` (and/or GDScript `scripts/test/test_asset_audit.gd`):
  - Recurses through `assets/`.
  - Verifies every asset file is cataloged in `docs/ASSET_MANIFEST.md`.
  - Checks SHA-256 checksums match.
  - Verifies all licenses are permitted (CC0 1.0, Public Domain, CC BY 4.0, MIT).
  - Asserts that no unapproved / unverified files exist in `assets/`.
  - Checks `CREDITS.md` contains attribution for any CC BY assets.

### Step 5: Update Game Scenes & Integration
- Update UI credits modal (`scenes/ui/credits_modal.tscn` and `scripts/ui/credits_modal.gd` or main menu credits) to display all licensed asset attributions.
- Build `scenes/platformer/levels/rebound_showcase_level.tscn` integrating:
  - Verified 16x16 open tilesets for terrain and obstacles.
  - Pip character sprite/animations using the verified open spritesheet.
  - Rebound spring pad, GhostFrame2D, ChromaticSocket, CollectibleShard, Checkpoint, and Exit Door.
  - Integrated open SFX and BGM.
- Implement automated test `scripts/test/test_showcase_level.gd` to headless-verify the showcase level end-to-end.

### Step 6: Full Verification & Commit
- Run automated audit script (`test_asset_audit.py`).
- Run showcase level test and complete test suite regression (`run_tests.py` + platformer test suite).
- Commit all changes locally on `main` with detailed commit message.
