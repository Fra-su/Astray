extends Area2D

var activated := false
var player: Node2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	player = get_tree().get_first_node_in_group("player")

func _on_body_entered(body: Node2D) -> void:
	if activated:
		return
	if body.has_method("take_damage"): #stupid way of checking if its the player
		body.last_checkpoint = global_position
		activated = true
