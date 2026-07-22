extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func take_damage() -> void:
	sprite.play("take_damage")
	await sprite.animation_finished
	sprite.stop()
	sprite.frame = 11 #Switches to the empty frame

func restore() -> void:
	sprite.animation = "take_damage"
	sprite.frame = 0 #Switches to the one with the full heart

## instantly set state with no animation, used when syncing hearts on scene load
func force_full() -> void:
	sprite.animation = "take_damage"
	sprite.stop()
	sprite.frame = 0

func force_empty() -> void:
	sprite.animation = "take_damage"
	sprite.stop()
	sprite.frame = 11
