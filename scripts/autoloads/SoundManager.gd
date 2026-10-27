extends Node
## SoundManager.gd
## Autoload Singleton that procedurally synthesizes and plays tactical FPS audio effects.
## Provides standalone audio for gunshots, reload clicks, hitmarkers, and dry fires.

var _gunshot_stream: AudioStreamWAV
var _hitmarker_stream: AudioStreamWAV
var _headshot_stream: AudioStreamWAV
var _reload_stream: AudioStreamWAV
var _empty_stream: AudioStreamWAV

var _players: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 8

func _ready() -> void:
	# Pre-synthesize all combat sound streams into memory
	_gunshot_stream = _synthesize_gunshot()
	_hitmarker_stream = _synthesize_hitmarker()
	_headshot_stream = _synthesize_headshot()
	_reload_stream = _synthesize_reload()
	_empty_stream = _synthesize_empty_click()
	
	# Create audio stream player pool for multi-channel playback
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

func _get_available_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	# Fallback: reuse first player
	return _players[0]

func play_gunshot(pitch_variance: float = 0.05) -> void:
	var player := _get_available_player()
	player.stream = _gunshot_stream
	player.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	player.volume_db = 0.0
	player.play()

func play_hitmarker(is_headshot: bool = false) -> void:
	var player := _get_available_player()
	player.stream = _headshot_stream if is_headshot else _hitmarker_stream
	player.pitch_scale = randf_range(0.98, 1.02)
	player.volume_db = 2.0 if is_headshot else 0.0
	player.play()

func play_reload() -> void:
	var player := _get_available_player()
	player.stream = _reload_stream
	player.pitch_scale = 1.0
	player.volume_db = -2.0
	player.play()

func play_empty_click() -> void:
	var player := _get_available_player()
	player.stream = _empty_stream
	player.pitch_scale = 1.0
	player.volume_db = -4.0
	player.play()

# ==============================================================================
# PROCEDURAL PCM AUDIO GENERATION
# ==============================================================================

func _synthesize_gunshot() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.25 # 250ms gunshot punch and tail
	var total_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(total_samples)
	
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Rapid explosive envelope decay
		var env: float = exp(-t * 18.0)
		
		# Low frequency punch (sine wave dropping from 160Hz to 40Hz)
		var freq: float = lerpf(160.0, 40.0, clampf(t / 0.1, 0.0, 1.0))
		var bass: float = sin(t * freq * TAU) * 0.7
		
		# High frequency mechanical noise transient
		var noise: float = randf_range(-1.0, 1.0) * exp(-t * 35.0) * 0.6
		
		# Combined sample
		var sample_val: float = (bass + noise) * env
		sample_val = clampf(sample_val, -1.0, 1.0)
		
		# 8-bit PCM unsigned (0 to 255)
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
	var duration: float = 0.06 # 60ms quick tactile 'tick'
	var total_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(total_samples)
	
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = exp(-t * 70.0)
		# High crisp tone at 1200Hz
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
	var duration: float = 0.15 # 150ms metallic ping
	var total_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(total_samples)
	
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = exp(-t * 22.0)
		# Dual chime frequency (2400Hz + 3200Hz)
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
		# Double mechanical click at t=0.05 and t=0.22
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
