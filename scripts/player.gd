extends CharacterBody2D

@export var speed      := 250
@export var gravity    := 1100
@export var jump_power := 600
@export var crouch_stick_deadzone := 0.3     # minimum stick tilt before crouch can trigger at all
@export var crouch_stick_cone_degrees := 45.0 # half-angle either side of straight down (90 total) within which crouch triggers

#Take damage signal
signal damaged()
signal energy_changed(new_energy: int)
signal healed()

#healing
@export var heal_cost := 16          # max energy drained per heal attempt
@export var heal_duration := 1.2     # time to drain a FULL energy bar (max_energy) at this rate; partial heals take proportionally less time
@export var heal_cooldown_duration := 0.4  # lockout after a completed heal before another can start, prevents accidental double-heal from holding
@export var heal_completion_delay := 0.15  # extra pause after drain finishes before the heart actually restores, tweak to match your energy bar's visual catch-up speed
@export var heal_refund_threshold := 8  # if a heal is cancelled after draining less than this much, refund the spent energy (covers accidental chained heals cut short)
var healing := false
var heal_spent := 0        # how much energy has been drained this heal attempt
var heal_target := 0       # how much energy this attempt will drain in total (min(heal_cost, energy available))
var heal_accum := 0.0       # fractional accumulator so draining feels smooth
var heal_finishing := false # true during the completion delay window, after drain is done but before complete_heal() fires
var heal_finish_timer := 0.0
var heal_cooldown_timer := 0.0
@onready var heal_particles: GPUParticles2D = $HealParticles

#energy (gained from hitting enemies)
@export var max_energy := 40
var energy := 0

#movement
var dir                 := Vector2()
var speed_mod           := 1.0
var gravity_mod         := 1.0
var velocity_last_frame := Vector2.ZERO #idk what for

#state
var crouching           := false
var allow_input         := true
var was_on_floor        := false #if on floor last frame
var invincible          := false
var is_dying             := false
var respawn_grace        := false # blocks ALL damage (including hazards, which ignore invincible by design) briefly after respawning

#death/respawn
@export var death_animation_name := "die"
@export var death_animation_max_wait := 3.0 # safety cap in case the die animation loops or is missing - set this longer than your actual death animation's real duration, or it'll cut the animation short and snap to the end early
@export var death_fade_duration := 0.8

#transitions
var transition_locked   := false #blocks input during room transitions, separate from allow_input
var locked_velocity := Vector2.ZERO
var locked_velocity_timer := 0.0 # counts down; while > 0, velocity is forced to locked_velocity

#attacking
@export var attack_cooldown := 0.3
@export var attack_offset := 20.0   # how far in front of the player the hitbox sits
@export var attack_hitbox_offset_correction := 2.0  # extra reach added only when facing right, to compensate for the sprite/player origin being slightly off-center - left side is untouched
@export var attack_hitbox_duration := 0.2  # how long the hitbox stays active per swing, in seconds
@export var swing_recoil_force := 50.0      # small pushback on every swing, even if it misses
@export var swing_hit_recoil_force := 100.0 # extra pushback added when the swing actually connects
@export var swing_recoil_lock_duration := 0.1 # how long recoil overrides normal movement
@export var pogo_bounce_velocity := -450.0 # upward pop applied when a downward pogo attack connects
@export var pogo_sprite_offset_correction := Vector2(0, 16) # the pogo animation's frames are 32x32 vs your other animations' 16x32 - this compensates for AnimatedSprite2D centering the taller frame differently
@export var attack_animation_max_wait := 1.0 # safety cap in case an attack animation loops or is missing
var attacking := false
var attack_cooldown_timer := 0.0
var hit_bodies_this_swing: Array = []
var is_pogo_swing := false
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var pogo_hitbox: Area2D = $PogoHitbox

#damage/knockback tuning
@export var enemy_knockback_force := 300.0
@export var enemy_knockback_hop := 150.0
@export var hazard_knockback_force := 300.0
@export var hazard_knockback_hop := 150.0
@export var hazard_teleport_delay := 0.25 # how long the knockback plays before snapping to checkpoint
@export var knockback_lock_duration := 0.15 # how long the player can't override knockback with movement
var hazard_locked := false
var playing_hurt := false

#idk what all for
var land_frames             := 0
var jump_frames             := 0
var land_duration           := 13
var jump_duration           := 3
var land_velocity_threshold := 800.0 #needed speed for big landing animation and input blocking to activate

