extends Node2D

@onready var shape: CollisionShape2D = $hitbox/CollisionShape2D
@onready var hitbox: Area2D = $hitbox
@onready var label: Label = $Label
@export var text := "Change text in inspect"
@export var fade_duration := 0.3

func _ready() -> void:
	label.modulate.a = 0.0
	hitbox.body_entered.connect(_on_hurtbox_body_entered)
	hitbox.body_exited.connect(_on_hurtbox_body_exited)

func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		label.text = text
		fade_to(1.0)

func _on_hurtbox_body_exited(body: Node2D) -> void:
	if body.has_method("take_damage"):
		fade_to(0.0)

func fade_to(target_alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", target_alpha, fade_duration)
