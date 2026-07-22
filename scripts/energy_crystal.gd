extends Sprite2D

@export var threshold := 16
@onready var player: CharacterBody2D = $"../../../.." # adjust to match actual scene depth, same pattern as EnergyBarMiddle

func _ready() -> void:
	player.energy_changed.connect(_on_energy_changed)
	_on_energy_changed(player.energy) # sync immediately on load

func _on_energy_changed(current_energy: int) -> void:
	visible = current_energy >= threshold