#coyote time
var frames_since_on_floor := 0 #how many frames since we were on the floor
var coyote_time_limit     := 4 #how many frames tolerance we get to jump (coyote time)

#time based jump
#the longer the the jump is held, the higher the jump
var current_jump_time := 0
var max_jump_time := 15

#springshroom related stuff
var shroom_jump_radius := 40 #the radius which we have to be for spring shroom to activate
var springshrooms      := [] #all of the springshrooms in a list for optimisation
 
#checkpoints and teleport points
var last_checkpoint := Vector2(768, 550)

#i-frames (invincibility flicker after taking damage)
var iframe_duration := 1.2 #how long invincibility lasts after a hit, in seconds
var iframe_flicker_time := 0.1 #how long each opacity step lasts

#modifier values for either jumping or running
var mod_values = {
	"crouching" : 0.6,
	"shroom_jump": 1.5,
}

func _ready(): #runs on start
	energy = GameState.current_energy
	energy_changed.emit(energy)
	#this allows faster distance calculations as we dont need to square root but instead we need to square the value
	shroom_jump_radius *= shroom_jump_radius
	#make a preloaded list of springshrooms so we dont have to generate a new list every single time
	for shroom in get_tree().get_nodes_in_group("springshroom"):
		springshrooms.append(shroom)

	#if we just arrived from a door, spawn at the position it specified
	if GameState.has_pending_spawn:
		position = GameState.next_spawn_position
		last_checkpoint = GameState.next_spawn_position
		velocity = Vector2.ZERO
		transition_locked = true
		$AnimatedSprite2D.flip_h = GameState.carried_facing_left
		GameState.has_pending_spawn = false

	attack_hitbox.monitoring = false
	attack_hitbox.body_entered.connect(_on_attack_hit)
	pogo_hitbox.monitoring = false
	pogo_hitbox.body_entered.connect(_on_pogo_hit)

	if heal_particles:
		heal_particles.emitting = false

	if GameState.pending_fade_in:
		GameState.pending_fade_in = false
		_fade_screen_from_black()
		$timers/sleep.stop() # forces the sleeping pose immediately - animate() shows "sleeping" whenever this timer is stopped
		$AnimatedSprite2D.play("sleeping") # also force it directly, as a redundant safety net in case of any timer/floor-detection race
		transition_locked = false # our death/respawn path bypasses Transition.gd entirely, so nothing else would ever clear this
		start_iframes() # brief invincibility in case the spawnpoint happens to be near a hazard/enemy
		respawn_grace = true
		await get_tree().create_timer(iframe_duration).timeout
		respawn_grace = false

func gain_energy(amount: int) -> void:
	energy = min(energy + amount, max_energy)
	GameState.current_energy = energy
	energy_changed.emit(energy)

func spend_energy(amount: int) -> void:
	energy = max(energy - amount, 0)
	GameState.current_energy = energy
	energy_changed.emit(energy)

func start_heal() -> void:
	print("heal started")
	healing = true
	heal_spent = 0
	heal_accum = 0.0
	heal_finishing = false
	heal_target = min(heal_cost, energy) # can't drain more than you have
	$AnimatedSprite2D.play("heal")
	if heal_particles:
		heal_particles.emitting = true

func cancel_heal() -> void:
	print("heal cancelled, spent this attempt: ", heal_spent)
	healing = false
	heal_finishing = false
	if heal_spent < heal_refund_threshold and heal_spent > 0:
		print("refunding ", heal_spent, " energy from cancelled heal")
		gain_energy(heal_spent)
	if heal_particles:
		heal_particles.emitting = false

func complete_heal() -> void:
	print("heal completed, emitting healed signal")
	healing = false
	heal_finishing = false
	heal_cooldown_timer = heal_cooldown_duration
	if heal_particles:
		heal_particles.emitting = false
	healed.emit()

func _on_attack_hit(body: Node2D) -> void:
	if body in hit_bodies_this_swing:
		return # already hit this same target during this swing, ignore repeats
	if body.has_method("take_hit"):
		hit_bodies_this_swing.append(body)
		body.take_hit(4)
		if not body.is_in_group("corpse"):
			gain_energy(4)
		_apply_swing_recoil(swing_hit_recoil_force)

