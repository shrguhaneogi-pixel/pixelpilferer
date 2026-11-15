# PIXEL PILFERER — 2D PLATFORMER DESIGN SPECIFICATION

> **Tagline:** Steal the world. Rebuild your escape.  
> **Genre:** 2D Side-Scrolling Puzzle-Platformer  
> **Protagonist:** Pip, a hooded pixel thief equipped with the magical Pixel Glove.  
> **Engine:** Godot 4.7.2 Stable (GL Compatibility, Pure GDScript).

---

## 1. Architectural Overview: The Hybrid Engine

PIXEL PILFERER transforms from a discrete turn-based top-down puzzle into a **hybrid 2D puzzle-platformer**.

```
┌─────────────────────────────────────────────────────────────────┐
│                    HYBRID ARCHITECTURE                          │
├────────────────────────────────┬────────────────────────────────┤
│    Continuous Physics Layer    │   Discrete Tile Editing Layer  │
├────────────────────────────────┼────────────────────────────────┤
│ • CharacterBody2D controller   │ • Tile-aligned 16×16 grid cells│
│ • Real-time horizontal motion  │ • Pixel Glove steal & place    │
│ • Jump curves & gravity        │ • Instantaneous collision sync │
│ • Coyote time & jump buffer    │ • Anchored floating platforms  │
│ • Smooth Camera2D tracking     │ • Color-coded socket puzzles   │
└────────────────────────────────┴────────────────────────────────┘
```

The fundamental separation is:
- **Player & Physics:** Handled continuously in `_physics_process(delta: float)` using `move_and_slide()`.
- **Environment & Blocks:** Manipulated discretely on a 16×16 tile grid, where placed blocks create solid, immovable, floating physical platforms that synchronize synchronously with Godot's 2D physics server.

---

## 2. Display & Viewport Standards

| Parameter | Value | Rationale |
| :--- | :--- | :--- |
| **Viewport Dimensions** | `640 × 360` px | Standard 16:9 widescreen pixel-art base; scales cleanly to 1080p (3×) and 4K (6×). |
| **Window Override** | `1280 × 720` px | Default 2× window for crisp desktop presentation. |
| **Stretch Mode** | `viewport` | Preserves authentic pixel grid across varying monitor sizes. |
| **Stretch Scale Mode** | `integer` | Strictly prevents uneven pixel distortion and shearing. |
| **Texture Filter** | `0` (Nearest) | Razor-sharp pixel art rendering without blur. |
| **2D Pixel Snapping** | Enabled (`snap_2d_transforms_to_pixel`, `snap_2d_vertices_to_pixel`) | Eliminates subpixel shimmer during camera tracking. |
| **Logical Tile Size** | `16 × 16` px | 40 tiles wide × 22.5 tiles high visible per screen frame. |

---

## 3. Continuous Physics & Movement Specification

### 3.1 Movement Constants

```gdscript
# Horizontal Movement
const RUN_SPEED: float = 120.0        # Max horizontal speed in pixels/second
const ACCELERATION: float = 800.0     # Horizontal acceleration in pixels/second²
const FRICTION: float = 1000.0        # Horizontal deceleration when stopping
const AIR_ACCELERATION: float = 650.0 # Air control acceleration
const AIR_FRICTION: float = 400.0     # Air deceleration

# Vertical Movement & Jumping
const GRAVITY: float = 620.0          # Downward gravitational acceleration (px/s²)
const JUMP_VELOCITY: float = -225.0   # Instantaneous impulse on jump (-225 px/s)
const TERMINAL_VELOCITY: float = 340.0# Maximum downward falling velocity (px/s)
const VARIABLE_JUMP_CUTOFF: float = 0.45 # Velocity multiplier when jump key is released early

# Game Feel Timers
const COYOTE_TIME: float = 0.08       # 80ms grace period after walking off a ledge
const JUMP_BUFFER_TIME: float = 0.10  # 100ms grace period before touching down
```

### 3.2 Derived Jump Physics
- **Peak Jump Height ($H$):**
  $$H = \frac{v_{0}^2}{2g} = \frac{(-225)^2}{2 \times 620} \approx 40.8 \text{ pixels} \quad (\approx 2.55 \text{ tiles})$$
  *Design guarantee:* Pip can comfortably jump atop a 2-tile high obstacle, but cannot jump over a 3-tile high wall without placing a platform.
- **Time to Peak ($t_{peak}$):**
  $$t_{peak} = \frac{|v_0|}{g} = \frac{225}{620} \approx 0.363 \text{ seconds}$$
- **Horizontal Jump Reach ($R$ at full run speed $120\text{ px/s}$):**
  $$R = v_x \times (2 \cdot t_{peak}) = 120 \times 0.726 \approx 87.1 \text{ pixels} \quad (\approx 5.44 \text{ tiles})$$
  *Design guarantee:* A standard 4-tile gap is safely traversable at full run; a 6-tile gap is impassable without placing a bridge block.

### 3.3 State Machine & Game Feel
1. **Grounded vs. Airborne:** Evaluated via `is_on_floor()`.
2. **Coyote Time:** When `is_on_floor()` changes from `true` to `false` without jumping, a `coyote_timer` is started for `0.08s`. Pressing jump during this window executes a full jump.
3. **Jump Buffering:** Pressing jump in the air starts a `jump_buffer_timer` for `0.10s`. If Pip lands before it expires, jump triggers immediately on the landing frame.
4. **Variable Jump Height:** If the jump key is released while vertical velocity $v_y < 0$, vertical velocity is scaled by `VARIABLE_JUMP_CUTOFF` ($v_y \leftarrow v_y \times 0.45$), giving immediate control over short hops vs. full jumps.

---

## 4. The Pixel Glove & Tile Manipulation

