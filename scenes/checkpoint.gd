extends Area2D

@export var radius: float = 20.0
var activated := false
var player: Node2D

func _ready() -> void:
	$CollisionShape2D.shape.radius = radius
	body_entered.connect(_on_body_entered)
	player = get_tree().get_first_node_in_group("player")

func _process(_delta: float) -> void:
	if player:
		print("dist: ", global_position.distance_to(player.global_position))

func _on_body_entered(body: Node2D) -> void:
	print("something entered: ", body.name)
	if activated:
		return
	if body.has_method("take_damage"):
		body.last_checkpoint = global_position
		activated = true
		print("checkpoint saved at: ", global_position)