func _on_pogo_hit(body: Node2D) -> void:
	if body in hit_bodies_this_swing:
		return
	if body.has_method("take_hit"):
		hit_bodies_this_swing.append(body)
		body.take_hit(4)
		if not body.is_in_group("corpse"):
			gain_energy(4)
		_apply_pogo_bounce()

func _apply_pogo_bounce() -> void:
	velocity.y = pogo_bounce_velocity
	jump_frames = jump_duration # reuses the existing jump-pose animation frames briefly

func try_attack() -> void:
	if attacking or attack_cooldown_timer > 0.0 or transition_locked:
		return
	attacking = true
	attack_cooldown_timer = attack_cooldown
	hit_bodies_this_swing.clear()

	is_pogo_swing = not is_on_floor() and _is_crouch_input() # airborne + holding down = strike downward instead of sideways

	if is_pogo_swing:
		pogo_hitbox.monitoring = true
	else:
		_update_attack_hitbox_position()
		attack_hitbox.monitoring = true
		_apply_swing_recoil(swing_recoil_force) # pogo swings don't get the normal sideways recoil push

	if is_pogo_swing:
		$AnimatedSprite2D.offset = pogo_sprite_offset_correction
	$AnimatedSprite2D.play("pogo" if is_pogo_swing else "horizontal_attack")

	await get_tree().create_timer(attack_hitbox_duration).timeout # let the hitbox register overlaps for a short window
	if is_pogo_swing:
		pogo_hitbox.monitoring = false
	else:
		attack_hitbox.monitoring = false

	await _await_animation_safely(attack_animation_max_wait)
	$AnimatedSprite2D.offset = Vector2.ZERO # revert the pogo offset correction regardless of which animation just played
	attacking = false

## races the real animation_finished signal against a timeout - protects against animations
## that loop (animation_finished never fires) or are missing entirely, so try_attack()
## can never get stuck with attacking left permanently true
func _await_animation_safely(max_wait: float) -> void:
	var finished := [false] # single-element array, not a plain bool - GDScript lambdas capture locals by VALUE
	var mark_finished := func(): finished[0] = true
	$AnimatedSprite2D.animation_finished.connect(mark_finished, CONNECT_ONE_SHOT)

	var elapsed := 0.0
	while not finished[0] and elapsed < max_wait:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	if not finished[0] and $AnimatedSprite2D.animation_finished.is_connected(mark_finished):
		$AnimatedSprite2D.animation_finished.disconnect(mark_finished)
	$AnimatedSprite2D.stop() # ensure playback actually stops even if the animation was looping

## keeps the hitbox on whichever side the player is actually facing, even if they flip
## direction mid-swing - attack_hitbox_offset_correction compensates for the sprite/origin
## not being perfectly centered, so left and right attacks reach equally far
func _update_attack_hitbox_position() -> void:
	var facing_dir = -1.0 if $AnimatedSprite2D.flip_h else 1.0
	var correction = attack_hitbox_offset_correction if facing_dir > 0 else 0.0
	attack_hitbox.position.x = attack_offset * facing_dir + correction
	attack_hitbox.position.y = 0

func _apply_swing_recoil(force: float) -> void:
	var facing_dir = -1.0 if $AnimatedSprite2D.flip_h else 1.0
	velocity.x += -facing_dir * force # push opposite the direction you're swinging
	locked_velocity = velocity
	locked_velocity_timer = swing_recoil_lock_duration

## call this when the player's health reaches 0 - plays the death animation, fades
## the screen to black, then respawns at the last spawnpoint (bench/cutscene) in whatever
## scene that spawnpoint lives in. Note: this node gets freed partway through by the
## scene change, so nothing can run in this function after that call - the freshly
## spawned player instance picks up the fade-in via GameState.pending_fade_in in _ready().
func die() -> void:
	if is_dying:
		return
	is_dying = true
	invincible = true
	transition_locked = true
	attacking = false
	healing = false
	velocity = Vector2.ZERO
	locked_velocity_timer = 0.0 # clear any in-progress knockback so it can't keep overriding velocity during the death animation

	await _play_death_animation_safely()
	await _fade_screen_to_black()

	GameState.current_health = GameState.max_health # restore health so respawning doesn't immediately re-trigger death
	GameState.next_spawn_position = GameState.last_spawn_position
	GameState.has_pending_spawn = true
	GameState.pending_fade_in = true

	print("[Player] dying, total_coins right before scene change: ", GameState.total_coins)
	get_tree().change_scene_to_file(GameState.last_spawn_scene)
	# this node may be freed at any point after the line above - do not add code here

