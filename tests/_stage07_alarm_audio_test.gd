extends SceneTree

const STAGE_SCENE := preload("res://scenes/stages/Stage07.tscn")

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	print("[Stage07AlarmAudioTest] START: Testing Stage 07 Alarm Sound System...")

	var stage = STAGE_SCENE.instantiate()
	root.add_child(stage)
	current_scene = stage

	for _f in 10:
		await process_frame

	# -------------------------------------------------------------
	# STEP 1: VERIFY ALARM AUDIO NODE & STREAM CONFIGURATION
	# -------------------------------------------------------------
	assert(stage.has_node("Environment/SecurityWatchtower/AlarmConsole/AlarmSirenAudio3D"), "AlarmSirenAudio3D node must exist under AlarmConsole")
	var audio_player: AudioStreamPlayer3D = stage.get_node("Environment/SecurityWatchtower/AlarmConsole/AlarmSirenAudio3D") as AudioStreamPlayer3D
	assert(audio_player != null, "AudioStreamPlayer3D instance must be valid")
	assert(audio_player.stream != null, "Audio player stream must be assigned")
	assert(audio_player.bus == "Master", "Audio player bus must be Master")
	assert(audio_player.unit_size == 20.0, "Unit size must provide harbor-wide 3D attenuation")
	assert(audio_player.max_distance >= 200.0, "Max distance must cover harbor perimeter")

	var stream := audio_player.stream
	if stream is AudioStreamWAV:
		assert(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Synthesized stream must be set to LOOP_FORWARD")
		print("[Stage07AlarmAudioTest] Verified AudioStreamWAV stream format: loop_mode=LOOP_FORWARD, mix_rate=%d, samples=%d" % [stream.mix_rate, stream.data.size()])

	print("[Stage07AlarmAudioTest] PASS: Alarm audio player and stream configuration verified.")

	# -------------------------------------------------------------
	# STEP 2: VERIFY SIREN REMAINS SILENT BEFORE LANDING (CINEMATIC)
	# -------------------------------------------------------------
	assert(stage.is_alarm_disabled == false, "Alarm must initially be active")
	assert(stage.is_cinematic_active() == true, "Intro cinematic must initially be active before landing")
	assert(stage.player.is_active == false, "Player must not be active before landing")
	assert(stage.is_alarm_audio_playing() == false, "Siren must remain SILENT before player lands")
	# Premature call to _start_alarm_audio() during cinematic must be rejected
	stage._start_alarm_audio()
	assert(stage.is_alarm_audio_playing() == false, "Premature call to _start_alarm_audio during cinematic must be blocked")
	print("[Stage07AlarmAudioTest] PASS: Siren remains silent before player lands / becomes active.")

	# -------------------------------------------------------------
	# STEP 3: VERIFY SIREN STARTS UPON LANDING / OPERATIVE DEPLOYMENT
	# -------------------------------------------------------------
	print("[Stage07AlarmAudioTest] Concluding cinematic / triggering player landing...")
	stage.skip_cinematic()
	await process_frame
	assert(stage.is_cinematic_active() == false, "Cinematic must be inactive after landing")
	assert(stage.player.is_active == true, "Player must be active after landing")
	assert(stage.is_alarm_audio_playing() == true, "Alarm siren must start playing when player lands")
	print("[Stage07AlarmAudioTest] PASS: Siren starts exactly upon operative landing/gameplay start.")

	# -------------------------------------------------------------
	# STEP 3B: PREVENT UNNECESSARY RE-TRIGGERING / RESTARTING
	# -------------------------------------------------------------
	print("[Stage07AlarmAudioTest] Testing protection against redundant start triggers...")
	# Calling _start_alarm_audio() when already playing must not interrupt or duplicate
	stage._start_alarm_audio()
	assert(stage.is_alarm_audio_playing() == true, "Alarm siren must continue playing uninterrupted")
	print("[Stage07AlarmAudioTest] PASS: Redundant start trigger safely ignored.")

	# -------------------------------------------------------------
	# STEP 4: VERIFY IMMEDIATE STOPPING UPON ALARM DEACTIVATION
	# -------------------------------------------------------------
	print("[Stage07AlarmAudioTest] Disabling alarm at console...")
	var disable_result = stage.interact_with_alarm()
	assert(disable_result == true, "Disabling alarm must return true")
	assert(stage.is_alarm_disabled == true, "Alarm must be marked disabled")
	assert(stage.is_alarm_audio_playing() == false, "Alarm siren must stop immediately when alarm is disabled")
	assert(audio_player.playing == false, "AudioStreamPlayer3D playing state must be false")
	print("[Stage07AlarmAudioTest] PASS: Alarm audio stopped immediately on deactivation.")

	# -------------------------------------------------------------
	# STEP 5: VERIFY PERSISTENT SILENCE & RE-TRIGGER REJECTION
	# -------------------------------------------------------------
	print("[Stage07AlarmAudioTest] Verifying redundant interactions remain silent...")
	# Second interact call must return false and NOT restart sound
	var second_interact = stage.interact_with_alarm()
	assert(second_interact == false, "Redundant alarm interaction must be rejected")
	assert(stage.is_alarm_audio_playing() == false, "Alarm audio must remain stopped")

	# Manual attempt to start alarm while disabled must be rejected
	stage._start_alarm_audio()
	assert(stage.is_alarm_audio_playing() == false, "Calling _start_alarm_audio while disabled must not start sound")
	print("[Stage07AlarmAudioTest] PASS: Post-disable re-trigger protection verified.")

	print("\n[Stage07AlarmAudioTest] ALL STAGE 07 ALARM AUDIO CHECKS PASSED.")
	quit(0)
