class_name AudioService extends Node

## Manages sound effect playback, background music streaming, volume controls, and audio settings.

@export var master_volume: float = 1.0 # 0.0 to 1.0
@export var sfx_volume: float = 1.0    # 0.0 to 1.0
@export var music_volume: float = 0.8  # 0.0 to 1.0
@export var sfx_enabled: bool = true
@export var music_enabled: bool = true

var _players: Dictionary = {}
var _music_player: AudioStreamPlayer

const SFX_MAP = {
	# Original SFX mappings
	&"steal": "res://assets/audio/sfx_steal.wav",
	&"place": "res://assets/audio/sfx_place.wav",
	&"socket": "res://assets/audio/sfx_socket.wav",
	&"step": "res://assets/audio/sfx_step.wav",
	&"undo": "res://assets/audio/sfx_undo.wav",
	&"win": "res://assets/audio/sfx_win.wav",
	&"bump": "res://assets/audio/sfx_bump.wav",
	&"exit_open": "res://assets/audio/sfx_exit_open.wav",
	&"ui_click": "res://assets/audio/sfx_ui_click.wav",
	&"chapter_restored": "res://assets/audio/sfx_chapter_restored.wav",

	# Verified Open-Source Asset mappings (Kenney CC0 1.0)
	&"jump": "res://assets/audio/sfx/sfx_jump.wav",
	&"hurt": "res://assets/audio/sfx/sfx_hurt.wav",
	&"bounce": "res://assets/audio/sfx/sfx_bounce.wav",
	&"pluck": "res://assets/audio/sfx/sfx_pluck.wav",
	&"land": "res://assets/audio/sfx/sfx_land.wav",
	&"siphon": "res://assets/audio/sfx/sfx_siphon.wav",
	&"snapback": "res://assets/audio/sfx/sfx_snapback.wav",
	&"shard": "res://assets/audio/sfx/sfx_socket.wav",
	&"checkpoint": "res://assets/audio/sfx/sfx_checkpoint.wav",
	&"door_open": "res://assets/audio/sfx/sfx_door_open.wav",
	&"victory": "res://assets/audio/music/music_victory_jingle.mp3"
}

const MUSIC_PATH = "res://assets/audio/music/music_world1_loop.mp3"
const LEGACY_MUSIC_PATH = "res://assets/audio/music_ambient.wav"

func _ready() -> void:
	_init_sfx_players()
	_init_music_player()

func _init_sfx_players() -> void:
	for sfx_name: StringName in SFX_MAP:
		var path: String = SFX_MAP[sfx_name]
		if ResourceLoader.exists(path):
			var player := AudioStreamPlayer.new()
			player.stream = load(path)
			player.bus = &"Master"
			add_child(player)
			_players[sfx_name] = player

func _init_music_player() -> void:
	var stream_path = MUSIC_PATH if ResourceLoader.exists(MUSIC_PATH) else LEGACY_MUSIC_PATH
	if ResourceLoader.exists(stream_path):
		_music_player = AudioStreamPlayer.new()
		_music_player.stream = load(stream_path)
		_music_player.bus = &"Master"
		_music_player.finished.connect(_on_music_finished)
		add_child(_music_player)
		if music_enabled:
			start_music()

func _on_music_finished() -> void:
	# Continuous music loop
	if music_enabled and _music_player:
		_music_player.play()

func start_music() -> void:
	if _music_player and music_enabled:
		update_music_volume()
		if is_inside_tree() and _music_player.is_inside_tree() and not _music_player.playing:
			_music_player.play()

func stop_music() -> void:
	if _music_player and _music_player.playing:
		_music_player.stop()

func play_track(track_path: String) -> void:
	if not ResourceLoader.exists(track_path):
		return
	if _music_player:
		_music_player.stop()
		_music_player.stream = load(track_path)
		if music_enabled:
			start_music()

func update_music_volume() -> void:
	if _music_player:
		if not music_enabled:
			_music_player.volume_db = -80.0
		else:
			var eff_vol: float = clampf(music_volume * master_volume, 0.0001, 1.0)
			_music_player.volume_db = linear_to_db(eff_vol)

func play_sfx(sfx_name: StringName) -> void:
	if not sfx_enabled:
		return
	if _players.has(sfx_name):
		var player: AudioStreamPlayer = _players[sfx_name]
		var eff_vol: float = clampf(sfx_volume * master_volume, 0.0001, 1.0)
		player.volume_db = linear_to_db(eff_vol)
		if is_inside_tree() and player.is_inside_tree():
			player.play()

func play_steal() -> void:
	if _players.has(&"siphon"):
		play_sfx(&"siphon")
	else:
		if _players.has(&"steal"):
			_players[&"steal"].pitch_scale = randf_range(0.97, 1.03)
		play_sfx(&"steal")

func play_place() -> void:
	if _players.has(&"place"):
		_players[&"place"].pitch_scale = randf_range(0.97, 1.03)
	play_sfx(&"place")

func play_socket() -> void:
	play_sfx(&"socket")

func play_step() -> void:
	if _players.has(&"step"):
		_players[&"step"].pitch_scale = randf_range(0.95, 1.05)
	play_sfx(&"step")

func play_undo() -> void: play_sfx(&"undo")
func play_win() -> void: play_sfx(&"win")
func play_bump() -> void:
	if not sfx_enabled:
		return
	if _players.has(&"bump"):
		_players[&"bump"].pitch_scale = randf_range(0.94, 1.04)
		play_sfx(&"bump")
	elif _players.has(&"step"):
		var player: AudioStreamPlayer = _players[&"step"]
		player.pitch_scale = 0.5
		var eff_vol: float = clampf(sfx_volume * master_volume * 0.75, 0.0001, 1.0)
		player.volume_db = linear_to_db(eff_vol)
		player.play()

func play_exit_open() -> void: play_sfx(&"exit_open")
func play_ui_click() -> void: play_sfx(&"ui_click")
func play_chapter_restored() -> void: play_sfx(&"chapter_restored")

# Rebound-specific platformer actions
func play_jump() -> void: play_sfx(&"jump")
func play_bounce() -> void: play_sfx(&"bounce")
func play_land() -> void: play_sfx(&"land")
func play_siphon() -> void: play_sfx(&"siphon")
func play_snapback() -> void: play_sfx(&"snapback")
func play_shard() -> void: play_sfx(&"shard")
func play_checkpoint() -> void: play_sfx(&"checkpoint")
func play_door_open() -> void: play_sfx(&"door_open")
func play_victory() -> void: play_sfx(&"victory")
