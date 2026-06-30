extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func take_damage() -> void:
	sprite.play("take_damage")
	await sprite.animation_finished
	sprite.stop()
	sprite.frame = 11 #Switches to the empty frame

func restore() -> void:
	sprite.frame = 1 #Switches to the one with the fulll heart
