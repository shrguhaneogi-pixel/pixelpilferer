# Pixel-Art Rendering, Integer Scaling, and Camera Setup

## 1. Project Configuration for Crisp Pixel Art

To avoid blurry textures, uneven pixels, and shimmering during movement, configure the following settings in `project.godot`:

```ini
[display]
window/size/viewport_width=320
window/size/viewport_height=180
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
window/stretch/scale_mode="integer"

[rendering]
textures/canvas_textures/default_texture_filter=0 # 0 = Nearest (Point)
2d/snap/snap_2d_transforms_to_pixel=true
2d/snap/snap_2d_vertices_to_pixel=true
```

### Stretch Mode Explanation
- **`mode = "canvas_items"`:** Sprites are rendered at native coordinates and scaled up cleanly with integer multiples. Best for sharp UI fonts and smooth sprite offsets.
- **`mode = "viewport"`:** The entire viewport is rendered at the base resolution (320x180) and upscaled as a whole image. Guarantees 100% strict retro pixel grid alignment across everything, including text and particles.
- **`scale_mode = "integer"`:** Prevents fractional pixel scales (e.g. 2.4x) that distort square pixels. Only scales in integer multiples (1x, 2x, 3x, 4x) with black letterbox borders if aspect ratios differ.

---

## 2. Preventing Subpixel Jitter

Subpixel jitter occurs when camera positions or entity coordinates have fractional float values (e.g., `position.x = 104.37`), causing sprite pixels to wobble back and forth between screen pixels.

### Pixel-Perfect Camera Script
Attach this script to `Camera2D` to ensure smooth tracking without subpixel crawl:

```gdscript
class_name PixelPerfectCamera extends Camera2D

@export var target: Node2D
@export var follow_speed: float = 10.0

func _process(delta: float) -> void:
    if target == null:
        return

    # 1. Smoothly interpolate toward target in floating space
    var desired_pos := global_position.lerp(target.global_position, follow_speed * delta)

    # 2. Snap final camera position to exact whole pixels
    global_position = desired_pos.round()
```

---

## 3. Sprite and TileSet Alignment Checklist

- [ ] TileSet tile size matches texture grid exactly (e.g., `16x16`).
- [ ] Sprites have `centered = true` with proper `offset` (or `centered = false` anchored at top-left `(0, 0)`).
- [ ] No nodes in the hierarchy have non-uniform scales (e.g., `scale = Vector2(1.0, 1.0)` always; never fractional scales like `Vector2(1.02, 0.98)`).
- [ ] Texture resources use Default Filter: Nearest (inherited from project settings).