func _play_death_animation_safely() -> void:
	if not $AnimatedSprite2D.sprite_frames.has_animation(death_animation_name):
		return

	$AnimatedSprite2D.play(death_animation_name)

	var finished := [false] # single-element array, not a plain bool - GDScript lambdas capture locals by VALUE, so a plain bool here would never actually get updated by the closure below
	var mark_finished := func(): finished[0] = true
	$AnimatedSprite2D.animation_finished.connect(mark_finished, CONNECT_ONE_SHOT)

	var elapsed := 0.0
	while not finished[0] and elapsed < death_animation_max_wait:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	if not finished[0] and $AnimatedSprite2D.animation_finished.is_connected(mark_finished):
		$AnimatedSprite2D.animation_finished.disconnect(mark_finished)

	# explicitly stop and pin to the last frame - otherwise, if the animation loops,
	# it keeps playing in the background even after we've stopped waiting for it
	var frame_count: int = $AnimatedSprite2D.sprite_frames.get_frame_count(death_animation_name)
	$AnimatedSprite2D.stop()
	$AnimatedSprite2D.animation = death_animation_name
	$AnimatedSprite2D.frame = max(frame_count - 1, 0)

func _fade_screen_to_black() -> void:
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)

	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.add_to_group("death_fade_overlay")
	layer.add_child(fade)
	# added to the tree root directly (not the current scene) so it survives change_scene_to_file,
	# since that only replaces get_tree().current_scene, not root's other direct children
	get_tree().root.add_child(layer)

	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, death_fade_duration)
	await tween.finished

func _fade_screen_from_black() -> void:
	var layer := get_tree().get_first_node_in_group("death_fade_overlay")
	if not layer:
		return
	var fade: ColorRect = layer.get_child(0)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, death_fade_duration)
	tween.tween_callback(layer.queue_free)

## called when hit by an enemy: knockback + i-frames, no teleport, respects invincibility
func take_damage(source: Node2D = null) -> void:
	if is_dying or invincible or respawn_grace:
		return
	if healing:
		cancel_heal()
	apply_knockback_from(source, enemy_knockback_force, enemy_knockback_hop)
	damaged.emit()
	if is_dying:
		return # died synchronously as a result of the emit above - don't play hurt/start iframes over the death sequence
	play_hurt_animation()
	start_iframes()

## called when touching a hazard: knockback first, then teleport to checkpoint, ignores invincibility
func take_hazard_damage(source: Node2D = null) -> void:
	if hazard_locked or is_dying:
		return
	if respawn_grace:
		return
	hazard_locked = true
	if healing:
		cancel_heal()

	apply_knockback_from(source, hazard_knockback_force, hazard_knockback_hop)
	damaged.emit()
	if is_dying:
		hazard_locked = false
		return # died synchronously as a result of the emit above
	play_hurt_animation()
	start_iframes()
	await get_tree().create_timer(hazard_teleport_delay).timeout
	_teleport_to_checkpoint()
	hazard_locked = false

func play_hurt_animation() -> void:
	if is_dying:
		return # damaged.emit() above can synchronously trigger die() via health_ui - don't let this stomp the death animation
	playing_hurt = true
	$AnimatedSprite2D.play("hurt")
	await $AnimatedSprite2D.animation_finished
	playing_hurt = false

func apply_knockback_from(source: Node2D, force: float, hop: float) -> void:
	var push_dir := 1.0 # arbitrary default only used if source is missing
	if source:
		push_dir = sign(global_position.x - source.global_position.x)
		if push_dir == 0:
			push_dir = 1.0
	velocity.x = push_dir * force
	velocity.y = -hop
	locked_velocity = velocity
	locked_velocity_timer = knockback_lock_duration

func _teleport_to_checkpoint() -> void:
	velocity = Vector2.ZERO
	position = last_checkpoint
	snap_out_of_floor()

func snap_out_of_floor() -> void:
	#if the checkpoint was placed slightly into the ground, nudge the player up until clear
	var nudge := Vector2(0, -1) #move up 1 pixel at a time
	var max_attempts := 100     #safety cap so this can't loop forever

	for i in max_attempts:
		if not test_move(global_transform, nudge):
			break
		global_position += nudge

