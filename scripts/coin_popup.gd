extends CanvasLayer

@export var fade_in_duration := 0.2
@export var fade_out_duration := 0.4
@export var linger_duration := 1.5   # how long to wait with no new pickups before fading out
@export var count_up_duration := 0.3 # how long the number takes to visually count up to the new total

var displayed_total := 0
var linger_timer := 0.0
var is_showing := false
var count_tween: Tween
var fade_tween: Tween

@onready var icon: TextureRect = $Icon
@onready var label: Label = $Label

func _ready() -> void:
	icon.modulate.a = 0.0
	label.modulate.a = 0.0
	displayed_total = GameState.total_coins
	label.text = str(displayed_total)
	GameState.coins_gained.connect(_on_coins_gained)

## fires every time a coin is picked up - always animates toward the actual current
## grand total (GameState.total_coins), so rapid pickups naturally stack together
## (previous total + newly gained = new total) exactly like Hollow Knight's Geo counter
func _on_coins_gained(_amount: int) -> void:
	linger_timer = linger_duration

	if not is_showing:
		is_showing = true
		_fade_in()

	_animate_count_to(GameState.total_coins)

func _fade_in() -> void:
	if fade_tween:
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(icon, "modulate:a", 1.0, fade_in_duration)
	fade_tween.tween_property(label, "modulate:a", 1.0, fade_in_duration)

func _animate_count_to(target: int) -> void:
	if count_tween:
		count_tween.kill()
	count_tween = create_tween()
	count_tween.tween_method(_update_display, displayed_total, target, count_up_duration)

func _update_display(value: float) -> void:
	displayed_total = int(round(value))
	label.text = str(displayed_total)

func _process(delta: float) -> void:
	if not is_showing:
		return
	linger_timer -= delta
	if linger_timer <= 0.0:
		is_showing = false
		# note: displayed_total is NOT reset here - it stays at the current grand total,
		# so the next burst continues counting up from wherever it left off, not from 0
		if fade_tween:
			fade_tween.kill()
		fade_tween = create_tween()
		fade_tween.set_parallel(true)
		fade_tween.tween_property(icon, "modulate:a", 0.0, fade_out_duration)
		fade_tween.tween_property(label, "modulate:a", 0.0, fade_out_duration)
