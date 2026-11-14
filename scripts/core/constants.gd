class_name Constants extends RefCounted

## Action Enumerations
enum ActionType {
	MOVE_NORTH,
	MOVE_EAST,
	MOVE_SOUTH,
	MOVE_WEST,
	INTERACT_NORTH,
	INTERACT_EAST,
	INTERACT_SOUTH,
	INTERACT_WEST,
	UNDO,
	RESTART
}

## Tile Types
enum TileType {
	EMPTY = 0,
	FLOOR = 1,
	VOID = 2,
	WALL = 3
}

## Chromatic Colors
enum BlockColor {
	NEUTRAL = 0,
	CYAN = 1,
	AMBER = 2,
	MAGENTA = 3,
	EMERALD = 4
}

## Cardinal Direction Vectors
const DIR_NORTH: Vector2i = Vector2i(0, -1)
const DIR_EAST: Vector2i = Vector2i(1, 0)
const DIR_SOUTH: Vector2i = Vector2i(0, 1)
const DIR_WEST: Vector2i = Vector2i(-1, 0)

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	DIR_NORTH,
	DIR_EAST,
	DIR_SOUTH,
	DIR_WEST
]

## Action to Direction Mapping
static func action_to_direction(action: int) -> Vector2i:
	match action:
		ActionType.MOVE_NORTH, ActionType.INTERACT_NORTH:
			return DIR_NORTH
		ActionType.MOVE_EAST, ActionType.INTERACT_EAST:
			return DIR_EAST
		ActionType.MOVE_SOUTH, ActionType.INTERACT_SOUTH:
			return DIR_SOUTH
		ActionType.MOVE_WEST, ActionType.INTERACT_WEST:
			return DIR_WEST
		_:
			return Vector2i.ZERO

static func is_move_action(action: int) -> bool:
	return action in [
		ActionType.MOVE_NORTH,
		ActionType.MOVE_EAST,
		ActionType.MOVE_SOUTH,
		ActionType.MOVE_WEST
	]

static func is_interact_action(action: int) -> bool:
	return action in [
		ActionType.INTERACT_NORTH,
		ActionType.INTERACT_EAST,
		ActionType.INTERACT_SOUTH,
		ActionType.INTERACT_WEST
	]

static func action_name(action: int) -> String:
	match action:
		ActionType.MOVE_NORTH: return "MOVE_NORTH"
		ActionType.MOVE_EAST: return "MOVE_EAST"
		ActionType.MOVE_SOUTH: return "MOVE_SOUTH"
		ActionType.MOVE_WEST: return "MOVE_WEST"
		ActionType.INTERACT_NORTH: return "INTERACT_NORTH"
		ActionType.INTERACT_EAST: return "INTERACT_EAST"
		ActionType.INTERACT_SOUTH: return "INTERACT_SOUTH"
		ActionType.INTERACT_WEST: return "INTERACT_WEST"
		ActionType.UNDO: return "UNDO"
		ActionType.RESTART: return "RESTART"
		_: return "UNKNOWN"

static func color_name(color: int) -> String:
	match color:
		BlockColor.NEUTRAL: return "Neutral"
		BlockColor.CYAN: return "Cyan"
		BlockColor.AMBER: return "Amber"
		BlockColor.MAGENTA: return "Magenta"
		BlockColor.EMERALD: return "Emerald"
		_: return "Unknown"
