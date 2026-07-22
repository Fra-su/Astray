extends Node
var next_spawn_position := Vector2.ZERO
var has_pending_spawn := false
var push_velocity := Vector2.ZERO # simple one-shot exit velocity set by doors
var current_health := 5
var max_health := 5
var current_energy := 0
var carried_facing_left := false
signal coins_gained(amount: int) # the coin popup UI listens for this
var total_coins := 0
var collected_coins: Dictionary = {} # keyed by a unique per-coin id, so coins don't respawn on room re-entry
# respawn / death system
var last_spawn_position := Vector2(754, 576) # default fallback until the player rests at a bench - matches the tutorial's actual starting position
var last_spawn_scene := "res://scenes/rooms/tutorial.tscn" # the tutorial's starting point is the default first spawnpoint
var pending_fade_in := false # set true by the dying player right before the scene change; the fresh player instance checks this to fade the screen back in
## call this from a Bench (on interact) or from the end of a cutscene to set where the player respawns
func set_spawnpoint(position: Vector2, scene_path: String) -> void:
	last_spawn_position = position
	last_spawn_scene = scene_path
# one-way shortcut gates (lever on one side permanently opens a gate on the other) -
# keyed by the room's own scene path, since there's never more than one per room.
# this persists for the current play session (survives room transitions) but not
# a full app restart - hook this into a save-file system later if you build one
var opened_gates: Dictionary = {}
func is_gate_open(gate_id: String) -> bool:
	return opened_gates.get(gate_id, false)
func open_gate(gate_id: String) -> void:
	opened_gates[gate_id] = true
func add_coins(amount: int) -> void:
	total_coins += amount
	coins_gained.emit(amount)
func is_coin_collected(coin_id: String) -> bool:
	return collected_coins.get(coin_id, false)
func mark_coin_collected(coin_id: String) -> void:
	collected_coins[coin_id] = true
