extends StaticBody2D

## Place this on the accessible side of a shortcut gate. Link it to the Gate node
## in the same room via the "gate" export. Hitting it with the player's attack
## (reuses the same take_hit() interface enemies/corpses use) permanently opens
## the gate - the gate itself handles persisting that across room revisits.

@export var gate: NodePath
@export var activated_animation := "activated" # optional - plays once when hit, if it exists

var triggered := false
var gate_node: Node

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if gate != NodePath():
		gate_node = get_node_or_null(gate)

	# if this room's gate was already opened on a previous visit, show the lever
	# as already-activated immediately, no need to replay the pull animation
	if gate_node and gate_node.has_method("get_gate_id") and GameState.is_gate_open(gate_node.get_gate_id()):
		_show_activated_instantly()

func take_hit(_amount: int = 1) -> void:
	if triggered:
		return
	triggered = true

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(activated_animation):
		sprite.play(activated_animation)

	if gate_node and gate_node.has_method("open"):
		gate_node.open()

func _show_activated_instantly() -> void:
	triggered = true
	if sprite and sprite.sprite_frames:
		var frame_count: int = sprite.sprite_frames.get_frame_count(activated_animation) if sprite.sprite_frames.has_animation(activated_animation) else 0
		if frame_count > 0:
			sprite.stop()
			sprite.animation = activated_animation
			sprite.frame = frame_count - 1