func start_iframes() -> void:
	invincible = true

	var elapsed := 0.0
	var flashed_dim := false

	while elapsed < iframe_duration:
		flashed_dim = not flashed_dim
		modulate.a = 0.7 if flashed_dim else 1.0
		await get_tree().create_timer(iframe_flicker_time).timeout
		elapsed += iframe_flicker_time

	modulate.a = 1.0
	invincible = false

func animate(): #could prbly optimise
	#flip the sprite based on direction
	$AnimatedSprite2D.flip_h = dir.x < 0 if dir.x != 0 else $AnimatedSprite2D.flip_h

	if attacking or playing_hurt or healing or is_dying:
		return #let the attack/hurt/heal animation play uninterrupted

	var animation = "" #the animation we will play
	
	if $timers/sleep.is_stopped():
		animation = "sleeping"
	elif $timers/sit.is_stopped():
		animation = "sitting"
	elif crouching:
		#we are crouching but depending on if we are moving we play a different animation
		animation = "crouching_running" if dir.x else "crouching_idle"
	elif land_frames > 0:
		$AnimatedSprite2D.play("jumping")
		$AnimatedSprite2D.frame = 6
		return
	elif jump_frames > 0:
		$AnimatedSprite2D.play("jumping")
		$AnimatedSprite2D.frame = 2
		return
	elif not is_on_floor():
		$AnimatedSprite2D.play("jumping")
		if velocity.y < -100:
			$AnimatedSprite2D.frame = 3
		elif velocity.y < 0:
			$AnimatedSprite2D.frame = 4
		else:
			$AnimatedSprite2D.frame = 5
		return
	else:
#		play different animation based on direction
		animation = "running" if dir.x and not $body/ShapeCast2D.is_colliding() else "idle"
		
	$AnimatedSprite2D.play(animation) #play the aniamtion

func toggle_crouch():
	$head.disabled = crouching #enable or disable head hitbox so we can become smaller to crouch
	speed_mod = mod_values["crouching"] if crouching else 1.0 #change speed to match crouching state

func update_timers():
#	these timers make us sleep or sit based on if we added input reacently
	if dir or velocity.y != 0: #condtions to reset timers so we dont sit or sleep
		$timers/sit.start()
		$timers/sleep.start()
		
	#for timer debugging
	#print(str($timers/sit.time_left) + "   " + str($timers/sleep.time_left))

func force_state_update():
	if not is_on_floor(): #force crouching to be off when not on ground
		crouching = false

func _is_crouch_input() -> bool:
	if Input.is_action_pressed("down"):
		return true # keyboard is digital, no angle check needed
	var stick := Vector2(Input.get_axis("con_left", "con_right"), Input.get_axis("con_up", "con_down"))
	if stick.length() < crouch_stick_deadzone:
		return false
	var angle_from_down := stick.angle_to(Vector2.DOWN)
	return absf(angle_from_down) <= deg_to_rad(crouch_stick_cone_degrees)

func get_input():
	if Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("con_attack"):
		try_attack()

	if not healing and heal_cooldown_timer <= 0.0 and (Input.is_action_pressed("heal") or Input.is_action_pressed("con_heal")) and is_on_floor() \
			and not attacking and not transition_locked and energy >= heal_cost:
		start_heal()

	if healing:
		if not (Input.is_action_pressed("heal") or Input.is_action_pressed("con_heal")) or not is_on_floor():
			cancel_heal()
		else:
			dir = Vector2.ZERO # locked in place while channeling
			return

	#default values
	gravity_mod = 1.0 #modifier for gravity
	crouching = false if not is_on_floor() else crouching #not allow crouching if not on ground
	
	#block or not block input
	if not allow_input or transition_locked:
		return
	
	#get axis but no normalization as we dont want speed decrease
	var kb_x := Input.get_axis("left", "right")
	dir.x = kb_x if kb_x != 0.0 else Input.get_axis("con_left", "con_right")
	var kb_y := Input.get_axis("up", "down")
	dir.y = kb_y if kb_y != 0.0 else Input.get_axis("con_up", "con_down")
	#change head position based on movement
	$head.position.x = (-1.0 if dir.x < 0 else 3.0) if dir.x != 0 else $head.position.x #move head to the right positionc

