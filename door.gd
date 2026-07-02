extends Area2D

@export var target_scene: String = "room_2"
@export var spawn_position := Vector2.ZERO
@export var area_name: String = ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		GameState.next_spawn_position = spawn_position
		GameState.has_pending_spawn = true
		GameState.carried_velocity = body.velocity
		body.transition_locked = true
		Transition.fade_to_scene("res://scenes/rooms/" + target_scene + ".tscn", area_name)
