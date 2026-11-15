"""
Pixel Pilferer — Procedural Retro Pixel-Art PNG and 16-bit WAV Audio Asset Generator
Zero external dependencies (uses standard python: struct, zlib, wave, math).
Generates 16x16 crisp pixel-art sprites, complete sound palette, and loopable ambient BGM.
"""

import os
import struct
import zlib
import math
import wave

# =========================================================================
# PALETTE DEFINITIONS (RGBA)
# =========================================================================
P_TRANSPARENT = (0, 0, 0, 0)
P_BLACK       = (8, 8, 17, 255)
P_MIDNIGHT    = (15, 13, 36, 255)
P_DEEP_BLUE   = (24, 20, 53, 255)
P_VIOLET      = (57, 38, 97, 255)
P_WALL_DARK   = (30, 26, 60, 255)
P_WALL_LIGHT  = (65, 55, 110, 255)
P_FLOOR_BASE  = (20, 18, 42, 255)
P_FLOOR_ACC   = (28, 25, 58, 255)
P_VOID        = (4, 4, 10, 255)
P_VOID_STAR   = (50, 45, 90, 255)

# Accent & Chromatic Colors
P_WHITE       = (255, 255, 255, 255)
P_NEUTRAL     = (180, 185, 200, 255)
P_NEUTRAL_HI  = (220, 225, 240, 255)
P_NEUTRAL_SH  = (110, 115, 130, 255)

P_CYAN        = (0, 229, 255, 255)
P_CYAN_HI     = (180, 250, 255, 255)
P_CYAN_SH     = (0, 140, 180, 255)

P_AMBER       = (255, 183, 3, 255)
P_AMBER_HI    = (255, 230, 130, 255)
P_AMBER_SH    = (190, 110, 0, 255)

P_MAGENTA     = (255, 0, 127, 255)
P_MAGENTA_HI  = (255, 150, 200, 255)
P_MAGENTA_SH  = (180, 0, 80, 255)

P_EMERALD     = (6, 214, 160, 255)
P_EMERALD_HI  = (160, 255, 220, 255)
P_EMERALD_SH  = (0, 140, 100, 255)

# Pip Cloak, Hood & Glove
P_PIP_CLOAK   = (35, 30, 70, 255)
P_PIP_HOOD    = (50, 42, 95, 255)
P_PIP_FACE    = (12, 10, 22, 255)
P_PIP_EYES    = (0, 229, 255, 255)
P_PIP_GLOVE   = (0, 229, 255, 255)
P_PIP_GLOVE_H = (200, 255, 255, 255)


def write_png(filepath: str, width: int, height: int, pixels: list):
    """Writes an RGBA PNG file from a 2D list of (R, G, B, A) tuples."""
    raw_bytes = bytearray()
    for row in pixels:
        raw_bytes.append(0)  # Filter type 0 (None)
        for r, g, b, a in row:
            raw_bytes.extend((r, g, b, a))

    def chunk(chunk_type: bytes, data: bytes) -> bytes:
        c = chunk_type + data
        crc = zlib.crc32(c) & 0xffffffff
        return struct.pack('>I', len(data)) + c + struct.pack('>I', crc)

    header = b'\x89PNG\r\n\x1a\n'
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    ihdr = chunk(b'IHDR', ihdr_data)
    idat = chunk(b'IDAT', zlib.compress(raw_bytes, 9))
    iend = chunk(b'IEND', b'')

    os.makedirs(os.path.dirname(os.path.abspath(filepath)), exist_ok=True)
    with open(filepath, 'wb') as f:
        f.write(header + ihdr + idat + iend)
    print(f"  [PNG] Generated {filepath} ({width}x{height})")


# =========================================================================
# SPRITE GENERATORS
# =========================================================================

