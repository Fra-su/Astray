extends CanvasLayer

@export var debug_visible := true # toggle off to skip the fade entirely for quick testing

@onready var rect: ColorRect = $ColorRect
@onready var picture: AnimatedSprite2D = $Silhouette
var fade_duration := 0.5
var hold_duration := 1.0

func fade_to_scene(scene_path: String, area_name: String = "") -> void:
	if not debug_visible:
		get_tree().call_deferred("change_scene_to_file", scene_path)
		await get_tree().process_frame
		_unlock_player()
		return

	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	picture.self_modulate.a = 0.0
	picture.play("default")

	var tween_in := create_tween()
	tween_in.tween_property(rect, "self_modulate:a", 1.0, fade_duration)
	await tween_in.finished

	var old_player = get_tree().get_first_node_in_group("player")
	if old_player:
		old_player.velocity = Vector2.ZERO

	var label_tween := create_tween()
	label_tween.tween_property(picture, "self_modulate:a", 1.0, 0.2)

	get_tree().call_deferred("change_scene_to_file", scene_path)
	await get_tree().process_frame

	await get_tree().create_timer(hold_duration).timeout

	var label_tween_out := create_tween()
	label_tween_out.tween_property(picture, "self_modulate:a", 0.0, 0.15)
	await label_tween_out.finished

	var tween_out := create_tween()
	tween_out.tween_property(rect, "self_modulate:a", 0.0, fade_duration)
	await tween_out.finished

	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unlock_player()

func _unlock_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.locked_velocity = GameState.push_velocity
		player.locked_velocity_timer = 0.15
		player.velocity = GameState.push_velocity
		player.transition_locked = false
