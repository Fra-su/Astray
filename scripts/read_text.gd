extends Area2D

@export var lore_lines: Array[String] = [
	"In darkness, we found silence.",
	"In silence, we found peace.",
]
@export var prompt_text := "Read"
@export var prompt_fade_duration := 0.3
@export var prompt_offset := Vector2(0, -40) # how far above the statue (in world units) the prompt sits
@export var text_font_size := 28
@export var line_fade_duration := 1.0   # how long each individual line takes to fade in
@export var line_stagger_delay := 0.8   # pause before each line starts fading in (including the first)
@export var text_fade_out_duration := 0.5 # how long the whole text block takes to fade out on exit
@export var screen_fade_duration := 0.6 # how long the black screen fade takes, both in and out
@export var stick_up_deadzone := 0.3     # minimum stick tilt before the controller trigger can fire at all
@export var stick_up_cone_degrees := 45.0 # half-angle either side of straight up (90 total) within which the controller trigger fires
var was_stick_up := false

var player_in_range := false
var reading := false
var can_exit := false
var skip_requested := false
var player_ref: CharacterBody2D
var prompt_tween: Tween

@onready var prompt_label: Label = $LoreUI/ReadPrompt
@onready var fade_rect: ColorRect = $LoreUI/Fade
@onready var text_container: VBoxContainer = $LoreUI/TextContainer
@onready var line_labels: Array[Label] = [
	$LoreUI/TextContainer/Line1,
	$LoreUI/TextContainer/Line2,
	$LoreUI/TextContainer/Line3,
	$LoreUI/TextContainer/Line4,
	$LoreUI/TextContainer/Line5,
	$LoreUI/TextContainer/Line6,
]

func _ready() -> void:
	prompt_label.text = prompt_text
	prompt_label.modulate.a = 0.0
	prompt_label.visible = false

	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_container.visible = false
	text_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for label in line_labels:
		label.visible = false
		label.modulate.a = 0.0
		label.add_theme_font_size_override("font_size", text_font_size)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if player_in_range and not reading:
		var stick := Vector2(Input.get_axis("con_left", "con_right"), Input.get_axis("con_up", "con_down"))
		var tilted_enough := stick.length() >= stick_up_deadzone
		var stick_up_now := tilted_enough and (absf(stick.angle_to(Vector2.UP)) <= deg_to_rad(stick_up_cone_degrees) or absf(stick.angle_to(Vector2.DOWN)) <= deg_to_rad(stick_up_cone_degrees))
		if stick_up_now and not was_stick_up:
			start_reading()
		was_stick_up = stick_up_now
	else:
		was_stick_up = false

	if not prompt_label.visible:
		return
	var screen_pos: Vector2 = get_viewport().canvas_transform * (global_position + prompt_offset)
	prompt_label.position = screen_pos - prompt_label.size / 2.0

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not reading:
		player_ref = body
		player_in_range = true
		_show_prompt()

func _on_body_exited(body: Node2D) -> void:
	if body == player_ref:
		player_in_range = false
		_hide_prompt()

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
	if player_in_range and not reading and (event.is_action_pressed("up") or event.is_action_pressed("down")):
		start_reading()
		get_viewport().set_input_as_handled()
	elif reading and not can_exit and _is_any_key_or_button_press(event):
		skip_requested = true
		get_viewport().set_input_as_handled()
	elif reading and can_exit and _is_any_key_or_button_press(event):
		exit_reading()
		get_viewport().set_input_as_handled()

func _is_any_key_or_button_press(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return true
	if event is InputEventMouseButton and event.pressed:
		return true
	if event is InputEventJoypadButton and event.pressed:
		return true
	return false

func start_reading() -> void:
	reading = true
	can_exit = false
	_hide_prompt()

	if player_ref:
		player_ref.transition_locked = true
		player_ref.velocity = Vector2.ZERO

	var fade_tween := create_tween()
	fade_tween.tween_property(fade_rect, "color:a", 1.0, screen_fade_duration)
	await fade_tween.finished

	_assign_text_lines()
	text_container.modulate.a = 1.0
	text_container.visible = true
	await _reveal_lines()

	can_exit = true

func _assign_text_lines() -> void:
	for i in line_labels.size():
		var label := line_labels[i]
		if i < lore_lines.size():
			label.text = lore_lines[i]
			label.visible = true
			label.modulate.a = 0.0
		else:
			label.visible = false

func _reveal_lines() -> void:
	skip_requested = false
	for label in line_labels:
		if not label.visible:
			continue

		if not skip_requested:
			await _interruptible_wait(line_stagger_delay)

		if skip_requested:
			label.modulate.a = 1.0
			continue

		var tween := create_tween()
		tween.tween_property(label, "modulate:a", 1.0, line_fade_duration)

		if not skip_requested:
			await _interruptible_wait(line_fade_duration) # wait for this line to fully finish before the next one even starts its delay

	skip_requested = false # reset so the next press exits instead of skipping again

func _interruptible_wait(duration: float) -> void:
	var elapsed := 0.0
	while elapsed < duration and not skip_requested:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

func exit_reading() -> void:
	reading = false
	can_exit = false

	var text_tween := create_tween()
	text_tween.tween_property(text_container, "modulate:a", 0.0, text_fade_out_duration)
	await text_tween.finished

	var fade_tween := create_tween()
	fade_tween.tween_property(fade_rect, "color:a", 0.0, screen_fade_duration)
	await fade_tween.finished

	text_container.visible = false
	for label in line_labels:
		label.modulate.a = 0.0
	if player_ref:
		player_ref.transition_locked = false
