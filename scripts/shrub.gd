extends CharacterBody2D

@export var speed := 80.0
var gravity := 1100.0
var direction := 1.0
var move_timer := 0.0
var turn_timer := 0.0
var turning := false
var turn_duration := 0.08

@onready var hurtbox: Area2D = $Hurtbox

func _ready():
	$AnimatedSprite2D.play("default")
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)

func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage()

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
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
