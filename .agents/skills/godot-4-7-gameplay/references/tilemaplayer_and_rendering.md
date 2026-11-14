# Correct Godot 4.7 TileMapLayer Usage and 2D Rendering

## 1. TileMapLayer Architecture vs Deprecated TileMap

In Godot 4.3+, the monolithic `TileMap` node was deprecated. In Godot 4.7:
- **`TileMapLayer` nodes are individual, dedicated nodes** in the scene tree.
- Each layer functions as an independent 2D canvas item with its own `z_index`, `y_sort_enabled`, navigation, physics, and rendering properties.
- **Never instantiate or script the legacy `TileMap` node.**

### Recommended Scene Structure
```text
MapRoot (Node2D)
├── GroundLayer (TileMapLayer)        # z_index: 0, walkable base terrain
├── HazardLayer (TileMapLayer)        # z_index: 1, traps, water, lava
├── ObstacleLayer (TileMapLayer)      # z_index: 2, walls, pillars (collision data)
├── EntityContainer (Node2D)          # y_sort_enabled: true
│   ├── Player (Node2D / View)
│   └── Guards (Node2D / View)
└── OverheadLayer (TileMapLayer)      # z_index: 10, roofs, canopies (drawn above actors)
```

---

## 2. TileMapLayer API Reference

All coordinate conversions and cell operations run directly on the specific `TileMapLayer` instance:

```gdscript
class_name MapManager extends Node2D

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var obstacle_layer: TileMapLayer = $ObstacleLayer

# Convert between screen/local space and integer grid space
func screen_pos_to_tile(local_pos: Vector2) -> Vector2i:
    return ground_layer.local_to_map(local_pos)

func tile_to_world_pos(cell: Vector2i) -> Vector2:
    return ground_layer.map_to_local(cell)

# Cell inspection
func is_cell_empty(cell: Vector2i) -> bool:
    return obstacle_layer.get_cell_source_id(cell) == -1

func get_cell_atlas(cell: Vector2i) -> Vector2i:
    return ground_layer.get_cell_atlas_coords(cell)

# Cell modification
func place_tile(cell: Vector2i, source_id: int, atlas_coords: Vector2i) -> void:
    ground_layer.set_cell(cell, source_id, atlas_coords, 0)

func remove_tile(cell: Vector2i) -> void:
    ground_layer.erase_cell(cell)

# Querying map bounds
func get_map_boundaries() -> Rect2i:
    return ground_layer.get_used_rect()
```

---

## 3. TileSet Custom Data Layers

Instead of hardcoding tile coordinates to check properties like "walkable", "slippery", or "solid", configure **Custom Data Layers** in the `TileSet` resource.

### Reading Custom Data
```gdscript
func is_tile_walkable(cell: Vector2i) -> bool:
    # 1. Check if an obstacle exists on the obstacle layer
    if obstacle_layer.get_cell_source_id(cell) != -1:
        return false

    # 2. Query TileData from the ground layer
    var tile_data: TileData = ground_layer.get_cell_tile_data(cell)
    if tile_data == null:
        return false # Empty void is not walkable

    # 3. Read custom data property safely
    var walkable: Variant = tile_data.get_custom_data(&"walkable")
    if walkable is bool:
        return walkable as bool

    return false
```

---

## 4. Y-Sorting and 2D Depth Ordering

For top-down or 2.5D grid games:
1. Enable `y_sort_enabled = true` on the parent node containing entities and relevant `TileMapLayer` nodes.
2. Ensure each actor's origin (`position`) sits exactly at its "footing" base (e.g., bottom-center of the tile: `y = tile_height`).
3. Set `y_sort_origin` on `TileMapLayer` or tiles within the TileSet if needed.

---

## 5. Deprecated Patterns to Avoid

| Legacy Pattern (Godot 3 / Early 4) | Correct Godot 4.7 Pattern |
| :--- | :--- |
| `tilemap.get_cell_source_id(layer_idx, coords)` | `tilemap_layer.get_cell_source_id(coords)` |
| `tilemap.set_cell(layer_idx, coords, ...)` | `tilemap_layer.set_cell(coords, ...)` |
| `tilemap.local_to_map(...)` on monolithic node | Call `local_to_map(...)` on specific `TileMapLayer` |
| Monolithic `TileMap` inspector layers | Individual child `TileMapLayer` nodes in scene tree |
