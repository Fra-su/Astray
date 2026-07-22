extends Area2D

@export var target_scene: String = "room_2"
@export var spawn_position := Vector2.ZERO
@export var area_name: String = ""
@export var push_velocity := Vector2.ZERO # velocity applied once when arriving in the new room

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage") and not body.transition_locked:
		GameState.next_spawn_position = spawn_position
		GameState.has_pending_spawn = true
		GameState.push_velocity = push_velocity
		GameState.carried_facing_left = body.get_node("AnimatedSprite2D").flip_h
		body.transition_locked = true
		Transition.fade_to_scene("res://scenes/rooms/" + target_scene + ".tscn", area_name)
