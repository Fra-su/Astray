extends Node2D
@onready var player: CharacterBody2D = $"../.."
@onready var hearts: Array = [$"Heart 1", $"Heart 2", $"Heart 3", $"Heart 4", $"Heart 5"]
var health := 5
var max_health := 5
func _ready() -> void:
	print("health_ui player resolved to: ", player)
	player.damaged.connect(damage_player)
	player.healed.connect(heal)
	# sync with persisted health from GameState (carries across scene/room loads)
	max_health = GameState.max_health
	health = GameState.current_health
	# instantly reflect any hearts already lost, no animation on load
	for i in max_health:
		if i < health:
			hearts[i].force_full()
		else:
			hearts[i].force_empty()
func damage_player() -> void:
	if health <= 0: #Cannot damage if health is less than 0.
		return
	health -= 1
	# damages the heart on the right first
	hearts[health].take_damage()
	GameState.current_health = health
	if health <= 0:
		player.die()
func heal(amount: int = 1) -> void: #For later healing use
	for i in amount:
		if health >= max_health:
			return
		hearts[health].restore()
		health += 1
	GameState.current_health = health
