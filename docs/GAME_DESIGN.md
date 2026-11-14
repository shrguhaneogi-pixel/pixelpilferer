# Pixel Pilferer — Game Design Document

**Title:** Pixel Pilferer  
**Tagline:** Steal the world. Rebuild your escape.  
**Genre:** 2D Top-Down Pixel-Art Puzzle Adventure  
**Target Platform:** Desktop (Windows) and Web (HTML5)  
**Engine:** Godot 4.7.2 / GDScript  

---

## 1. Core Concept & Narrative Hook

The player controls **Pip**, a diminutive hooded thief equipped with a legendary artefact: the **Pixel Glove**. Pip infiltrates geometric vaults and forgotten neon-infused districts where reality itself is made of modular grid blocks. By siphoning ("stealing") blocks from the environment, Pip dismantles barriers and reconfigures pathways to activate ancient chromatic sockets and unlock the exit portal.

There are no enemies, countdown timers, or combat mechanics. Progression is purely mental: careful spatial planning, resource conservation, and logical deductions.

---

## 2. Formal Non-Negotiable Game Rules

1. **Grid Topology:** 2D orthogonal grid. All positions and movements are discrete integer coordinates `Vector2i(x, y)`.
2. **Four-Directional Actions:**
   - Movement: `MOVE_NORTH`, `MOVE_EAST`, `MOVE_SOUTH`, `MOVE_WEST`
   - Interaction: `INTERACT_NORTH`, `INTERACT_EAST`, `INTERACT_SOUTH`, `INTERACT_WEST`
3. **Carrying Capacity:** Exactly one block. Pip cannot carry two blocks simultaneously.
4. **No Diagonal Interactions:** Picking up, placing, or moving diagonally is prohibited.
5. **Tile Types:**
   - **Floor:** Walkable by default.
   - **Void:** Impassable abyss. Can be converted into a traversable bridge by placing a movable block over it.
   - **Wall (Immutable):** Permanent solid obstacle. Cannot be stolen, walked through, or placed onto.
   - **Socket:** Special floor cell. Activates when an appropriate movable block is placed upon it.
   - **Exit Portal:** Level exit. Closed until all required sockets in the level are activated.
6. **Block Dynamics:**
   - A movable block on ordinary floor is an obstacle (blocks movement).
   - A movable block dropped into a void fills the gap, becoming a walkable bridge tile.
   - A bridge block can be stolen back out of the void, returning the cell to impassable void.
   - A block cannot be placed on the player's current cell, on an immutable wall, on an exit, or on another existing block.
7. **Color Chromatics:**
   - Blocks retain their color attribute: `NEUTRAL`, `CYAN`, `AMBER`, `MAGENTA`, `EMERALD`.
   - **Neutral Sockets:** Accept any color block.
   - **Colored Sockets:** Require an exact color match (e.g., Cyan block on Cyan socket).
8. **Win Condition:**
   - Every required socket in the level is satisfied.
   - The player reaches the active Exit cell.
9. **Determinism & Reversibility:**
   - **Undo:** Reverts the logical game state back by one step ($S_t \to S_{t-1}$).
   - **Restart:** Restores the level's exact initial state ($S_0$).
   - No stochastic elements or frame-dependent physics.

---

## 3. Campaign & Chapter Structure

The campaign comprises 4 thematic chapters with 5 handcrafted puzzles each (20 levels total):

### Chapter 1: The Stolen Street (Levels 1-1 to 1-5)
- **Theme:** Dim twilight cityscape with neon cyan trim.
- **Mechanics:** 
  - 1-1: Movement basics, stealing a neutral block from a wall indentation, clearing the corridor.
  - 1-2: Placing an obstacle to alter movement lanes, activating a first neutral socket.
  - 1-3: Simple 1-cell void bridging over an alley.
  - 1-4: The duality of blocks (first as an obstacle, then as a bridge).
  - 1-5: Multiple sockets, managing block conservation in tight quarters.

### Chapter 2: The Broken Bridges (Levels 2-1 to 2-5)
- **Theme:** Collapsed skyway arches, deep indigo void chasm.
- **Mechanics:**
  - 2-1: Stealing a bridge to strand oneself or create a bridge ahead.
  - 2-2: Leap-frogging: using one block to cross a gap, picking it up from the other side, and bridging forward.
  - 2-3: Multi-island crossings with dead-end traps.
  - 2-4: Socket on an isolated island; balancing bridging vs socket activation.
  - 2-5: The Grand Chasm: sequential bridging puzzles requiring strict forward planning.

### Chapter 3: The Forgotten Vault (Levels 3-1 to 3-5)
- **Theme:** Ancient machinery, obsidian walls, amber energy conduits.
- **Mechanics:**
  - 3-1: Introduction of Amber blocks and amber sockets.
  - 3-2: Color separation: neutral blocks vs colored blocks.
  - 3-3: Bottlenecks where misplaced blocks trap Pip permanently (until undo).
  - 3-4: Multi-socket sequences requiring careful order of operations.
  - 3-5: The Vault Lock: 3 sockets, 3 blocks, intertwining pathways.

### Chapter 4: The Chromatic Core (Levels 4-1 to 4-5)
- **Theme:** Vibrant, shifting crystalline sanctuary; deep violet and multi-spectral lighting.
- **Mechanics:**
  - 4-1: Introduction of Magenta and Emerald chromatic spectrums.
  - 4-2: Double-color matching with dual bridges.
  - 4-3: Strict color routing where a block must cross its own matching channel.
  - 4-4: Asymmetric puzzle with interdependent color locks.
  - 4-5: The Master Heist: The Core Chamber, demanding mastery of all mechanics, culminating in the restoration of the world's stolen light.

---

## 4. User Experience & Accessibility

- **Input Buffering:** 120ms buffer prevents lost key inputs during fast play.
- **Instant Response with Visual Polish:** Grid state changes instantaneously in data; visuals follow with smooth ease-out tweens.
- **Undo / Redo:** Unlimited undo history per level; quick instant rewind.
- **Hint System:** Optional hint highlighting the next strategic milestone or block interaction for stuck players.
- **Reduced Motion Setting:** Toggles off camera shakes and screen flashes; snaps movement instantly instead of tweening.
- **Colorblind Palettes:** Sockets and blocks feature unique geometric glyphs/patterns in addition to distinct hues (Neutral = Diamond, Cyan = Triangle, Amber = Square, Magenta = Circle, Emerald = Cross).
