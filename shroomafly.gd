extends CharacterBody2D

@export var max_health := 6

# hovering motion while idle (no player in range/sight)
@export var hover_amplitude := 8.0   # how far up/down it bobs, in pixels
@export var hover_speed := 2.0       # how fast the bob cycles
var hover_time := 0.0
var origin_y := 0.0

# aggressive chase behavior
@export var detection_radius := 300.0
@export var chase_speed := 160.0
@export var chase_acceleration := 250.0  # how quickly it speeds up toward the player
@export var chase_deceleration := 50.0   # how quickly it slows/drifts when not chasing
@export var los_mask := 1 # collision layer that blocks line of sight (usually solid ground/walls)
@export var require_line_of_sight := true # if false, chases through walls/obstacles once in range
@export var use_anchor_wander := false
@export var hover_wander_radius := 40.0
@export var hover_wander_speed := 25.0
@export var wander_retarget_interval := 1.5
var anchor_position := Vector2.ZERO
var wander_target := Vector2.ZERO
var wander_retarget_timer := 0.0

## call this after repositioning a freshly-spawned enemy (e.g. from a hive) so its idle
## hover/wander is centered on the correct point instead of wherever it briefly existed at _ready()
func set_anchor(pos: Vector2) -> void:
	anchor_position = pos
	origin_y = pos.y
	wander_target = pos
@export var use_directional_animations := true # if false, sprite never flips at all - used for Angry Firefly, which only has "default" and a symmetrical texture
@export var death_animation_name := "die" # which animation's frame is used for the corpse texture; set to "default" if no dedicated die animation exists
@export var corpse_label := "Shroomafly"
var player_ref: Node2D
var chasing := false

var gravity := 1100.0

@export var knockback_force := 700.0
@export var knockback_hop := 100.0
@export var knockback_duration := 0.12
var knockback_timer := 0.0

@export var death_launch_force := 400.0
@export var death_launch_hop := 500.0
@export var death_frame_index := 0 # which frame of the "die" animation to use for the corpse
@export var spawn_corpse_on_death := true # set false for enemies that shouldn't leave a corpse (e.g. Angry Firefly)

@onready var hurtbox: Area2D = $Hurtbox
@onready var enemy_health: Node = $Enemy_Health
@onready var hit_flash: Node = $HitFlash
@onready var hazard_detector: Area2D = $HazardDetector

func _ready():
	$AnimatedSprite2D.play("default")
	if $AnimatedSprite2D.material:
		$AnimatedSprite2D.material = $AnimatedSprite2D.material.duplicate()

	origin_y = position.y
	anchor_position = global_position
	wander_target = global_position
	player_ref = get_tree().get_first_node_in_group("player")

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
	hurtbox.set_deferred("monitoring", false)
	hazard_detector.set_deferred("monitoring", false)

	if spawn_corpse_on_death:
		var push_dir := 1.0
		if player_ref:
			push_dir = sign(global_position.x - player_ref.global_position.x)
			if push_dir == 0:
				push_dir = 1.0
		call_deferred("_spawn_corpse", push_dir)

	queue_free()

func _spawn_corpse(push_dir: float) -> void:
	var corpse := preload("res://scenes/enemies/enemy_corpse.tscn").instantiate()
	get_parent().add_child(corpse)
	corpse.global_position = global_position
	corpse.setup(
		$AnimatedSprite2D.sprite_frames.get_frame_texture(death_animation_name, death_frame_index),
		$AnimatedSprite2D.flip_h,
		Vector2(push_dir * death_launch_force, -death_launch_hop),
		corpse_label
	)

func apply_knockback() -> void:
	var push_dir := 1.0
	if player_ref:
		push_dir = sign(global_position.x - player_ref.global_position.x)
		if push_dir == 0:
			push_dir = 1.0

	velocity.x = push_dir * knockback_force
	velocity.y = -knockback_hop
	knockback_timer = knockback_duration

func has_line_of_sight_to(target: Node2D) -> bool:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	query.exclude = [self]
	query.collision_mask = los_mask
	var result := space_state.intersect_ray(query)
	return result.is_empty() # empty means nothing solid blocked the view

func _physics_process(delta):
	if knockback_timer > 0.0:
		# briefly interrupted from hovering/chasing while getting knocked back
		knockback_timer -= delta
		velocity.y += gravity * delta * 0.3 # light gravity pull during knockback, not full weight
		velocity.x = move_toward(velocity.x, 0.0, knockback_force / knockback_duration * delta)
		move_and_slide()
		return

	var in_range := player_ref and global_position.distance_to(player_ref.global_position) <= detection_radius
	var sighted := in_range and (not require_line_of_sight or has_line_of_sight_to(player_ref))

	if sighted:
		chasing = true
		_chase_player(delta)
	else:
		if chasing:
			origin_y = position.y # recenter the idle hover wherever the chase left off
		chasing = false
		_idle_hover(delta)

func _switch_animation(anim_name: String) -> void:
	if $AnimatedSprite2D.animation == anim_name:
		return
	var current_frame: int = $AnimatedSprite2D.frame
	$AnimatedSprite2D.play(anim_name)
	$AnimatedSprite2D.frame = current_frame

func _chase_player(delta: float) -> void:
	var to_player := player_ref.global_position - global_position
	var move_dir := to_player.normalized()
	var target_velocity := move_dir * chase_speed

	velocity = velocity.move_toward(target_velocity, chase_acceleration * delta)
	move_and_slide()

	if use_directional_animations:
		_switch_animation("right" if to_player.x >= 0 else "left")
	# else: intentionally does nothing - symmetrical textures (like Angry Firefly) never flip

func _idle_hover(delta: float) -> void:
	if use_anchor_wander:
		_wander(delta)
		return

	hover_time += delta * hover_speed
	position.y = origin_y + sin(hover_time) * hover_amplitude

	# let horizontal drift bleed off gradually instead of snapping to a stop
	velocity.x = move_toward(velocity.x, 0.0, chase_deceleration * delta)
	velocity.y = 0.0

	_switch_animation("default")

func _wander(delta: float) -> void:
	wander_retarget_timer -= delta
	if wander_retarget_timer <= 0.0:
		wander_retarget_timer = wander_retarget_interval
		var angle := randf() * TAU
		var dist := randf_range(0.0, hover_wander_radius)
		wander_target = anchor_position + Vector2(cos(angle), sin(angle)) * dist

	var to_target := wander_target - global_position
	if to_target.length() > 2.0:
		velocity = velocity.move_toward(to_target.normalized() * hover_wander_speed, chase_acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, chase_deceleration * delta)

	move_and_slide()
	_switch_animation("default")
