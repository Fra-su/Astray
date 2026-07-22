extends RigidBody2D

@onready var sprite: Sprite2D = $Sprite2D

# per-enemy-type offset corrections, since different sprites have different
# amounts of empty padding in their frame canvas
const OFFSET_CORRECTIONS := {
	"Shrub": Vector2(0, -11),
	"Shroomafly": Vector2(0, 0),
}

func setup(texture: Texture2D, flip_h: bool, launch_velocity: Vector2, enemy_type: String = "") -> void:
	sprite.texture = texture
	sprite.flip_h = flip_h
	sprite.scale = Vector2(4, 4)
	sprite.offset = OFFSET_CORRECTIONS.get(enemy_type, Vector2.ZERO)
	sprite.modulate = Color(0.6, 0.6, 0.6, 0.85) # subtle darken, mostly opaque

	linear_velocity = launch_velocity
	angular_velocity = sign(launch_velocity.x) * randf_range(4.0, 8.0) # spin in the direction it's launched

func take_hit(_amount: int = 1) -> void:
	# corpses can still be punched around for fun, no health logic needed
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var push_dir = sign(global_position.x - player.global_position.x)
		apply_central_impulse(Vector2(push_dir * 400.0, -300.0))