#	create a hashmap with the input values
	var im = {
		"up"          : Input.is_action_pressed("up") or Input.is_action_pressed("con_up"),
		"down"        : _is_crouch_input(),
		"jump"        : Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("con_jump"),
		"jump_rel"    : Input.is_action_just_released("jump") or Input.is_action_just_released("con_jump"),
	}		

	
	if not $head/ShapeCast2D.is_colliding():
		if im["jump"] or velocity.y > 0:
			for shroom in springshrooms: #could optimise using different nodes #springshroom jumping
#				if our distance is within a certain radius we jump
				if position.distance_squared_to(shroom.position) <= shroom_jump_radius:
					velocity.y = -jump_power * mod_values["shroom_jump"] #apply mod with jump
					shroom.play("spring") #play animation
					return #break out
					
			var coyote_cond = frames_since_on_floor <= coyote_time_limit
			
			if im["jump"] and (is_on_floor() or coyote_cond):
				velocity.y = -jump_power #jump
				jump_frames = jump_duration #may need to add to shroom bit
		else:
			crouching = im["down"] and is_on_floor() #check if croucing
			
		if im["jump_rel"]:
			velocity.y /= 1.5 #fix magic number

func update_vel(delta):
	if is_dying:
		# checked before knockback/transition branches so leftover knockback velocity
		# from the killing blow can't keep getting force-reapplied during the death animation
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			velocity.y = 0.0
		return

	if healing:
		velocity = Vector2.ZERO

		if heal_finishing:
			heal_finish_timer -= delta
			if heal_finish_timer <= 0.0:
				complete_heal()
			return

		# constant drain rate based on max_energy, so time scales with how much is actually drained
		# (e.g. draining half your energy takes half as long as a full drain)
		var rate = float(max_energy) / heal_duration # energy units per second
		heal_accum += rate * delta
		while heal_accum >= 1.0 and heal_spent < heal_target and energy > 0:
			heal_accum -= 1.0
			spend_energy(1)
			heal_spent += 1
		if heal_spent >= heal_target or energy <= 0:
			heal_finishing = true
			heal_finish_timer = heal_completion_delay
		return

	if locked_velocity_timer > 0.0:
		locked_velocity_timer -= delta
		velocity.x = locked_velocity.x # only horizontal recoil is held steady
		if not is_on_floor():
			velocity.y += gravity * delta * gravity_mod # gravity keeps acting on vertical velocity the whole time - freezing it here was letting attacks pause gravity mid-air for extra height
		else:
			velocity.y = 0.0
		if $hitbox.is_colliding():
			_check_hitbox_damage()
		return

	if transition_locked:
		# input is locked during a transition, but let existing velocity keep playing out
		# without gravity pulling the player down mid-fade
		return

	if not is_on_floor():
		velocity.y += gravity * delta * gravity_mod
	if land_frames > 0:
		velocity.x = 0
	else:
		velocity.x = dir.x * speed * speed_mod

	if $hitbox.is_colliding():
		_check_hitbox_damage()

	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

func _check_hitbox_damage() -> void:
	var collider = $hitbox.get_collider(0)
	if collider and collider.is_in_group("hazard"):
		take_hazard_damage(collider)
	else:
		take_damage(collider)

func _physics_process(delta: float) -> void:
	if land_frames <= 0: #idk yet
		allow_input = true

	if heal_cooldown_timer > 0.0:
		heal_cooldown_timer -= delta

	get_input()
	update_timers() #update sleep and sit timers
	toggle_crouch()
	force_state_update()
	update_vel(delta)
	if attacking and not is_pogo_swing:
		_update_attack_hitbox_position() # keeps tracking facing direction even if it changes mid-swing
	frames_since_on_floor = 0 if is_on_floor() else frames_since_on_floor + 1 #coyte time
	velocity_last_frame = velocity #idk why used yet
	move_and_slide() #update position

#	if we have a large fall, disable input for a frame and play landing animation
#	also do this before animate so is animated
	if is_on_floor() and not was_on_floor:
		if velocity_last_frame.y >= land_velocity_threshold:
			land_frames = land_duration
			allow_input = false
			jump_frames = 0

	animate()
	was_on_floor = is_on_floor() #idk what for yet

	land_frames = land_frames - 1 if land_frames > 0 else land_frames # idk what for yet
	jump_frames = jump_frames - 1 if jump_frames > 0 else jump_frames # idk what for yet

#camera values:
# left: 0
# bottom: 736
