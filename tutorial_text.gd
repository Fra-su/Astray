extends Node2D

@onready var shape: CollisionShape2D = $hitbox/CollisionShape2D
@onready var hitbox: Area2D = $hitbox
@onready var label: Label = $Label
@export var text := "Change text in inspect"

func _ready() -> void:
	hitbox.body_entered.connect(_on_hurtbox_body_entered)
	hitbox.body_exited.connect(_on_hurtbox_body_exited)

func _process(delta: float) -> void:
	pass

func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"): 
		label.text = text

func _on_hurtbox_body_exited(body: Node2D) -> void:
	if body.has_method("take_damage"): 
		label.text = ""