def generate_pip_spritesheet(filepath: str):
    """
    Pip sprite sheet: 4 frames horizontal (16x16 each = 64x16).
    Frame 0: South (facing front)
    Frame 1: East (facing right)
    Frame 2: North (facing back)
    Frame 3: West (facing left)
    """
    w, h = 64, 16
    grid = [[P_TRANSPARENT for _ in range(w)] for _ in range(h)]

    def draw_south(ox: int):
        # Hood apex and rim
        for x in range(ox + 5, ox + 11): grid[1][x] = P_BLACK
        for x in range(ox + 4, ox + 12): grid[2][x] = P_PIP_HOOD
        for x in range(ox + 3, ox + 13):
            for y in range(3, 8): grid[y][x] = P_PIP_HOOD
        # Face shadow & glowing visor
        for x in range(ox + 5, ox + 11):
            for y in range(5, 8): grid[y][x] = P_PIP_FACE
        for x in range(ox + 6, ox + 10):
            grid[6][x] = P_PIP_EYES
        grid[6][ox + 7] = P_WHITE
        grid[6][ox + 8] = P_WHITE
        # Cloak body
        for y in range(8, 14):
            for x in range(ox + 3, ox + 13): grid[y][x] = P_PIP_CLOAK
        # Cloak seam
        for y in range(8, 14): grid[y][ox + 7] = P_BLACK
        # Pixel Glove (Right hand)
        grid[10][ox + 12] = P_PIP_GLOVE_H
        grid[11][ox + 12] = P_PIP_GLOVE
        grid[11][ox + 13] = P_PIP_GLOVE
        grid[12][ox + 12] = P_PIP_GLOVE
        # Boots
        grid[14][ox + 5] = P_BLACK; grid[14][ox + 6] = P_BLACK
        grid[14][ox + 9] = P_BLACK; grid[14][ox + 10] = P_BLACK

    def draw_east(ox: int):
        # Hood side profile
        for x in range(ox + 5, ox + 11): grid[1][x] = P_BLACK
        for x in range(ox + 4, ox + 11):
            for y in range(2, 8): grid[y][x] = P_PIP_HOOD
        # Face shadow & visor
        for y in range(5, 8):
            for x in range(ox + 8, ox + 11): grid[y][x] = P_PIP_FACE
        grid[6][ox + 9] = P_PIP_EYES
        grid[6][ox + 10] = P_WHITE
        # Body
        for y in range(8, 14):
            for x in range(ox + 4, ox + 11): grid[y][x] = P_PIP_CLOAK
        # Pixel Glove extending forward
        grid[10][ox + 11] = P_PIP_GLOVE_H
        grid[10][ox + 12] = P_PIP_GLOVE
        grid[11][ox + 11] = P_PIP_GLOVE
        # Feet
        grid[14][ox + 6] = P_BLACK; grid[14][ox + 7] = P_BLACK
        grid[14][ox + 9] = P_BLACK

    def draw_north(ox: int):
        # Hood back
        for x in range(ox + 5, ox + 11): grid[1][x] = P_BLACK
        for x in range(ox + 4, ox + 12):
            for y in range(2, 8): grid[y][x] = P_PIP_HOOD
        # Cloak back
        for y in range(8, 14):
            for x in range(ox + 3, ox + 13): grid[y][x] = P_PIP_CLOAK
        for y in range(7, 13): grid[y][ox + 7] = P_PIP_HOOD
        # Side glove rim
        grid[11][ox + 3] = P_PIP_GLOVE
        grid[11][ox + 12] = P_PIP_GLOVE
        # Boots
        grid[14][ox + 5] = P_BLACK; grid[14][ox + 6] = P_BLACK
        grid[14][ox + 9] = P_BLACK; grid[14][ox + 10] = P_BLACK

    def draw_west(ox: int):
        # Mirror of East
        for y in range(h):
            for x in range(16):
                grid[y][ox + x] = grid[y][16 + (15 - x)]

    draw_south(0)
    draw_east(16)
    draw_north(32)
    draw_west(48)
    write_png(filepath, w, h, grid)


