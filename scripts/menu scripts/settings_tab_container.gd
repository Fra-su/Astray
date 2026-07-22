extends Control

@onready var window_mode_option: OptionButton = $MarginContainer/ScrollContainer/VBoxContainer/WindowModeOption
@onready var master_slider: HSlider = $MarginContainer/ScrollContainer/VBoxContainer/MasterRow/MasterSlider
@onready var sfx_slider: HSlider = $MarginContainer/ScrollContainer/VBoxContainer/SfxRow/SfxSlider
@onready var music_slider: HSlider = $MarginContainer/ScrollContainer/VBoxContainer/MusicRow/MusicSlider

const WINDOW_MODES := [
	{"label": "Windowed", "mode": DisplayServer.WINDOW_MODE_WINDOWED},
	{"label": "Fullscreen", "mode": DisplayServer.WINDOW_MODE_FULLSCREEN},
	{"label": "Exclusive Fullscreen", "mode": DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN},
]

func _ready() -> void:
	for entry in WINDOW_MODES:
		window_mode_option.add_item(entry["label"])
	_select_current_window_mode()
	window_mode_option.item_selected.connect(_on_window_mode_selected)

	for slider in [master_slider, sfx_slider, music_slider]:
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01

	master_slider.value = SettingsSignalBus.master_volume
	sfx_slider.value = SettingsSignalBus.sfx_volume
	music_slider.value = SettingsSignalBus.music_volume

	master_slider.value_changed.connect(SettingsSignalBus.set_master_volume)
	sfx_slider.value_changed.connect(SettingsSignalBus.set_sfx_volume)
	music_slider.value_changed.connect(SettingsSignalBus.set_music_volume)

func _select_current_window_mode() -> void:
	for i in WINDOW_MODES.size():
		if WINDOW_MODES[i]["mode"] == SettingsSignalBus.window_mode:
			window_mode_option.select(i)
			return
	window_mode_option.select(0)

func _on_window_mode_selected(index: int) -> void:
	SettingsSignalBus.set_window_mode(WINDOW_MODES[index]["mode"])
