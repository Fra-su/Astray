extends CharacterBody2D

@export var max_health := 20  # tankier than a single Shrub/Shroomafly since it's meant to be whittled down over time

# spawning behavior - fires every time the hive takes damage, not just on death
@export var angry_firefly_scene: PackedScene = preload("res://scenes/enemies/angry_firefly.tscn")
@export var fireflies_per_hit_min := 1        # random range of how many spawn per individual hit
@export var fireflies_per_hit_max := 2
@export var idle_spawn_interval := 4.0        # naturally summons a firefly this often while idle, regardless of being hit
@export var idle_spawn_count := 1
@export var firefly_wander_radius := 90.0  # how far spawned fireflies wander from this hive while idle/unprovoked
var idle_spawn_timer := 0.0
@export var spawn_offset_radius := 24.0   # random scatter distance around the hive so spawns don't stack exactly on top of each other
@export var spawn_launch_speed := 80.0    # small pop of outward velocity so newly spawned fireflies don't spawn already touching the hive's hurtbox
@export var death_spawn_launch_speed := 220.0  # faster outward pop for the death burst, for an actual "explosion" feel
@export var max_alive_fireflies := 6      # soft cap so a long combo doesn't flood the room with fireflies; spawns are skipped once this is hit
@export var death_firefly_burst_count := 8  # how many fireflies explode out when the hive itself finally dies, ignores the alive-cap since it's a one-time event
var spawned_fireflies: Array[Node] = []   # tracked so we can prune dead ones and check the cap

@export var death_launch_force := 300.0
@export var death_launch_hop := 400.0
@export var death_frame_index := 0 # which frame of the death animation to use for the corpse
@export var death_animation_name := "die" # set to "default" if this enemy has no dedicated die animation
@export var corpse_spawn_offset := Vector2(0, 24) # nudge the corpse clear of the ceiling tile the hive is embedded against, so it doesn't spawn stuck inside solid geometry
var dead_pending := false

@onready var hurtbox: Area2D = $Hurtbox
@onready var enemy_health: Node = $Enemy_Health
@onready var hit_flash: Node = $HitFlash
@onready var hazard_detector: Area2D = $HazardDetector

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

## fires on every hit (not just death) - this is the hive's whole gimmick
func _on_hurt(current_health: int) -> void:
	hit_flash.flash($AnimatedSprite2D)
	if current_health > 0: # don't spawn more on the hit that kills it, _on_died handles that separately
		var count := randi_range(fireflies_per_hit_min, fireflies_per_hit_max)
		_spawn_angry_fireflies(count, false, spawn_launch_speed, true) # true = new spawns immediately go aggressive
		_provoke_all_fireflies() # any fireflies already out from this hive also go aggressive now

func _spawn_angry_fireflies(count: int, ignore_cap: bool = false, launch_speed: float = -1.0, provoke_on_spawn: bool = false) -> void:
	var speed := spawn_launch_speed if launch_speed < 0.0 else launch_speed
	_prune_dead_fireflies()
	for i in count:
		if not ignore_cap and spawned_fireflies.size() >= max_alive_fireflies:
			break # soft cap reached, skip remaining spawns this hit

		var angle := randf() * TAU
		var offset := Vector2(cos(angle), sin(angle)) * randf_range(0.0, spawn_offset_radius)

		# add_child/instantiate can't happen directly here - this is usually called
		# from _on_hurt, which fires during the attack hitbox's physics query flush
		call_deferred("_spawn_single_firefly", offset, speed, provoke_on_spawn)

func _spawn_single_firefly(offset: Vector2, speed: float, provoke_on_spawn: bool) -> void:
	var firefly := angry_firefly_scene.instantiate()
	get_parent().add_child(firefly)
	firefly.global_position = global_position + offset
	firefly.force_update_transform() # otherwise collision shapes (Hurtbox etc.) can lag a frame behind the visual position, causing an offset hitbox right after spawning

	if firefly is CharacterBody2D:
		firefly.velocity = offset.normalized() * speed if offset.length() > 0.1 else Vector2.UP * speed

	# force these regardless of the Angry Firefly scene's own Inspector settings, so a missed
	# checkbox in the editor can't cause fireflies to aggro unprovoked or hover around the wrong point
	if "aggro_only_when_provoked" in firefly:
		firefly.aggro_only_when_provoked = true
	if "use_anchor_wander" in firefly:
		firefly.use_anchor_wander = true
	if "hover_wander_radius" in firefly:
		firefly.hover_wander_radius = firefly_wander_radius
	if "spawn_corpse_on_death" in firefly:
		firefly.spawn_corpse_on_death = false
	if firefly.has_method("set_anchor"):
		firefly.set_anchor(global_position) # anchor to the hive itself, not the scattered spawn point

	if provoke_on_spawn and firefly.has_method("provoke"):
		firefly.provoke()

	spawned_fireflies.append(firefly)

func _provoke_all_fireflies() -> void:
	_prune_dead_fireflies()
	for f in spawned_fireflies:
		if f.has_method("provoke"):
			f.provoke()

func _prune_dead_fireflies() -> void:
	spawned_fireflies = spawned_fireflies.filter(func(f): return is_instance_valid(f))

func _on_died() -> void:
	dead_pending = true
	hurtbox.set_deferred("monitoring", false)
	hazard_detector.set_deferred("monitoring", false)
	velocity = Vector2.ZERO

	_spawn_angry_fireflies(death_firefly_burst_count, true, death_spawn_launch_speed, true) # explode outward, ignoring the alive-cap, and immediately aggressive

	if $AnimatedSprite2D.sprite_frames.has_animation(death_animation_name):
		$AnimatedSprite2D.play(death_animation_name)
		await $AnimatedSprite2D.animation_finished

	var push_dir := 1.0
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
	corpse.global_position = global_position + corpse_spawn_offset
	corpse.setup(
		$AnimatedSprite2D.sprite_frames.get_frame_texture(death_animation_name, death_frame_index),
		$AnimatedSprite2D.flip_h,
		Vector2(push_dir * death_launch_force, death_launch_hop), # positive Y (downward) - the hive hangs from the ceiling, so an upward pop would drive the corpse straight back into the ceiling tile it's embedded against
		"Firefly Hive"
	)

func _physics_process(delta):
	if dead_pending:
		return
	# stationary - no movement logic at all, just naturally summons fireflies over time
	idle_spawn_timer += delta
	if idle_spawn_timer >= idle_spawn_interval:
		idle_spawn_timer -= idle_spawn_interval
		_spawn_angry_fireflies(idle_spawn_count) # unprovoked - these just wander until the hive is actually hit
