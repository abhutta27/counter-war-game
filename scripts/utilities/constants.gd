class_name GameConstants
extends Node
## GameConstants.gd
## Central game constants, collision masks, groups, enums, and configurations.

# ==============================================================================
# COLLISION LAYERS (Bit flags and integers)
# ==============================================================================
const LAYER_WORLD: int = 1         # Layer 1: Static geometry, terrain, walls
const LAYER_PLAYER: int = 2        # Layer 2: Player capsule
const LAYER_ENEMY: int = 3         # Layer 3: Enemy bodies
const LAYER_HEADSHOT: int = 4      # Layer 4: Precision head hitboxes
const LAYER_TARGET: int = 5        # Layer 5: Shooting range / mission targets
const LAYER_PROJECTILE: int = 6    # Layer 6: Bullets & projectiles

# ==============================================================================
# NODE GROUPS
# ==============================================================================
const GROUP_PLAYER: String = "player"
const GROUP_ENEMIES: String = "enemies"
const GROUP_TARGETS: String = "targets"
const GROUP_HEADSHOT: String = "headshot_hitbox"
const GROUP_INTERACTABLE: String = "interactable"

# ==============================================================================
# DAMAGE TYPES
# ==============================================================================
enum DamageType {
	BULLET,
	EXPLOSIVE,
	MELEE,
	ENVIRONMENT
}

# ==============================================================================
# WEAPON TYPES
# ==============================================================================
enum WeaponType {
	ASSAULT_RIFLE,
	PISTOL,
	REVOLVER,
	SHOTGUN,
	SMG,
	SNIPER,
	LMG
}

# ==============================================================================
# GAME STATES (Core flow)
# ==============================================================================
enum GameState {
	BOOT,
	MAIN_MENU,
	LOADING,
	PLAYING,
	PAUSED,
	MISSION_COMPLETE,
	MISSION_FAILED,
	GAME_OVER
}

# ==============================================================================
# PLAYER MOVEMENT STATES
# ==============================================================================
enum MovementState {
	IDLE,
	WALKING,
	RUNNING,
	SPRINTING,
	CROUCHING,
	JUMPING,
	FALLING,
	DEAD
}

# ==============================================================================
# ENEMY AI STATES
# ==============================================================================
enum EnemyState {
	IDLE,
	PATROL,
	INVESTIGATE,
	ALERT,
	CHASE,
	TAKE_COVER,
	ATTACK,
	SEARCH,
	RETREAT,
	DEAD
}

# ==============================================================================
# TARGET TYPES
# ==============================================================================
enum TargetType {
	STATIC,
	MOVING,
	ENEMY,
	PRIORITY,
	MISSION
}