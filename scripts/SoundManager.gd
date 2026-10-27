extends Node
## SoundManager.gd
## Autoload Singleton that procedurally synthesizes and plays tactical FPS audio effects.
## Provides standalone audio for gunshots, reload clicks, hitmarkers, and dry fires.

var _gunshot_stream: AudioStreamWAV
var _hitmarker_stream: AudioStreamWAV
var _headshot_stream: AudioStreamWAV
var _reload_stream: AudioStreamWAV
var _empty_stream: AudioStreamWAV
var _enemy_alert_voice_streams: Array[AudioStream] = []

var _players: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 8
var _last_alert_voice_time: float = -999.0
var _last_alert_voice_index: int = -1
const ALERT_VOICE_GLOBAL_COOLDOWN: float = 2.5
const ENEMY_ALERT_VOICE_DIRECTORY := "res://assets/audio/voices/enemy_alert"

func _ready() -> void:
	_gunshot_stream = _synthesize_gunshot()
	_hitmarker_stream = _synthesize_hitmarker()
	_headshot_stream = _synthesize_headshot()
	_reload_stream = _synthesize_reload()
	_empty_stream = _synthesize_empty_click()
	_load_enemy_alert_voices()
	
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

func _get_available_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]

func stop_all() -> void:
	for p in _players:
		if p and p.playing:
			p.stop()

func _can_play_combat_audio() -> bool:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		var GameConstants = preload("res://scripts/utilities/constants.gd")
		if gm.current_state != GameConstants.GameState.PLAYING and gm.current_state != GameConstants.GameState.BOOT:
			return false
		if gm.is_game_paused:
			return false
	return true

func play_gunshot(pitch_variance: float = 0.05) -> void:
	if not _can_play_combat_audio():
		return
	var player := _get_available_player()
	player.stream = _gunshot_stream
	player.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	player.volume_db = 0.0
	player.play()

func play_hitmarker(is_headshot: bool = false) -> void:
	if not _can_play_combat_audio():
		return
	var player := _get_available_player()
	player.stream = _headshot_stream if is_headshot else _hitmarker_stream
	player.pitch_scale = randf_range(0.98, 1.02)
	player.volume_db = 2.0 if is_headshot else 0.0
	player.play()

func play_reload() -> void:
	if not _can_play_combat_audio():
		return
	var player := _get_available_player()
	player.stream = _reload_stream
	player.pitch_scale = 1.0
	player.volume_db = -2.0
	player.play()

func play_empty_click() -> void:
	if not _can_play_combat_audio():
		return
	var player := _get_available_player()
	player.stream = _empty_stream
	player.pitch_scale = 1.0
	player.volume_db = -4.0
	player.play()

func try_play_enemy_alert(player: AudioStreamPlayer3D) -> bool:
	# The caller owns this 3D player, so the voice follows the detecting Enemy.
	# With no real voice assets installed, fail silently instead of presenting a
	# procedural beep as human speech.
	if not _can_play_combat_audio() or not is_instance_valid(player):
		return false
	if _enemy_alert_voice_streams.is_empty():
		return false
	var current_time := Time.get_ticks_msec() / 1000.0
	if current_time - _last_alert_voice_time < ALERT_VOICE_GLOBAL_COOLDOWN:
		return false

	var voice_index := randi_range(0, _enemy_alert_voice_streams.size() - 1)
	if _enemy_alert_voice_streams.size() > 1 and voice_index == _last_alert_voice_index:
		voice_index = (voice_index + randi_range(1, _enemy_alert_voice_streams.size() - 1)) % _enemy_alert_voice_streams.size()

	_last_alert_voice_time = current_time
	_last_alert_voice_index = voice_index
	player.stream = _enemy_alert_voice_streams[voice_index]
	player.pitch_scale = randf_range(0.98, 1.02)
	player.play()
	return true

func _load_enemy_alert_voices() -> void:
	_enemy_alert_voice_streams.clear()
	if not DirAccess.dir_exists_absolute(ENEMY_ALERT_VOICE_DIRECTORY):
		return
	for file_name in DirAccess.get_files_at(ENEMY_ALERT_VOICE_DIRECTORY):
		var extension := file_name.get_extension().to_lower()
		if extension not in ["wav", "ogg", "mp3"]:
			continue
		var stream := load(ENEMY_ALERT_VOICE_DIRECTORY.path_join(file_name)) as AudioStream
		if stream:
			_enemy_alert_voice_streams.append(stream)


# ==============================================================================
# PROCEDURAL PCM AUDIO GENERATION
# ==============================================================================

func _synthesize_gunshot() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.25
	var total_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(total_samples)
	
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = exp(-t * 18.0)
		var freq: float = lerpf(160.0, 40.0, clampf(t / 0.1, 0.0, 1.0))
		var bass: float = sin(t * freq * TAU) * 0.7
		var noise: float = randf_range(-1.0, 1.0) * exp(-t * 35.0) * 0.6
		var sample_val: float = (bass + noise) * env
		sample_val = clampf(sample_val, -1.0, 1.0)
		var byte_val: int = int((sample_val * 0.5 + 0.5) * 255.0)
		data[i] = byte_val
		
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream

func _synthesize_hitmarker() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.06
	var total_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(total_samples)
	
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = exp(-t * 70.0)
		var tone: float = sin(t * 1200.0 * TAU) * env
		var byte_val: int = int((tone * 0.5 + 0.5) * 255.0)
		data[i] = byte_val
		
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream

func _synthesize_headshot() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.15
	var total_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(total_samples)
	
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = exp(-t * 22.0)
		var ping: float = (sin(t * 2400.0 * TAU) * 0.6 + sin(t * 3200.0 * TAU) * 0.4) * env
		var byte_val: int = int((ping * 0.5 + 0.5) * 255.0)
		data[i] = byte_val
		
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream

func _synthesize_reload() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.35
	var total_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(total_samples)
	
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var click1: float = exp(-absf(t - 0.05) * 80.0) * sin((t - 0.05) * 800.0 * TAU)
		var click2: float = exp(-absf(t - 0.22) * 100.0) * sin((t - 0.22) * 1400.0 * TAU)
		var val: float = clampf(click1 + click2, -1.0, 1.0)
		var byte_val: int = int((val * 0.5 + 0.5) * 255.0)
		data[i] = byte_val
		
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream

func _synthesize_empty_click() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.05
	var total_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(total_samples)
	
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = exp(-t * 90.0)
		var click: float = sin(t * 1800.0 * TAU) * env
		var byte_val: int = int((click * 0.5 + 0.5) * 255.0)
		data[i] = byte_val
		
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream
