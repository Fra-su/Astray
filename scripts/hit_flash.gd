extends Node

@export var flash_color: Color = Color("#00c8df")
@export var flash_peak := 0.6      # how strong the flash gets (0-1)
@export var flash_in_time := 0.05
@export var flash_out_time := 0.1

func flash(sprite: CanvasItem) -> void:
	if not sprite.material:
		push_warning("hit_flash: target sprite has no ShaderMaterial assigned")
		return

	sprite.material.set_shader_parameter("flash_color", flash_color)

	var tween := create_tween()
	tween.tween_method(
		func(v): sprite.material.set_shader_parameter("flash_amount", v),
		0.0, flash_peak, flash_in_time
	)
	tween.tween_method(
		func(v): sprite.material.set_shader_parameter("flash_amount", v),
		flash_peak, 0.0, flash_out_time
	)
