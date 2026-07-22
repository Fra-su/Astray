extends Node2D

## Drop this into a room scene (as a regular Node2D, NOT inside any CanvasLayer) to get
## a small swarm of ambient wandering fireflies, confined to the room's Camera2D limits.
## Since it's plain world-space content with a high z_index, it draws above normal
## sprites/tiles but still stays underneath any UI CanvasLayer (transition fades, the
## Lore Statue's text, etc) automatically - Godot always composites CanvasLayers above
## the base world regardless of z_index.

@export var firefly_count := 8
@export var firefly_color := Color(0xFB / 255.0, 0xFF / 255.0, 0x00 / 255.0)
@export var pixel_size := 4.0 # visible dot size in world units, matching your 4x pixel-art scale

@export var move_speed_min := 15.0
@export var move_speed_max := 35.0
@export var retarget_interval_min := 1.5 # how often each firefly picks a new random destination
@export var retarget_interval_max := 4.0

@export var bob_amplitude := 3.0    # vertical drift layered on top of the wander movement
@export var bob_frequency_min := 0.5
@export var bob_frequency_max := 1.5

@export var light_energy := 0.6
@export var light_range := 48.0
@export var flicker_amplitude := 0.25 # how much the light's energy varies, for a blinking feel

@export var z_index_value := 50 # draws above normal world sprites/tiles
@export var spawn_margin := 150.0 # how far outside the currently visible screen area fireflies can still spawn/wander
@export var visible_area_scale := 1.5 # multiplies the "visible" rect used to exclude spawns - higher means fireflies keep further back from the literal screen edge
@export var bounds_update_interval := 0.5 # how often (in seconds) the wander area re-centers on the camera as it moves

var bounds_update_timer := 0.0
var active_fireflies: Array[Firefly] = []

func _ready() -> void:
	await get_tree().process_frame # let the rest of the scene (including the room's real camera) finish initializing first
	var bounds := _get_camera_bounds()
	for i in firefly_count:
		_spawn_firefly(bounds)

func _process(delta: float) -> void:
	bounds_update_timer -= delta
	if bounds_update_timer <= 0.0:
		bounds_update_timer = bounds_update_interval
		_refresh_fireflies()

## removes fireflies that have drifted well outside the current view, then tops back
## up to firefly_count with fresh ones inside the new bounds - so as you explore, old
## fireflies get cleaned up behind you and new ones appear ahead, instead of the same
## handful just endlessly re-targeting around wherever they first spawned
func _refresh_fireflies() -> void:
	active_fireflies = active_fireflies.filter(func(f): return is_instance_valid(f))

	var bounds := _get_camera_bounds()
	var visible_rect := _get_visible_rect()
	var despawn_bounds := bounds.grow(spawn_margin) # a bit more forgiving than the spawn area itself, so fireflies aren't yanked away the instant they're barely outside view

	for firefly in active_fireflies.duplicate():
		if visible_rect.has_point(firefly.core_position):
			continue # never despawn something the player can currently see, no matter what
		if not despawn_bounds.has_point(firefly.core_position):
			active_fireflies.erase(firefly)
			firefly.queue_free()

	while active_fireflies.size() < firefly_count:
		_spawn_firefly(bounds)

## builds a world-space Rect2 around the camera's CURRENT visible area (not the whole
## room's scroll limits) - expanded outward by spawn_margin so some fireflies sit just
## off-screen and can drift in/out naturally instead of all popping in already visible
func _get_camera_bounds() -> Rect2:
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return Rect2(global_position - Vector2(200, 150), Vector2(400, 300))

	var screen_size: Vector2 = get_viewport_rect().size / camera.zoom
	var top_left := camera.global_position - screen_size / 2.0 - Vector2(spawn_margin, spawn_margin)
	var size := screen_size + Vector2(spawn_margin, spawn_margin) * 2.0

	return Rect2(top_left, size)

## the area actually visible to the player right now (scaled up by visible_area_scale
## for extra buffer) - fireflies must never spawn inside this, only in the margin ring
## between this and the full bounds from _get_camera_bounds()
func _get_visible_rect() -> Rect2:
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return Rect2(global_position, Vector2.ZERO)

	var screen_size: Vector2 = (get_viewport_rect().size / camera.zoom) * visible_area_scale
	return Rect2(camera.global_position - screen_size / 2.0, screen_size)

