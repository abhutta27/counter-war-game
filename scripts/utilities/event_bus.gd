extends Node
## EventBus.gd
## Global Autoload Event Bus for decoupled communication across systems.
## Prevents direct spaghetti dependencies between Player, Enemies, UI, Audio, and Level.

# ==============================================================================
# 1. GAME FLOW & STATE SIGNALS
# ==============================================================================
signal state_change_requested(new_state: int)
signal state_changed(new_state: int, previous_state: int)
signal level_load_requested(level_id: int)
signal level_started(level_id: int)
signal level_completed(level_id: int, victory: bool, stats: Dictionary)
signal game_paused(is_paused: bool)

# ==============================================================================
# 2. COMBAT & DAMAGE SIGNALS
# ==============================================================================
signal damage_applied(damage_info: RefCounted)
signal hit_registered(victim: Node, is_critical: bool, hit_pos: Vector3)
signal entity_eliminated(victim: Node, killer: Node, is_critical: bool)

# ==============================================================================
# 3. PLAYER & WEAPON SIGNALS
# ==============================================================================
signal player_spawned(player_node: CharacterBody3D)
signal player_health_updated(current_hp: int, max_hp: int)
signal player_eliminated()
signal weapon_fired(weapon_name: String)
signal weapon_reloaded(weapon_name: String)
signal ammo_updated(current_ammo: int, max_ammo: int)
signal weapon_switched(new_weapon_name: String)

# ==============================================================================
# 4. ENEMY & TARGET SIGNALS
# ==============================================================================
signal enemy_spawned(enemy_node: Node)
signal enemy_state_changed(enemy_node: Node, new_state: int)
signal target_spawned(target_node: Node)
signal target_hit(target_node: Node, is_headshot: bool)
signal target_eliminated(target_node: Node)

# ==============================================================================
# 5. SCORING & METRIC SIGNALS
# ==============================================================================
signal score_updated(current_score: int)
signal metrics_updated(shots_fired: int, shots_hit: int, accuracy: float)

# ==============================================================================
# 6. AUDIO & FEEDBACK REQUESTS
# ==============================================================================
signal audio_play_requested(sound_name: String, extra_param: Variant)
signal camera_shake_requested(trauma: float)
