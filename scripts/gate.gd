extends StaticBody2D

## Solid gate that blocks the player until a linked Lever hits open(). Once opened,
## it stays open forever for the room - persisted in GameState keyed by this room's
## own scene path, so there's no manual ID to configure as long as there's only one
## gate per room.

@export var tile_size := 64.0   # how big one tile is in world units (16px sprite x4 scale = 64 by default - adjust to match your project)
@export var rise_tiles := 3     # how many tiles it rises before disappearing
@export var rise_duration := 0.6
@export var behind_tiles_z_index := 0 # match your background's z_index; if walls share the same z_index, either bump walls to 1 or reorder this node between background and walls in the scene tree instead

var gate_id := ""
var is_open := false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	z_index = behind_tiles_z_index
	gate_id = get_gate_id()

	if GameState.is_gate_open(gate_id):
		_set_open_instantly()

func get_gate_id() -> String:
	return get_tree().current_scene.scene_file_path

## call this from the linked Lever when it's struck
func open() -> void:
	if is_open:
		return
	is_open = true
	GameState.open_gate(gate_id)

	# disable collision immediately - the player can walk through as soon as it
	# starts rising, rather than waiting for the rise to finish
	collision_shape.disabled = true

	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - tile_size * rise_tiles, rise_duration)
	await tween.finished

	visible = false
	queue_free() # permanently gone now - if this room loads again, a fresh Gate instance is
				 # created from the scene file and immediately hides itself via _set_open_instantly()

func _set_open_instantly() -> void:
	is_open = true
	collision_shape.disabled = true
	visible = false
