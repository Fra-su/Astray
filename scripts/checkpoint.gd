extends Area2D

var activated := false
var player: Node2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	player = get_tree().get_first_node_in_group("player")

func _on_body_entered(body: Node2D) -> void:
	# Check if the colliding body is the player
	if body == player: 
		body.last_checkpoint = global_position
		
		if not activated:
			activated = true
			# Optional: Play activation animation or sound effect here
