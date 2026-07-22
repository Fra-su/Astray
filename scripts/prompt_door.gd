extends Area2D

@export var target_scene: String = "room_2"
@export var spawn_position := Vector2.ZERO
@export var area_name: String = ""
@export var push_velocity := Vector2.ZERO # velocity applied once when arriving in the new room

@export var prompt_text := "Enter"
@export var prompt_fade_duration := 0.3
@export var prompt_offset := Vector2(0, -40) # how far above the door (in world units) the prompt sits
@export var stick_deadzone := 0.3     # minimum stick tilt before the controller trigger can fire at all
@export var stick_cone_degrees := 45.0 # half-angle either side of straight up/down (90 total) within which the controller trigger fires

var player_in_range := false
var player_ref: CharacterBody2D
var prompt_tween: Tween
var was_stick_triggered := false
var entering := false # guard against double-triggering the transition

@onready var prompt_label: Label = $DoorUI/EnterPrompt

func _ready() -> void:
	prompt_label.text = prompt_text
	prompt_label.modulate.a = 0.0
	prompt_label.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage") and not entering:
		player_ref = body
		player_in_range = true
		_show_prompt()

func _on_body_exited(body: Node2D) -> void:
	if body == player_ref:
		player_in_range = false
		_hide_prompt()

func _process(_delta: float) -> void:
	# controller stick check - continuous polling since analog input has no clean "just pressed" event
	if player_in_range and not entering:
		var stick := Vector2(Input.get_axis("con_left", "con_right"), Input.get_axis("con_up", "con_down"))
		var tilted_enough := stick.length() >= stick_deadzone
		var stick_triggered_now := tilted_enough and (absf(stick.angle_to(Vector2.UP)) <= deg_to_rad(stick_cone_degrees) or absf(stick.angle_to(Vector2.DOWN)) <= deg_to_rad(stick_cone_degrees))
		if stick_triggered_now and not was_stick_triggered:
			_enter_door()
		was_stick_triggered = stick_triggered_now
	else:
		was_stick_triggered = false

	if not prompt_label.visible:
		return
	var screen_pos: Vector2 = get_viewport().canvas_transform * (global_position + prompt_offset)
	prompt_label.position = screen_pos - prompt_label.size / 2.0

func _show_prompt() -> void:
	prompt_label.visible = true
	if prompt_tween:
		prompt_tween.kill()
	prompt_tween = create_tween()
	prompt_tween.tween_property(prompt_label, "modulate:a", 1.0, prompt_fade_duration)

func _hide_prompt() -> void:
	if prompt_tween:
		prompt_tween.kill()
	prompt_tween = create_tween()
	prompt_tween.tween_property(prompt_label, "modulate:a", 0.0, prompt_fade_duration)
	prompt_tween.tween_callback(func(): prompt_label.visible = false)

func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range or entering:
		return
	if event.is_action_pressed("up") or event.is_action_pressed("down"):
		_enter_door()

## identical to door.gd's _on_body_entered logic, just triggered by input instead of touch
func _enter_door() -> void:
	if not player_ref or player_ref.transition_locked:
		return
	entering = true
	_hide_prompt()

	GameState.next_spawn_position = spawn_position
	GameState.has_pending_spawn = true
	GameState.push_velocity = push_velocity
	GameState.carried_facing_left = player_ref.get_node("AnimatedSprite2D").flip_h
	player_ref.transition_locked = true
	Transition.fade_to_scene("res://scenes/rooms/" + target_scene + ".tscn", area_name)
