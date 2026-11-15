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
	&"steal": "res://assets/audio/sfx_steal.wav",
	&"place": "res://assets/audio/sfx_place.wav",
	&"socket": "res://assets/audio/sfx_socket.wav",
	&"step": "res://assets/audio/sfx_step.wav",
	&"undo": "res://assets/audio/sfx_undo.wav",
	&"win": "res://assets/audio/sfx_win.wav",
	&"bump": "res://assets/audio/sfx_bump.wav",
	&"exit_open": "res://assets/audio/sfx_exit_open.wav",
	&"ui_click": "res://assets/audio/sfx_ui_click.wav",
	&"chapter_restored": "res://assets/audio/sfx_chapter_restored.wav"
}

const MUSIC_PATH = "res://assets/audio/music_ambient.wav"

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
	if ResourceLoader.exists(MUSIC_PATH):
		_music_player = AudioStreamPlayer.new()
		_music_player.stream = load(MUSIC_PATH)
		_music_player.bus = &"Master"
		_music_player.finished.connect(_on_music_finished)
		add_child(_music_player)
		if music_enabled:
			start_music()

func _on_music_finished() -> void:
	# Continuous ambient music loop
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

func play_steal() -> void: play_sfx(&"steal")
func play_place() -> void: play_sfx(&"place")
func play_socket() -> void: play_sfx(&"socket")
func play_step() -> void:
	if _players.has(&"step"):
		var p: AudioStreamPlayer = _players[&"step"]
		p.pitch_scale = 1.0
	play_sfx(&"step")
func play_undo() -> void: play_sfx(&"undo")
func play_win() -> void: play_sfx(&"win")
func play_bump() -> void:
	if not sfx_enabled:
		return
	if _players.has(&"bump"):
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
