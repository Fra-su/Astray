extends CanvasLayer

@export var debug_visible := true # toggle off to skip the fade entirely for quick testing

@onready var rect: ColorRect = $ColorRect
@onready var picture: AnimatedSprite2D = $Silhouette
var fade_duration := 0.5
var hold_duration := 1.0

func fade_to_scene(scene_path: String, area_name: String = "") -> void:
	if not debug_visible:
		# skip the whole fade sequence, just swap scenes instantly
		get_tree().call_deferred("change_scene_to_file", scene_path)
		await get_tree().process_frame
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player.transition_locked = false
		return

	rect.mouse_filter = Control.MOUSE_FILTER_STOP # block input while transitioning
	picture.self_modulate.a = 0.0
	picture.play("default")

	# fade to black
	var tween_in := create_tween()
	tween_in.tween_property(rect, "self_modulate:a", 1.0, fade_duration)
	await tween_in.finished

	# screen is now fully black — safe to freeze without the player seeing it snap
	var old_player = get_tree().get_first_node_in_group("player")
	if old_player:
		old_player.velocity = Vector2.ZERO

	# fade the picture in alongside the black hold
	var label_tween := create_tween()
	label_tween.tween_property(picture, "self_modulate:a", 1.0, 0.2)

	# actually load the new scene while the screen is black
	get_tree().call_deferred("change_scene_to_file", scene_path)
	await get_tree().process_frame # let the new scene finish instantiating

	# hold on black for a beat so the transition doesn't feel instant
	await get_tree().create_timer(hold_duration).timeout

	# fade the picture back out before revealing the scene
	var label_tween_out := create_tween()
	label_tween_out.tween_property(picture, "self_modulate:a", 0.0, 0.15)
	await label_tween_out.finished

	# fade back into the game
	var tween_out := create_tween()
	tween_out.tween_property(rect, "self_modulate:a", 0.0, fade_duration)
	await tween_out.finished

	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# now that the player is visible again, let carried momentum play out for a beat
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.resume_carried_velocity(GameState.carried_velocity, 0.2)
		await get_tree().create_timer(0.2).timeout
		player.transition_locked = false
