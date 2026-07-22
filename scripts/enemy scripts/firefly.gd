extends Node2D

func _ready():
	$AnimatedSprite2D.frame = randi_range(0, $AnimatedSprite2D.sprite_frames.get_frame_count("default"))
