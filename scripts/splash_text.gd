extends CanvasLayer

@export var display_text := "Area Name"
@export var font_size := 24
@export var fade_in_duration := 0.6
@export var hold_duration := 2.5
@export var fade_out_duration := 0.6
@export var min_start_delay := 0.5 # random delay before the fade-in begins, so it doesn't pop the instant the room loads
@export var max_start_delay := 1.0
@export var autoplay_on_ready := true # if false, call play() manually instead of firing on scene load

@onready var label: Label = $Label

func _ready() -> void:
	label.text = display_text
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate.a = 0.0

	if autoplay_on_ready:
		play()

## call this manually if autoplay_on_ready is false (e.g. triggered by an Area2D instead of on room load)
func play() -> void:
	label.text = display_text
	label.add_theme_font_size_override("font_size", font_size)

	var delay := randf_range(min_start_delay, max_start_delay)
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout

	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, fade_in_duration)
	tween.tween_interval(hold_duration)
	tween.tween_property(label, "modulate:a", 0.0, fade_out_duration)