## picks a random point within bounds that does NOT fall inside the visible rect -
## retries a handful of times, then just falls back to the bounds' edge region if unlucky
func _pick_offscreen_point(bounds: Rect2) -> Vector2:
	var visible_rect := _get_visible_rect()
	for attempt in 20:
		var point := Vector2(
			bounds.position.x + randf() * bounds.size.x,
			bounds.position.y + randf() * bounds.size.y
		)
		if not visible_rect.has_point(point):
			return point

	# fallback after too many failed attempts - just place it right at the bounds' edge
	var edge_side := randi() % 4
	match edge_side:
		0: return Vector2(bounds.position.x, bounds.position.y + randf() * bounds.size.y) # left edge
		1: return Vector2(bounds.position.x + bounds.size.x, bounds.position.y + randf() * bounds.size.y) # right edge
		2: return Vector2(bounds.position.x + randf() * bounds.size.x, bounds.position.y) # top edge
		_: return Vector2(bounds.position.x + randf() * bounds.size.x, bounds.position.y + bounds.size.y) # bottom edge

func _spawn_firefly(bounds: Rect2) -> void:
	var firefly := Firefly.new()
	firefly.color = firefly_color
	firefly.pixel_size = pixel_size
	firefly.bounds = bounds
	firefly.move_speed = randf_range(move_speed_min, move_speed_max)
	firefly.retarget_interval_min = retarget_interval_min
	firefly.retarget_interval_max = retarget_interval_max
	firefly.bob_amplitude = bob_amplitude
	firefly.bob_frequency = randf_range(bob_frequency_min, bob_frequency_max)
	firefly.bob_phase = randf_range(0.0, TAU)
	firefly.light_energy = light_energy
	firefly.light_range = light_range
	firefly.flicker_amplitude = flicker_amplitude
	firefly.z_index = z_index_value
	firefly.position = _pick_offscreen_point(bounds)
	add_child(firefly)
	active_fireflies.append(firefly)

## individual firefly agent - each one wanders independently with its own randomized
## timing/phase, so the swarm never looks synchronized or "patterny"
class Firefly extends Node2D:
	var color: Color
	var pixel_size: float
	var bounds: Rect2
	var move_speed: float
	var retarget_interval_min: float
	var retarget_interval_max: float
	var bob_amplitude: float
	var bob_frequency: float
	var bob_phase: float
	var light_energy: float
	var light_range: float
	var flicker_amplitude: float

	var core_position: Vector2 # the actual wander position, separate from the visual bob offset
	var target: Vector2
	var retarget_timer := 0.0
	var time_alive := 0.0
	var light: PointLight2D

	func _ready() -> void:
		core_position = position
		_pick_new_target()
		_build_visuals()

	func _build_visuals() -> void:
		# the light gets a soft radial glow texture (fades out toward the edges)
		var glow_gradient := Gradient.new()
		glow_gradient.set_color(0, Color(1, 1, 1, 1))
		glow_gradient.set_color(1, Color(1, 1, 1, 0))

		var glow_tex := GradientTexture2D.new()
		glow_tex.gradient = glow_gradient
		glow_tex.fill = GradientTexture2D.FILL_RADIAL
		glow_tex.fill_from = Vector2(0.5, 0.5)
		glow_tex.fill_to = Vector2(1.0, 0.5)
		glow_tex.width = 32
		glow_tex.height = 32

		# the visible firefly body itself is a flat, solid, crisp square - no soft
		# falloff at all, so it reads as a clean pixel rather than a blurry dot
		var square_image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		square_image.fill(Color(1, 1, 1, 1))
		var square_tex := ImageTexture.create_from_image(square_image)

		var sprite := Sprite2D.new()
		sprite.texture = square_tex
		sprite.modulate = color
		sprite.scale = Vector2.ONE * (pixel_size / 4.0)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # keeps the square crisp, no smoothing/blur when scaled
		add_child(sprite)

		light = PointLight2D.new()
		light.texture = glow_tex
		light.color = color
		light.energy = light_energy
		light.texture_scale = light_range / 32.0
		add_child(light)

	func _pick_new_target() -> void:
		target = Vector2(
			bounds.position.x + randf() * bounds.size.x,
			bounds.position.y + randf() * bounds.size.y
		)
		retarget_timer = randf_range(retarget_interval_min, retarget_interval_max)

	func _process(delta: float) -> void:
		time_alive += delta
		retarget_timer -= delta

		if retarget_timer <= 0.0 or core_position.distance_to(target) < 4.0:
			_pick_new_target()

		var to_target := target - core_position
		if to_target.length() > 0.1:
			core_position += to_target.normalized() * move_speed * delta

		# vertical bob layered on top of the wander movement, phase offset per instance
		position = core_position + Vector2(0, sin(time_alive * bob_frequency + bob_phase) * bob_amplitude)

		if light:
			light.energy = light_energy + sin(time_alive * 3.0 + bob_phase) * flicker_amplitude
