extends Sprite2D

@onready var player: CharacterBody2D = $"../../../.." # EnergyBarMiddle -> EnergyBar -> HealthUI -> Canvas -> player

@export var glide_duration := 0.3

var displayed_energy := 0.0
var energy_tween: Tween

func _ready() -> void:
	if not material:
		push_warning("EnergyBarMiddle needs a ShaderMaterial using energy_bar.gdshader assigned")
		return

	if texture:
		material.set_shader_parameter("bar_width_px", float(texture.get_width()))

	player.energy_changed.connect(_on_energy_changed)

	# sync immediately on load, no glide needed for the initial value
	displayed_energy = float(player.energy)
	visible = player.energy >= 2
	material.set_shader_parameter("energy_pixels", displayed_energy)

func _on_energy_changed(current_energy: int) -> void:
	var target := float(current_energy)

	if energy_tween:
		energy_tween.kill()

	# stay visible for the whole glide if either the start or end value would show something
	if current_energy >= 2 or displayed_energy >= 2:
		visible = true

	energy_tween = create_tween()
	energy_tween.tween_method(_set_displayed_energy, displayed_energy, target, glide_duration)
	energy_tween.set_trans(Tween.TRANS_SINE)
	energy_tween.set_ease(Tween.EASE_IN_OUT)

	if current_energy < 2:
		energy_tween.tween_callback(func(): visible = false)

func _set_displayed_energy(value: float) -> void:
	displayed_energy = value
	material.set_shader_parameter("energy_pixels", value)
