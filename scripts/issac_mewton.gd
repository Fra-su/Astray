extends CharacterBody2D

## Place one instance of this scene in mewton_house.tscn (required_state = AT_HOME) and
## another in town_room.tscn (required_state = AT_WORK). Whichever instance doesn't match
## MewtonState.current_state disables itself entirely on _ready() - only one is ever "real"
## at a time, giving the illusion that Issac himself moved between the two locations.
@export var required_state: MewtonState.State = MewtonState.State.AT_HOME

# wander area - relative to wherever this instance is placed in the editor, so you can
# just drop the scene down and tune these two numbers per-location without recalculating
# absolute coordinates
@export var wander_min_x := -150.0
@export var wander_max_x := 150.0

@export var walk_speed := 50.0
@export var gravity := 1100.0

# how long he stands still "looking at stuff" vs how long he walks per leg of wandering
@export var min_idle_duration := 1.5
@export var max_idle_duration := 4.5
@export var min_walk_duration := 1.0
@export var max_walk_duration := 3.0

# a little humanizing touch - sometimes glances the other direction while idle,
# like someone actually looking around a room rather than freezing in place
@export var look_around_chance := 0.4

@export var prompt_text := "Talk"
@export var prompt_fade_duration := 0.3
@export var prompt_offset := Vector2(0, -40)

enum LocalState { IDLE, WALKING }
var local_state := LocalState.IDLE
var state_timer := 0.0
var walk_target_x := 0.0
var spawn_x := 0.0

var player_in_range := false
var player_ref: CharacterBody2D
var prompt_tween: Tween

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shop_trigger: Area2D = $ShopTrigger
@onready var prompt_label: Label = $NpcUI/TalkPrompt

func _ready() -> void:
	if MewtonState.current_state != required_state:
		# this isn't where Issac currently is - disable entirely, the other instance is the real one
		visible = false
		set_physics_process(false)
		set_process(false)
		shop_trigger.monitoring = false
		$CollisionShape2D.disabled = true
		return

	spawn_x = global_position.x
	prompt_label.modulate.a = 0.0
	prompt_label.visible = false

	shop_trigger.body_entered.connect(_on_shop_trigger_body_entered)
	shop_trigger.body_exited.connect(_on_shop_trigger_body_exited)

	_enter_idle()

func _enter_idle() -> void:
	local_state = LocalState.IDLE
	state_timer = randf_range(min_idle_duration, max_idle_duration)
	sprite.play("idle")
	if randf() < look_around_chance:
		sprite.flip_h = not sprite.flip_h # glance the other way for a moment - small realism touch

func _enter_walk() -> void:
	local_state = LocalState.WALKING
	state_timer = randf_range(min_walk_duration, max_walk_duration)
	walk_target_x = spawn_x + randf_range(wander_min_x, wander_max_x)
	sprite.flip_h = walk_target_x < global_position.x
	sprite.play("walk")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	state_timer -= delta

	if local_state == LocalState.IDLE:
		velocity.x = 0.0
		if state_timer <= 0.0:
			_enter_walk()
	else: # WALKING
		var dir := signf(walk_target_x - global_position.x)
		velocity.x = dir * walk_speed
		var reached := absf(walk_target_x - global_position.x) < 4.0
		if reached or state_timer <= 0.0:
			_enter_idle()

	move_and_slide()

func _process(_delta: float) -> void:
	if not prompt_label.visible:
		return
	var screen_pos: Vector2 = get_viewport().canvas_transform * (global_position + prompt_offset)
	prompt_label.position = screen_pos - prompt_label.size / 2.0

func _on_shop_trigger_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		player_ref = body
		player_in_range = true
		_show_prompt()

func _on_shop_trigger_body_exited(body: Node2D) -> void:
	if body == player_ref:
		player_in_range = false
		_hide_prompt()

func _show_prompt() -> void:
	prompt_label.text = prompt_text
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
	if player_in_range and (event.is_action_pressed("up") or event.is_action_pressed("con_up")):
		open_shop()

## scaffolding only - hook up the actual shop UI here later
func open_shop() -> void:
	pass # TODO: implement shop UI
