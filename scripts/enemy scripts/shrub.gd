extends CharacterBody2D

@export var speed := 80.0
@export var max_health := 11
var gravity := 1100.0
var direction := 1.0
var move_timer := 0.0
var turn_timer := 0.0
var turning := false
var turn_duration := 0.08 # how long the turn frame shows in seconds

@export var knockback_force := 1000.0     # initial push, tapers off quickly
@export var knockback_hop := 150.0       # small upward pop for extra impact feel
@export var knockback_duration := 0.12  # short so it doesn't slide far
var knockback_timer := 0.0

@export var death_launch_force := 500.0        # strong horizontal punch on death
@export var death_launch_hop := 600.0          # strong vertical pop on death
@export var death_frame_index := 3 # which frame of the "die" animation to use for the corpse

@onready var hurtbox: Area2D = $Hurtbox
@onready var enemy_health: Node = $Enemy_Health
@onready var hit_flash: Node = $HitFlash
@onready var hazard_detector: Area2D = $HazardDetector
var dead_pending := false

func _ready():
	$AnimatedSprite2D.play("default")
	if $AnimatedSprite2D.material:
		$AnimatedSprite2D.material = $AnimatedSprite2D.material.duplicate()
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	enemy_health.hurt.connect(_on_hurt)
	enemy_health.died.connect(_on_died)
	hazard_detector.body_entered.connect(_on_hazard_entered)

	enemy_health.max_health = max_health
	enemy_health.health = max_health

func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(self)

func _on_hazard_entered(body: Node2D) -> void:
	if body.is_in_group("hazard"):
		take_hit(999)

func take_hit(amount: int = 1) -> void:
	enemy_health.take_hit(amount)

func _on_hurt(_current_health: int) -> void:
	hit_flash.flash($AnimatedSprite2D)
	apply_knockback()

func _on_died() -> void:
	dead_pending = true
	hurtbox.set_deferred("monitoring", false)
	hazard_detector.set_deferred("monitoring", false)
	velocity = Vector2.ZERO

	$AnimatedSprite2D.play("die")
	await $AnimatedSprite2D.animation_finished

	var push_dir := direction
	var player = get_tree().get_first_node_in_group("player")
	if player:
		push_dir = sign(global_position.x - player.global_position.x)
		if push_dir == 0:
			push_dir = 1.0

	call_deferred("_spawn_corpse", push_dir)
	queue_free()

func _spawn_corpse(push_dir: float) -> void:
	var corpse := preload("res://scenes/enemies/enemy_corpse.tscn").instantiate()
	get_parent().add_child(corpse)
	corpse.global_position = global_position
	corpse.setup(
		$AnimatedSprite2D.sprite_frames.get_frame_texture("die", death_frame_index),
		$AnimatedSprite2D.flip_h,
		Vector2(push_dir * death_launch_force, -death_launch_hop),
		"Shrub"
	)

func apply_knockback() -> void:
	var push_dir := direction # fallback if player can't be found
	var player = get_tree().get_first_node_in_group("player")
	if player:
		push_dir = sign(global_position.x - player.global_position.x)
		if push_dir == 0:
			push_dir = 1.0

	velocity.x = push_dir * knockback_force
	velocity.y = -knockback_hop
	knockback_timer = knockback_duration

func _physics_process(delta):
	if dead_pending:
		return # frozen in place while the death animation plays out

	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, knockback_force / knockback_duration * delta)
		move_and_slide()
		return # while airborne, only gravity + residual knockback apply, no walking logic

	if knockback_timer > 0.0:
		knockback_timer -= delta
		# ease the knockback out quickly instead of holding constant speed
		velocity.x = move_toward(velocity.x, 0.0, knockback_force / knockback_duration * delta)
		move_and_slide()
		return # skip normal movement/turning logic while being knocked back

	if turning:
		turn_timer -= delta
		if turn_timer <= 0:
			turning = false
			$AnimatedSprite2D.play("default")
	elif $"Wall Check".is_colliding() or not $"Floor Check".is_colliding():
		direction *= -1.0
		$"Wall Check".target_position.x *= -1
		$"Floor Check".position.x *= -1
		$AnimatedSprite2D.flip_h = direction < 0
		turning = true
		turn_timer = turn_duration
		$AnimatedSprite2D.play("shrub turn")
	if not turning:
		move_timer += delta
		var step_time = 4.0 / speed
		if move_timer >= step_time:
			move_timer -= step_time
			position.x += 4.0 * direction
			position = Vector2i(round(position / 4)) * 4
	velocity.x = 0
	move_and_slide()
