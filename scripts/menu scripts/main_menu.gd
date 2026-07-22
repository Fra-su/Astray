class_name MainMenu
extends Control

@onready var start_button: Button = $MarginContainer/HBoxContainer/VBoxContainer/Start_Button as Button
@onready var exit_button: Button = $MarginContainer/HBoxContainer/VBoxContainer/Exit_Button as Button
@onready var options_button: Button = $MarginContainer/HBoxContainer/VBoxContainer/Options_Button as Button
@onready var options_menu: Control = $Options_Menu as OptionsMenu
@onready var margin_container: MarginContainer = $MarginContainer as MarginContainer
@onready var start_level = preload("res://scenes/rooms/tutorial.tscn") as PackedScene

func _ready():
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_tree().root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND # fills the window completely - default (KEEP) preserves aspect ratio with black bars, which was causing the pillarboxing
	_force_rescale()
	handle_connecting_signals()

## setting content_scale properties doesn't always trigger an immediate visual re-layout on its own -
## nudging the window size (even by 0) forces Godot to recompute the stretch/letterbox transform right away
func _force_rescale() -> void:
	var current_size := get_tree().root.size
	get_tree().root.size = current_size

func on_button_down() -> void:
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().change_scene_to_packed(start_level)

func on_options_pressed() -> void:
	margin_container.visible = false
	options_menu.set_process(true)
	options_menu.visible = true

func on_exit_pressed() -> void:
	get_tree().quit()

func on_exit_options_menu() -> void:
	margin_container.visible = true
	options_menu.visible = false

func handle_connecting_signals() -> void:
	start_button.button_down.connect(on_button_down)
	options_button.button_down.connect(on_options_pressed)
	exit_button.button_down.connect(on_exit_pressed)
	options_menu.exit_options_menu.connect(on_exit_options_menu)