def generate_blocks_spritesheet(filepath: str):
    """
    Blocks spritesheet: 5 frames horizontal (16x16 each = 80x16).
    0: Neutral (Diamond rune)
    1: Cyan (Triangle rune)
    2: Amber (Square rune)
    3: Magenta (Circle rune)
    4: Emerald (Cross rune)
    """
    w, h = 80, 16
    grid = [[P_TRANSPARENT for _ in range(w)] for _ in range(h)]

    colors = [
        (P_NEUTRAL, P_NEUTRAL_HI, P_NEUTRAL_SH, "diamond"),
        (P_CYAN, P_CYAN_HI, P_CYAN_SH, "triangle"),
        (P_AMBER, P_AMBER_HI, P_AMBER_SH, "square"),
        (P_MAGENTA, P_MAGENTA_HI, P_MAGENTA_SH, "circle"),
        (P_EMERALD, P_EMERALD_HI, P_EMERALD_SH, "cross")
    ]

    for idx, (col_mid, col_hi, col_sh, rune) in enumerate(colors):
        ox = idx * 16
        # Outer border
        for x in range(ox + 1, ox + 15):
            grid[1][x] = P_BLACK
            grid[14][x] = P_BLACK
        for y in range(1, 15):
            grid[y][ox + 1] = P_BLACK
            grid[y][ox + 14] = P_BLACK

        # Bevel highlight (top & left)
        for x in range(ox + 2, ox + 14):
            grid[2][x] = col_hi
            grid[3][x] = col_hi
        for y in range(2, 14):
            grid[y][ox + 2] = col_hi
            grid[y][ox + 3] = col_hi

        # Bevel shadow (bottom & right)
        for x in range(ox + 2, ox + 14):
            grid[13][x] = col_sh
            grid[12][x] = col_sh
        for y in range(2, 14):
            grid[y][ox + 13] = col_sh
            grid[y][ox + 12] = col_sh

        # Body core
        for y in range(4, 12):
            for x in range(ox + 4, ox + 12):
                grid[y][x] = col_mid

        # Inner Glyph / Rune
        cx, cy = ox + 7, 7
        if rune == "diamond":
            grid[cy-2][cx] = P_WHITE; grid[cy-2][cx+1] = P_WHITE
            grid[cy-1][cx-1] = P_WHITE; grid[cy-1][cx+2] = P_WHITE
            grid[cy][cx-2] = P_WHITE; grid[cy][cx+3] = P_WHITE
            grid[cy+1][cx-1] = P_WHITE; grid[cy+1][cx+2] = P_WHITE
            grid[cy+2][cx] = P_WHITE; grid[cy+2][cx+1] = P_WHITE
        elif rune == "triangle":
            grid[cy-2][cx] = P_WHITE; grid[cy-2][cx+1] = P_WHITE
            grid[cy-1][cx-1] = P_WHITE; grid[cy-1][cx+2] = P_WHITE
            grid[cy][cx-2] = P_WHITE; grid[cy][cx+3] = P_WHITE
            for x in range(cx-3, cx+5): grid[cy+2][x] = P_WHITE
        elif rune == "square":
            for x in range(cx-2, cx+4):
                grid[cy-2][x] = P_WHITE
                grid[cy+3][x] = P_WHITE
            for y in range(cy-2, cy+4):
                grid[y][cx-2] = P_WHITE
                grid[y][cx+3] = P_WHITE
        elif rune == "circle":
            for x in range(cx-1, cx+3):
                grid[cy-2][x] = P_WHITE
                grid[cy+3][x] = P_WHITE
            for y in range(cy-1, cy+3):
                grid[y][cx-2] = P_WHITE
                grid[y][cx+3] = P_WHITE
        elif rune == "cross":
            for y in range(cy-2, cy+4):
                grid[y][cx] = P_WHITE
                grid[y][cx+1] = P_WHITE
            for x in range(cx-2, cx+4):
                grid[cy][x] = P_WHITE
                grid[cy+1][x] = P_WHITE

    write_png(filepath, w, h, grid)


def generate_tileset(filepath: str):
    """
    Tileset: 4x1 tiles (64x16).
    0: Floor tile
    1: Wall tile (immutable masonry)
    2: Void tile (abyss with sparkling cosmic stars)
    3: Bridge tile (sturdy planks with cyan guide rails)
    """
    w, h = 64, 16
    grid = [[P_TRANSPARENT for _ in range(w)] for _ in range(h)]

    # Tile 0: Floor
    for y in range(16):
        for x in range(16):
            grid[y][x] = P_FLOOR_BASE
            if (x == 0 or y == 0 or x == 15 or y == 15) and (x + y) % 2 == 0:
                grid[y][x] = P_FLOOR_ACC
    grid[4][4] = P_FLOOR_ACC; grid[11][11] = P_FLOOR_ACC
    grid[4][11] = P_FLOOR_ACC; grid[11][4] = P_FLOOR_ACC

    # Tile 1: Wall (Immutable)
    ox = 16
    for y in range(16):
        for x in range(ox, ox + 16):
            grid[y][x] = P_WALL_DARK
    for x in range(ox + 1, ox + 15):
        grid[1][x] = P_WALL_LIGHT
        grid[8][x] = P_WALL_LIGHT
    for y in range(1, 8):
        grid[y][ox + 8] = P_WALL_LIGHT
    for y in range(8, 15):
        grid[y][ox + 4] = P_WALL_LIGHT
        grid[y][ox + 12] = P_WALL_LIGHT

    # Tile 2: Void (Abyss)
    ox = 32
    for y in range(16):
        for x in range(ox, ox + 16):
            grid[y][x] = P_VOID
    grid[3][ox + 5] = P_VOID_STAR
    grid[10][ox + 12] = P_VOID_STAR
    grid[12][ox + 3] = P_VOID_STAR
    grid[7][ox + 8] = (90, 80, 160, 255)

    # Tile 3: Bridge plank
    ox = 48
    for y in range(16):
        for x in range(ox, ox + 16):
            grid[y][x] = (40, 35, 75, 255)
    # Side rails
    for y in range(16):
        grid[y][ox] = P_CYAN_SH
        grid[y][ox + 1] = P_CYAN
        grid[y][ox + 14] = P_CYAN
        grid[y][ox + 15] = P_CYAN_SH
    # Horizontal planks
    for y in [3, 7, 11, 15]:
        for x in range(ox + 2, ox + 14):
            grid[y][x] = (65, 60, 115, 255)

    write_png(filepath, w, h, grid)


