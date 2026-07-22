extends Parallax2D

@export var pixel_size := 4

func _ready() -> void:
	scroll_scale.y = 1.0 # track camera vertically 1:1, same as tiles

func _process(_delta: float) -> void:
	# only snap the horizontal scroll for crisp pixel-art tiling
	scroll_offset.x = round(scroll_offset.x / pixel_size) * pixel_size
