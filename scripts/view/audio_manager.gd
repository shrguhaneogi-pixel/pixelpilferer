class_name AudioManager extends Node

@export var sfx_enabled: bool = true
@export var sfx_volume: float = 1.0 # 0.0 to 1.0

var _players: Dictionary = {}

const SFX_PATHS = {
	&"steal": "res://assets/sfx/sfx_steal.wav",
	&"place": "res://assets/sfx/sfx_place.wav",
	&"socket": "res://assets/sfx/sfx_socket.wav",
	&"step": "res://assets/sfx/sfx_step.wav",
	&"undo": "res://assets/sfx/sfx_undo.wav",
	&"win": "res://assets/sfx/sfx_win.wav"
}

func _ready() -> void:
	for sfx_name: StringName in SFX_PATHS:
		var stream_path: String = SFX_PATHS[sfx_name]
		if ResourceLoader.exists(stream_path):
			var player := AudioStreamPlayer.new()
			player.stream = load(stream_path)
			player.bus = &"Master"
			add_child(player)
			_players[sfx_name] = player

func play_sfx(sfx_name: StringName) -> void:
	if not sfx_enabled:
		return
	if _players.has(sfx_name):
		var player: AudioStreamPlayer = _players[sfx_name]
		player.volume_db = linear_to_db(clampf(sfx_volume, 0.0001, 1.0))
		player.play()

func play_steal() -> void: play_sfx(&"steal")
func play_place() -> void: play_sfx(&"place")
func play_socket() -> void: play_sfx(&"socket")
func play_step() -> void: play_sfx(&"step")
func play_undo() -> void: play_sfx(&"undo")
func play_win() -> void: play_sfx(&"win")
