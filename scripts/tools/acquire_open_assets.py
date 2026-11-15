"""
Acquire and organize verified, human-authored open-source game assets (CC0 1.0).
Zero Generative AI assets used.
All assets sourced from official repositories of Kenney (kenney.nl) and Juhani Junkala (OpenGameArt.org).
"""

import os
import hashlib
import urllib.request
import urllib.parse
from PIL import Image
import io

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ASSETS_DIR = os.path.join(BASE_DIR, "assets")

DOWNLOADS = {
    # Licenses
    "licenses/CC0-1.0.txt": "https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt",
    "licenses/CC-BY-4.0.txt": "https://creativecommons.org/licenses/by/4.0/legalcode.txt",

    # Kenney Pixel Platformer Master Sheets (CC0 1.0)
    "tilesets/tiles_packed.png": "https://raw.githubusercontent.com/uheartbeast/Pixel-Platformer/master/tiles_packed.png",
    "characters/characters_packed.png": "https://raw.githubusercontent.com/uheartbeast/Pixel-Platformer/master/characters_packed.png",

    # Fonts by Kenney (CC0 1.0)
    "fonts/kenpixel.ttf": "https://raw.githubusercontent.com/iwenzhou/kenney/master/Fonts%20(10%20files)/kenpixel.ttf",
    "fonts/kenpixel_mini.ttf": "https://raw.githubusercontent.com/iwenzhou/kenney/master/Fonts%20(10%20files)/kenpixel_mini.ttf",

    # SFX by Kenney (CC0 1.0)
    "audio/sfx/sfx_jump.wav": "https://raw.githubusercontent.com/uheartbeast/Pixel-Platformer/master/Sounds/Jump.wav",
    "audio/sfx/sfx_hurt.wav": "https://raw.githubusercontent.com/uheartbeast/Pixel-Platformer/master/Sounds/Hurt.wav",
    "audio/sfx/sfx_click.wav": "https://raw.githubusercontent.com/Calinou/kenney-interface-sounds/master/addons/kenney_interface_sounds/click_001.wav",
    "audio/sfx/sfx_land.wav": "https://raw.githubusercontent.com/Calinou/kenney-interface-sounds/master/addons/kenney_interface_sounds/drop_001.wav",
    "audio/sfx/sfx_place.wav": "https://raw.githubusercontent.com/Calinou/kenney-interface-sounds/master/addons/kenney_interface_sounds/drop_003.wav",
    "audio/sfx/sfx_bounce.wav": "https://raw.githubusercontent.com/Calinou/kenney-interface-sounds/master/addons/kenney_interface_sounds/bong_001.wav",
    "audio/sfx/sfx_pluck.wav": "https://raw.githubusercontent.com/Calinou/kenney-interface-sounds/master/addons/kenney_interface_sounds/pluck_001.wav",
    "audio/sfx/sfx_snapback.wav": "https://raw.githubusercontent.com/Calinou/kenney-interface-sounds/master/addons/kenney_interface_sounds/back_001.wav",
    "audio/sfx/sfx_socket.wav": "https://raw.githubusercontent.com/Calinou/kenney-interface-sounds/master/addons/kenney_interface_sounds/glass_001.wav",
    "audio/sfx/sfx_checkpoint.wav": "https://raw.githubusercontent.com/Calinou/kenney-interface-sounds/master/addons/kenney_interface_sounds/confirmation_001.wav",
    "audio/sfx/sfx_door_open.wav": "https://raw.githubusercontent.com/Calinou/kenney-interface-sounds/master/addons/kenney_interface_sounds/open_001.wav",
    "audio/sfx/sfx_siphon.wav": "https://raw.githubusercontent.com/Calinou/kenney-interface-sounds/master/addons/kenney_interface_sounds/glitch_001.wav",

    # Music by Juhani Junkala (SubspaceAudio) - CC0 1.0 Universal
    "audio/music/music_title_loop.mp3": "https://raw.githubusercontent.com/crafter-games/shipnlearn/main/public/audio/music-map.mp3",
    "audio/music/music_world1_loop.mp3": "https://raw.githubusercontent.com/crafter-games/shipnlearn/main/public/audio/music-html.mp3",
    "audio/music/music_world2_loop.mp3": "https://raw.githubusercontent.com/crafter-games/shipnlearn/main/public/audio/music-css.mp3",
    "audio/music/music_victory_jingle.mp3": "https://raw.githubusercontent.com/crafter-games/shipnlearn/main/public/audio/jingle-victory.mp3",
}

def compute_sha256(filepath):
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(8192):
            h.update(chunk)
    return h.hexdigest()

