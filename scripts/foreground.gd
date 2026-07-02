extends TileMapLayer

@onready var player: Node2D = get_tree().get_first_node_in_group("player")

func _process(_delta):
	if not player:
		return
	var vp_transform = get_viewport().get_canvas_transform()
	var converted = vp_transform * player.global_position
	material.set_shader_parameter("player_pos", converted)
