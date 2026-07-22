extends Node

@export var max_health := 3
var health := 0

signal died()
signal hurt(current_health: int)

func _ready() -> void:
	health = max_health

func take_hit(amount: int = 1) -> void:
	if health <= 0:
		return # already dead, ignore further hits

	health -= amount
	hurt.emit(health)

	if health <= 0:
		died.emit() # let the owning enemy handle its own death sequence
