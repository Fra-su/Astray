extends Node2D

@export var value := 1
var collected := false
var coin_id := ""

@onready var pickup_area: Area2D = $PickupArea

func _ready() -> void:
	coin_id = get_tree().current_scene.scene_file_path + ":" + str(global_position.round())
	print("[Cip] coin_id=", coin_id, " already_collected=", GameState.is_coin_collected(coin_id))
	if GameState.is_coin_collected(coin_id):
		queue_free() # already picked up on a previous visit
		return
	pickup_area.body_entered.connect(_on_body_entered)

func _process(_delta: float) -> void:
	$AnimatedSprite2D.play("default")

func _on_body_entered(body: Node2D) -> void:
	if collected:
		return
	if body.has_method("take_damage"): # same check used elsewhere in your project to identify the player
		collected = true
		pickup_area.monitoring = false
		GameState.add_coins(value)
		GameState.mark_coin_collected(coin_id)
		print("[Cip] collected and marked: ", coin_id, " now_marked=", GameState.is_coin_collected(coin_id))
		_play_pickup_and_remove()

func _play_pickup_and_remove() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", scale * 1.3, 0.1)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
	await tween.finished
	queue_free()
