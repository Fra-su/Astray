extends Node2D

@onready var player: CharacterBody2D = $"../.."
@onready var hearts: Array = [$"Heart 1", $"Heart 2", $"Heart 3", $"Heart 4", $"Heart 5"]

var health := 5
var max_health := 5

func _ready() -> void:
	player.damaged.connect(damage_player)

func damage_player() -> void:
	if health <= 0: #Cannot damage if health is less than 0.
		return

	health -= 1
	# damages the heart on the right first
	hearts[health].take_damage()

func heal(amount: int = 1) -> void: #For later healing use
	for i in amount:
		if health >= max_health:
			return
		hearts[health].restore()
		health += 1