### 4.1 Core Rules
1. **Capacity:** Pip can hold **strictly 0 or 1** fragment at any given time.
2. **Reach:** Interaction reach is $28\text{ px}$ from Pip's center ($\approx 1.75\text{ tiles}$).
3. **Aiming:**
   - Default: Horizontal facing direction ($\pm 16\text{ px}$ in $X$).
   - Aim Up (W / Up Arrow): Offsets interaction target $16\text{ px}$ upward.
   - Aim Down (S / Down Arrow): Offsets interaction target $16\text{ px}$ downward.
4. **Targeting Indicator:** A pulsating 16×16 tile bracket renders over the currently targeted grid cell.

### 4.2 Steal Action (Harvesting Blocks)
- **Preconditions:**
  - Glove hand is empty (`carried_block == null`).
  - Target cell contains an editable, movable fragment (Neutral or Chromatic).
  - Target cell is within interaction reach ($28\text{ px}$).
  - Target cell is NOT immutable terrain (bedrock/stone).
- **Execution:**
  1. Cell data (color, rune symbol) is transferred to Pip's `carried_block`.
  2. The tile is deleted from the dynamic platform layer.
  3. Physical collision shape for the tile is instantly disabled/removed.
  4. Audio: `sfx_steal.wav` plays with slight pitch variation.
  5. Particle: Deconstruction pixel burst at target cell.
- **Support Removal Edge Case:**
  If Pip stands on a movable block and aims down to steal it:
  The block is stolen, collision under Pip's feet ceases to exist, and Pip immediately begins falling under gravity on the very next physics frame.

### 4.3 Place Action (Deploying Platforms)
- **Preconditions:**
  - Glove hand is holding a fragment (`carried_block != null`).
  - Target cell is within interaction reach ($28\text{ px}$).
  - Target cell is empty air (`EMPTY` / `AIR`).
  - Target cell does NOT contain immutable terrain or another fragment.
  - **Dynamic Collision Safety:** Target cell bounds do NOT intersect Pip's `CharacterBody2D` collision rectangle.
- **Execution:**
  1. A solid, anchored tile is created in the dynamic platform layer at the integer tile coordinate.
  2. A matching 16×16 `StaticBody2D` collision shape (or synchronized `TileMapLayer` solid cell) is activated.
  3. The placed block **does not fall under gravity**; it remains locked in space as an anchored floating platform.
  4. Pip can immediately land on, jump off, or walk across the placed block.
  5. `carried_block` resets to `null`.
  6. Audio: `sfx_place.wav` plays.
  7. Particle: Materialization pixel spark.

---

## 5. Puzzle Elements: Sockets & Chromatic Runes

Sockets are recessed wall or floor fixtures that require specific fragments to activate electrical circuits, open doors, or unlock the exit portal.

| Color | Hex | Rune Symbol | Function |
| :--- | :--- | :---: | :--- |
| **Neutral** | `#D0C8B0` | `◆` | Universal building block; solid platform. |
| **Cyan** | `#3B9EFF` | `▲` | Conductive resonance; activates cyan sockets. |
| **Amber** | `#FFA32B` | `■` | Kinetic resonance; activates amber sockets. |
| **Magenta** | `#FF4297` | `●` | Quantum resonance; activates magenta sockets. |
| **Emerald** | `#2DE082` | `✚` | Biomass resonance; activates emerald sockets. |

- Sockets are visually distinct with clear rune engravings (dual-channel accessibility: color + symbol).
- Placing a matching fragment into a socket locks or links it, producing `sfx_socket.wav`.
- When all required level sockets are satisfied, the exit portal unlocks with `sfx_exit_open.wav`.

---

## 6. Camera Specification

- **Node:** `Camera2D` attached to the level or smoothing root.
- **Tracking:** Follows Pip horizontally with position smoothing enabled (`position_smoothing_speed = 6.0`).
- **Lookahead:** Shifts $24\text{ px}$ in the direction Pip is facing so the forward traversal route is always visible.
- **Vertical Deadzone:** 32 px vertical deadzone; small hops do not jerk the camera up and down.
- **Limits:** Hard level boundary limits clamped to `[0, map_width_px]` and `[0, map_height_px]`.
- **Pixel Clamping:** Position rounded to integer coordinates (`camera.position = camera.position.round()`) in `_process` to avoid subpixel blur.

---

## 7. Checkpoints, Hazards, and Restart

- **Hazards & Bottomless Pits:** Pits below the level floor or spikes trigger instantaneous death.
- **Checkpoint Architecture:**
  - Touching a Checkpoint saves:
    1. Player respawn coordinates.
    2. Complete snapshot of all movable fragment locations and colors.
    3. State of all sockets and opened doors.
    4. Carried block state.
- **On Death / Respawn:**
  - Screen fades briefly.
  - Player velocity resets to `Vector2.ZERO`.
  - Player spawns safely on the checkpoint platform.
  - Fragment positions are restored from the checkpoint snapshot.
- **Full Level Restart (R Key):**
  - Instantaneously resets the level to turn 0 (initial layout and spawn point).

---

## 8. Controls & Mapping

| Action | Primary Input | Alternative Input | Function |
| :--- | :--- | :--- | :--- |
| `move_left` | `A` | `Left Arrow` | Walk left |
| `move_right` | `D` | `Right Arrow` | Walk right |
| `jump` | `Space` | `W` / `Up Arrow` (while moving) | Jump / Variable height |
| `interact` | `E` | `J` | Steal / Place fragment |
| `aim_up` | `W` | `Up Arrow` | Aim glove upward |
| `aim_down` | `S` | `Down Arrow` | Aim glove downward |
| `restart` | `R` | - | Instant level restart |
| `pause` | `Esc` | - | Toggle pause menu |