def generate_sockets_spritesheet(filepath: str):
    """
    Sockets spritesheet: 5 colors x 2 states (inactive, active) = 10 frames (160x16).
    Colors: Neutral, Cyan, Amber, Magenta, Emerald.
    """
    w, h = 160, 16
    grid = [[P_TRANSPARENT for _ in range(w)] for _ in range(h)]

    colors = [
        (P_NEUTRAL, P_NEUTRAL_HI, P_NEUTRAL_SH),
        (P_CYAN, P_CYAN_HI, P_CYAN_SH),
        (P_AMBER, P_AMBER_HI, P_AMBER_SH),
        (P_MAGENTA, P_MAGENTA_HI, P_MAGENTA_SH),
        (P_EMERALD, P_EMERALD_HI, P_EMERALD_SH)
    ]

    for c_idx, (col_mid, col_hi, col_sh) in enumerate(colors):
        # Inactive state
        ox = c_idx * 32
        for y in range(16):
            for x in range(ox, ox + 16):
                grid[y][x] = P_FLOOR_BASE
        # Socket rim
        for x in range(ox + 3, ox + 13):
            grid[3][x] = P_BLACK; grid[12][x] = P_BLACK
        for y in range(3, 13):
            grid[y][ox + 3] = P_BLACK; grid[y][ox + 12] = P_BLACK
        # Inner depression
        for y in range(4, 12):
            for x in range(ox + 4, ox + 12):
                grid[y][x] = (12, 10, 24, 255)
        # Inactive dim rune
        dim_col = (col_mid[0] // 3, col_mid[1] // 3, col_mid[2] // 3, 255)
        for y in range(6, 10):
            for x in range(ox + 6, ox + 10):
                grid[y][x] = dim_col

        # Active state (radiant full-power glow)
        ox_act = ox + 16
        for y in range(16):
            for x in range(ox_act, ox_act + 16):
                grid[y][x] = P_FLOOR_BASE
        # Outer glow
        for x in range(ox_act + 2, ox_act + 14):
            grid[2][x] = col_sh; grid[13][x] = col_sh
        for y in range(2, 14):
            grid[y][ox_act + 2] = col_sh; grid[y][ox_act + 13] = col_sh
        # Radiant energy core
        for y in range(4, 12):
            for x in range(ox_act + 4, ox_act + 12):
                grid[y][x] = col_mid
        for y in range(6, 10):
            for x in range(ox_act + 6, ox_act + 10):
                grid[y][x] = P_WHITE

    write_png(filepath, w, h, grid)


def generate_exit_portal(filepath: str):
    """
    Exit Portal: 2 frames (32x16).
    Frame 0: Locked (dark stone arch, padlock sigil)
    Frame 1: Open (radiant cyan swirling vortex portal)
    """
    w, h = 32, 16
    grid = [[P_TRANSPARENT for _ in range(w)] for _ in range(h)]

    # Locked arch (left 16x16)
    for y in range(16):
        for x in range(16):
            grid[y][x] = P_FLOOR_BASE
    # Stone pillars
    for y in range(2, 14):
        grid[y][2] = P_WALL_LIGHT; grid[y][3] = P_WALL_DARK
        grid[y][12] = P_WALL_DARK; grid[y][13] = P_WALL_LIGHT
    for x in range(2, 14):
        grid[2][x] = P_WALL_LIGHT; grid[3][x] = P_WALL_DARK
    # Dark locked core
    for y in range(4, 14):
        for x in range(4, 12):
            grid[y][x] = P_VOID
    # Padlock sigil
    grid[8][7] = (220, 60, 60, 255); grid[8][8] = (220, 60, 60, 255)
    grid[9][7] = (220, 60, 60, 255); grid[9][8] = (220, 60, 60, 255)

    # Open vortex (right 16x16)
    ox = 16
    for y in range(16):
        for x in range(ox, ox + 16):
            grid[y][x] = P_FLOOR_BASE
    # Swirling radiant portal rings
    cx, cy = ox + 7.5, 7.5
    for y in range(16):
        for x in range(ox, ox + 16):
            dist = math.hypot(x - cx, y - cy)
            if dist < 6.8:
                if dist < 2.0:
                    grid[y][x] = P_WHITE
                elif dist < 4.0:
                    grid[y][x] = P_CYAN_HI
                elif dist < 5.6:
                    grid[y][x] = P_CYAN
                else:
                    grid[y][x] = P_CYAN_SH

    write_png(filepath, w, h, grid)


def generate_app_icon(filepath: str):
    """
    App Icon (64x64):
    Midnight blue backdrop, Pip in center with glowing pixel glove.
    """
    w, h = 64, 64
    grid = [[P_MIDNIGHT for _ in range(w)] for _ in range(h)]

    # Border gradient
    for y in range(h):
        for x in range(w):
            if x in (0, 63) or y in (0, 63):
                grid[y][x] = P_BLACK
            elif x in (1, 62) or y in (1, 62):
                grid[y][x] = P_VIOLET

    # Pip Hood & Cloak (scaled up)
    for y in range(16, 48):
        for x in range(16, 44):
            if 16 <= y <= 30 and 20 <= x <= 40:
                grid[y][x] = P_PIP_HOOD
            if 24 <= y <= 28 and 24 <= x <= 38:
                grid[y][x] = P_PIP_FACE
                if 25 <= y <= 27 and 26 <= x <= 36:
                    grid[y][x] = P_CYAN
            if 31 <= y <= 48 and 18 <= x <= 42:
                grid[y][x] = P_PIP_CLOAK

    # Glowing Chromatic Cube
    for y in range(28, 44):
        for x in range(36, 52):
            if x == 36 or x == 51 or y == 28 or y == 43:
                grid[y][x] = P_WHITE
            elif x < 44 and y < 36:
                grid[y][x] = P_CYAN
            elif x >= 44 and y < 36:
                grid[y][x] = P_AMBER
            elif x < 44 and y >= 36:
                grid[y][x] = P_MAGENTA
            else:
                grid[y][x] = P_EMERALD

    write_png(filepath, w, h, grid)


# =========================================================================
# PROCEDURAL RETRO SFX GENERATORS (WAV 16-BIT 44100Hz)
# =========================================================================

def write_wav(filepath: str, samples: list, sample_rate: int = 44100):
    os.makedirs(os.path.dirname(os.path.abspath(filepath)), exist_ok=True)
    with wave.open(filepath, 'w') as wav_file:
        wav_file.setnchannels(1)      # Mono
        wav_file.setsampwidth(2)      # 16-bit
        wav_file.setframerate(sample_rate)
        packed_data = bytearray()
        for s in samples:
            val = max(-32767, min(32767, int(s * 32767)))
            packed_data.extend(struct.pack('<h', val))
        wav_file.writeframes(packed_data)
    print(f"  [WAV] Generated {filepath} ({len(samples)} samples, {len(samples)/sample_rate:.2f}s)")


def generate_sfx_steal(filepath: str):
    sr = 44100
    dur = 0.14
    n = int(sr * dur)
    samples = []
    for i in range(n):
        t = i / sr
        freq = 300.0 + (1600.0 * (t / dur) ** 2)
        env = 1.0 - (t / dur)
        wave_val = 0.6 * math.sin(2 * math.pi * freq * t) + 0.4 * (1.0 if math.sin(2 * math.pi * freq * t) > 0 else -1.0)
        samples.append(wave_val * env * 0.7)
    write_wav(filepath, samples, sr)


def generate_sfx_place(filepath: str):
    sr = 44100
    dur = 0.12
    n = int(sr * dur)
    samples = []
    for i in range(n):
        t = i / sr
        freq = 240.0 * math.exp(-t * 28.0) + 60.0
        env = math.exp(-t * 30.0)
        wave_val = math.sin(2 * math.pi * freq * t)
        samples.append(wave_val * env * 0.8)
    write_wav(filepath, samples, sr)


def generate_sfx_socket(filepath: str):
    sr = 44100
    dur = 0.35
    n = int(sr * dur)
    samples = []
    notes = [523.25, 659.25, 783.99, 1046.50]  # C5, E5, G5, C6
    for i in range(n):
        t = i / sr
        val = 0.0
        for idx, freq in enumerate(notes):
            note_t = t - (idx * 0.05)
            if note_t > 0:
                note_env = math.exp(-note_t * 9.0)
                val += 0.25 * math.sin(2 * math.pi * freq * note_t) * note_env
        samples.append(val * 0.85)
    write_wav(filepath, samples, sr)


def generate_sfx_step(filepath: str):
    sr = 44100
    dur = 0.04
    n = int(sr * dur)
    samples = []
    for i in range(n):
        t = i / sr
        freq = 130.0 * math.exp(-t * 70.0) + 45.0
        env = (1.0 - t / dur) ** 2
        wave_val = math.sin(2 * math.pi * freq * t)
        samples.append(wave_val * env * 0.3)
    write_wav(filepath, samples, sr)


def generate_sfx_undo(filepath: str):
    sr = 44100
    dur = 0.12
    n = int(sr * dur)
    samples = []
    for i in range(n):
        t = i / sr
        freq = 1400.0 - (1000.0 * (t / dur))
        env = 1.0 - (t / dur)
        val = math.sin(2 * math.pi * freq * t) * env
        samples.append(val * 0.6)
    write_wav(filepath, samples, sr)


def generate_sfx_win(filepath: str):
    sr = 44100
    dur = 0.65
    n = int(sr * dur)
    samples = []
    melody = [(0.00, 523.25), (0.10, 659.25), (0.20, 783.99), (0.30, 987.77), (0.40, 1046.50)]
    for i in range(n):
        t = i / sr
        val = 0.0
        for start_t, freq in melody:
            nt = t - start_t
            if nt > 0:
                nenv = math.exp(-nt * 6.0)
                val += 0.28 * math.sin(2 * math.pi * freq * nt) * nenv
        samples.append(val * 0.9)
    write_wav(filepath, samples, sr)


def generate_sfx_bump(filepath: str):
    """Low buzzing thud for invalid action/wall bump."""
    sr = 44100
    dur = 0.08
    n = int(sr * dur)
    samples = []
    for i in range(n):
        t = i / sr
        freq = 90.0 + 30.0 * math.sin(2 * math.pi * 35.0 * t)
        env = math.exp(-t * 22.0)
        sq = 1.0 if math.sin(2 * math.pi * freq * t) > 0 else -1.0
        samples.append(sq * env * 0.45)
    write_wav(filepath, samples, sr)


def generate_sfx_exit_open(filepath: str):
    """Harmonic rising energy vortex drone when exit unlocks."""
    sr = 44100
    dur = 0.45
    n = int(sr * dur)
    samples = []
    for i in range(n):
        t = i / sr
        freq1 = 220.0 + (330.0 * (t / dur))
        freq2 = 440.0 + (660.0 * (t / dur))
        env = math.sin(math.pi * (t / dur))
        val = 0.5 * math.sin(2 * math.pi * freq1 * t) + 0.3 * math.sin(2 * math.pi * freq2 * t)
        samples.append(val * env * 0.75)
    write_wav(filepath, samples, sr)


def generate_sfx_ui_click(filepath: str):
    """Crisp 800Hz menu blip for tactile button responses."""
    sr = 44100
    dur = 0.035
    n = int(sr * dur)
    samples = []
    for i in range(n):
        t = i / sr
        freq = 800.0 - (400.0 * (t / dur))
        env = (1.0 - t / dur) ** 2
        val = math.sin(2 * math.pi * freq * t) * env
        samples.append(val * 0.4)
    write_wav(filepath, samples, sr)


def generate_sfx_chapter_restored(filepath: str):
    """Majestic 7-note restoration chord sequence for chapter completions."""
    sr = 44100
    dur = 1.10
    n = int(sr * dur)
    samples = []
    # C5, E5, G5, B5, C6, D6, E6
    notes = [
        (0.00, 523.25), (0.12, 659.25), (0.24, 783.99),
        (0.36, 987.77), (0.48, 1046.50), (0.60, 1174.66), (0.72, 1318.51)
    ]
    for i in range(n):
        t = i / sr
        val = 0.0
        for start_t, freq in notes:
            nt = t - start_t
            if nt > 0:
                nenv = math.exp(-nt * 4.5)
                val += 0.22 * math.sin(2 * math.pi * freq * nt) * nenv
        samples.append(val * 0.85)
    write_wav(filepath, samples, sr)


def generate_music_ambient(filepath: str):
    """
    Loopable retro synth ambient soundscape (12.0s loop).
    Soft sine-wave arpeggio pads, soothing sub-bass pulse, zero harsh harmonics.
    """
    sr = 44100
    dur = 12.0
    n = int(sr * dur)
    samples = []

    # 12 beats at 60 BPM. Chord sequence:
    # Bars 1-4: C minor (C, Eb, G, Bb)
    # Bars 5-8: Ab major (Ab, C, Eb, G)
    # Bars 9-12: Bb major (Bb, D, F, A)
    chord_notes = [
        # Bar 1 (0..4s): C minor
        [(261.63, 0.0), (311.13, 0.5), (392.00, 1.0), (466.16, 1.5),
         (523.25, 2.0), (392.00, 2.5), (311.13, 3.0), (261.63, 3.5)],
        # Bar 2 (4..8s): Ab major
        [(207.65, 4.0), (261.63, 4.5), (311.13, 5.0), (392.00, 5.5),
         (415.30, 6.0), (311.13, 6.5), (261.63, 7.0), (207.65, 7.5)],
        # Bar 3 (8..12s): Bb major
        [(233.08, 8.0), (293.66, 8.5), (349.23, 9.0), (440.00, 9.5),
         (466.16, 10.0), (349.23, 10.5), (293.66, 11.0), (233.08, 11.5)]
    ]

    for i in range(n):
        t = i / sr
        val = 0.0

        # Gentle sub-bass drone
        if t < 4.0:
            bass_freq = 65.41  # C2
        elif t < 8.0:
            bass_freq = 51.91  # Ab1
        else:
            bass_freq = 58.27  # Bb1
        val += 0.20 * math.sin(2 * math.pi * bass_freq * t)

        # Arpeggiated melodic notes
        for bar in chord_notes:
            for freq, note_time in bar:
                nt = (t - note_time)
                if nt > 0:
                    note_env = math.exp(-nt * 2.2)
                    val += 0.12 * math.sin(2 * math.pi * freq * nt) * note_env

        # Loop crossfade at boundaries (smooth seamless loop)
        loop_fade = 1.0
        fade_time = 0.05
        if t < fade_time:
            loop_fade = t / fade_time
        elif t > dur - fade_time:
            loop_fade = (dur - t) / fade_time

        samples.append(val * loop_fade * 0.40)

    write_wav(filepath, samples, sr)


def main():
    print("=== Generating Pixel Pilferer Art & Audio Assets ===")
    generate_pip_spritesheet("assets/sprites/pip.png")
    generate_blocks_spritesheet("assets/sprites/blocks.png")
    generate_tileset("assets/sprites/tileset.png")
    generate_sockets_spritesheet("assets/sprites/sockets.png")
    generate_exit_portal("assets/sprites/exit_portal.png")
    generate_app_icon("assets/sprites/icon.png")

    generate_sfx_steal("assets/audio/sfx_steal.wav")
    generate_sfx_place("assets/audio/sfx_place.wav")
    generate_sfx_socket("assets/audio/sfx_socket.wav")
    generate_sfx_step("assets/audio/sfx_step.wav")
    generate_sfx_undo("assets/audio/sfx_undo.wav")
    generate_sfx_win("assets/audio/sfx_win.wav")
    generate_sfx_bump("assets/audio/sfx_bump.wav")
    generate_sfx_exit_open("assets/audio/sfx_exit_open.wav")
    generate_sfx_ui_click("assets/audio/sfx_ui_click.wav")
    generate_sfx_chapter_restored("assets/audio/sfx_chapter_restored.wav")
    generate_music_ambient("assets/audio/music_ambient.wav")
    print("=== All Visual and Audio Assets Generated Successfully! ===")


if __name__ == "__main__":
    main()