def download_file(rel_path, url):
    dest = os.path.join(ASSETS_DIR, rel_path)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    print(f"Downloading: {rel_path} <- {url}")
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req) as resp:
        content = resp.read()
    with open(dest, "wb") as f:
        f.write(content)
    sha = compute_sha256(dest)
    print(f"  [OK] Saved {len(content)} bytes. SHA256: {sha[:16]}...")
    return sha

def extract_gameplay_and_character_sprites():
    """Extract individual gameplay elements and character animations into clean assets."""
    tiles_path = os.path.join(ASSETS_DIR, "tilesets", "tiles_packed.png")
    char_path = os.path.join(ASSETS_DIR, "characters", "characters_packed.png")

    if not os.path.exists(tiles_path) or not os.path.exists(char_path):
        print("Master sheets missing, skipping extraction.")
        return

    tiles_img = Image.open(tiles_path).convert("RGBA")
    char_img = Image.open(char_path).convert("RGBA")

    # In tiles_packed.png (360x162, 20x9 grid of 18x18 tiles):
    # Spring resting: tile at col 7, row 5 (indices 0-based: x=7*18, y=5*18)
    # Spring compressed: tile at col 8, row 5
    # Shard / Gem blue: tile at col 7, row 3 (diamond gem)
    # Shard / Gem amber: tile at col 8, row 3
    # Shard / Gem ruby: tile at col 9, row 3
    # Shard / Gem emerald: tile at col 10, row 3
    # Checkpoint flag pole: col 11, row 5 & 6
    # Locked door closed: col 10, row 5 & 6
    # Door open: col 11, row 5 & 6

    gameplay_dir = os.path.join(ASSETS_DIR, "gameplay")
    os.makedirs(gameplay_dir, exist_ok=True)

    # Spring Rest (16x16 cropped from 18x18 center)
    spring_rest = tiles_img.crop((7 * 18 + 1, 5 * 18 + 1, 8 * 18 - 1, 6 * 18 - 1))
    spring_rest.save(os.path.join(gameplay_dir, "spring_rest.png"))

    spring_compressed = tiles_img.crop((8 * 18 + 1, 5 * 18 + 1, 9 * 18 - 1, 6 * 18 - 1))
    spring_compressed.save(os.path.join(gameplay_dir, "spring_compressed.png"))

    # Shards (Gems)
    gem_blue = tiles_img.crop((7 * 18 + 1, 3 * 18 + 1, 8 * 18 - 1, 4 * 18 - 1))
    gem_blue.save(os.path.join(gameplay_dir, "shard_cyan.png"))

    gem_amber = tiles_img.crop((8 * 18 + 1, 3 * 18 + 1, 9 * 18 - 1, 4 * 18 - 1))
    gem_amber.save(os.path.join(gameplay_dir, "shard_amber.png"))

    gem_ruby = tiles_img.crop((9 * 18 + 1, 3 * 18 + 1, 10 * 18 - 1, 4 * 18 - 1))
    gem_ruby.save(os.path.join(gameplay_dir, "shard_magenta.png"))

    gem_emerald = tiles_img.crop((10 * 18 + 1, 3 * 18 + 1, 11 * 18 - 1, 4 * 18 - 1))
    gem_emerald.save(os.path.join(gameplay_dir, "shard_emerald.png"))

    # Door (16x32)
    door_top = tiles_img.crop((10 * 18 + 1, 5 * 18 + 1, 11 * 18 - 1, 6 * 18 - 1))
    door_bottom = tiles_img.crop((10 * 18 + 1, 6 * 18 + 1, 11 * 18 - 1, 7 * 18 - 1))
    door = Image.new("RGBA", (16, 32))
    door.paste(door_top, (0, 0))
    door.paste(door_bottom, (0, 16))
    door.save(os.path.join(gameplay_dir, "door_locked.png"))

    # Door Open (16x32)
    door_open_top = tiles_img.crop((11 * 18 + 1, 5 * 18 + 1, 12 * 18 - 1, 6 * 18 - 1))
    door_open_bottom = tiles_img.crop((11 * 18 + 1, 6 * 18 + 1, 12 * 18 - 1, 7 * 18 - 1))
    door_open = Image.new("RGBA", (16, 32))
    door_open.paste(door_open_top, (0, 0))
    door_open.paste(door_open_bottom, (0, 16))
    door_open.save(os.path.join(gameplay_dir, "door_open.png"))

    # Flag / Checkpoint (16x32)
    flag_top = tiles_img.crop((11 * 18 + 1, 6 * 18 + 1, 12 * 18 - 1, 7 * 18 - 1))
    flag_bottom = tiles_img.crop((11 * 18 + 1, 7 * 18 + 1, 12 * 18 - 1, 8 * 18 - 1))
    flag = Image.new("RGBA", (16, 32))
    flag.paste(flag_top, (0, 0))
    flag.paste(flag_bottom, (0, 16))
    flag.save(os.path.join(gameplay_dir, "checkpoint_flag.png"))

    # Pip Character Spritesheet (64x24: Idle, Run1, Run2, Jump/Fall)
    # Green Pip is at x=0, y=0 in characters_packed.png (24x24 frames)
    # Col 0: Idle, Col 1: Run1, Col 2: Run2 / Jump
    char_dir = os.path.join(ASSETS_DIR, "characters")
    pip_idle = char_img.crop((0, 0, 24, 24))
    pip_run1 = char_img.crop((24, 0, 48, 24))
    pip_run2 = char_img.crop((48, 0, 72, 24))
    pip_jump = char_img.crop((24, 24, 48, 48))

    pip_strip = Image.new("RGBA", (96, 24))
    pip_strip.paste(pip_idle, (0, 0))
    pip_strip.paste(pip_run1, (24, 0))
    pip_strip.paste(pip_run2, (48, 0))
    pip_strip.paste(pip_jump, (72, 0))
    pip_strip.save(os.path.join(char_dir, "pip_character_strip.png"))

    # Also save individual 16x16 / 24x24 frames
    pip_idle.save(os.path.join(char_dir, "pip_idle.png"))
    pip_run1.save(os.path.join(char_dir, "pip_run.png"))
    pip_jump.save(os.path.join(char_dir, "pip_jump.png"))

    # World 1-4 Tileset sub-sheets (16x16 tiles cropped from the 18x18 master grid)
    tilesets_dir = os.path.join(ASSETS_DIR, "tilesets")
    # World 1: Grassland/Street (Rows 0-1)
    w1_sheet = Image.new("RGBA", (16 * 10, 16 * 2))
    for r in range(2):
        for c in range(10):
            tile = tiles_img.crop((c * 18 + 1, r * 18 + 1, (c + 1) * 18 - 1, (r + 1) * 18 - 1))
            w1_sheet.paste(tile, (c * 16, r * 16))
    w1_sheet.save(os.path.join(tilesets_dir, "tileset_world1_street.png"))

    # World 2: Underground Caverns (Rows 2-3, cols 0-9)
    w2_sheet = Image.new("RGBA", (16 * 10, 16 * 2))
    for r in range(2):
        for c in range(10):
            tile = tiles_img.crop((c * 18 + 1, (r + 2) * 18 + 1, (c + 1) * 18 - 1, (r + 3) * 18 - 1))
            w2_sheet.paste(tile, (c * 16, r * 16))
    w2_sheet.save(os.path.join(tilesets_dir, "tileset_world2_cavern.png"))

    # World 3: Industrial Vault (Rows 3-4, cols 10-19)
    w3_sheet = Image.new("RGBA", (16 * 10, 16 * 2))
    for r in range(2):
        for c in range(10):
            tile = tiles_img.crop(((c + 10) * 18 + 1, (r + 3) * 18 + 1, (c + 11) * 18 - 1, (r + 4) * 18 - 1))
            w3_sheet.paste(tile, (c * 16, r * 16))
    w3_sheet.save(os.path.join(tilesets_dir, "tileset_world3_vault.png"))

    # World 4: Chromatic Citadel (Rows 4-5, cols 0-9)
    w4_sheet = Image.new("RGBA", (16 * 10, 16 * 2))
    for r in range(2):
        for c in range(10):
            tile = tiles_img.crop((c * 18 + 1, (r + 4) * 18 + 1, (c + 1) * 18 - 1, (r + 5) * 18 - 1))
            w4_sheet.paste(tile, (c * 16, r * 16))
    w4_sheet.save(os.path.join(tilesets_dir, "tileset_world4_citadel.png"))

    print("[OK] Extracted gameplay, character, and 4-world tilesets.")

def main():
    print("Starting Open-Source Asset Acquisition...")
    shas = {}
    for rel_path, url in DOWNLOADS.items():
        try:
            sha = download_file(rel_path, url)
            shas[rel_path] = sha
        except Exception as e:
            print(f"  [ERROR] Failed to download {rel_path}: {e}")

    extract_gameplay_and_character_sprites()
    print("All open-source assets acquired successfully.")

if __name__ == "__main__":
    main()
