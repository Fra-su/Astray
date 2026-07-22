extends Node

signal master_volume_changed(value: float)
signal sfx_volume_changed(value: float)
signal music_volume_changed(value: float)
signal window_mode_changed(mode: int)
signal keybind_changed(action_name: String)

const SAVE_PATH := "user://settings.cfg"

var master_volume := 1.0
var sfx_volume := 1.0
var music_volume := 1.0
var window_mode: int = DisplayServer.WINDOW_MODE_WINDOWED

# actions whose bindings get saved/loaded - keep this in sync with your hotkey rebind rows
const SAVED_ACTIONS := [
	"left", "right", "down", "jump", "attack", "heal", "skill",
	"con_jump", "con_attack", "con_heal", "con_skill",
]

func _ready() -> void:
	load_settings()
	apply_all()

func set_master_volume(value: float) -> void:
	master_volume = value
	_apply_bus_volume("Master", value)
	master_volume_changed.emit(value)
	save_settings()

func set_sfx_volume(value: float) -> void:
	sfx_volume = value
	_apply_bus_volume("SFX", value)
	sfx_volume_changed.emit(value)
	save_settings()

func set_music_volume(value: float) -> void:
	music_volume = value
	_apply_bus_volume("Music", value)
	music_volume_changed.emit(value)
	save_settings()

func _apply_bus_volume(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(max(value, 0.0001)))
	AudioServer.set_bus_mute(idx, value <= 0.0001)

func set_window_mode(mode: int) -> void:
	window_mode = mode
	DisplayServer.window_set_mode(mode)
	window_mode_changed.emit(mode)
	save_settings()

## call this after rebinding an action in InputMap, so the change gets persisted
func notify_keybind_changed(action_name: String) -> void:
	keybind_changed.emit(action_name)
	save_settings()

func apply_all() -> void:
	_apply_bus_volume("Master", master_volume)
	_apply_bus_volume("SFX", sfx_volume)
	_apply_bus_volume("Music", music_volume)
	DisplayServer.window_set_mode(window_mode)
	# keybinds are applied directly inside load_settings() via _deserialize_and_apply

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("display", "window_mode", window_mode)

	for action in SAVED_ACTIONS:
		var events := InputMap.action_get_events(action)
		if events.size() == 0:
			continue
		var data := _serialize_event(events[0])
		if not data.is_empty():
			config.set_value("keybinds", action, data)

	config.save(SAVE_PATH)

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return # no save file yet - defaults above are used as-is

	master_volume = config.get_value("audio", "master", 1.0)
	sfx_volume = config.get_value("audio", "sfx", 1.0)
	music_volume = config.get_value("audio", "music", 1.0)
	window_mode = config.get_value("display", "window_mode", DisplayServer.WINDOW_MODE_WINDOWED)

	for action in SAVED_ACTIONS:
		var data = config.get_value("keybinds", action, null)
		if data:
			_deserialize_and_apply(action, data)

## InputEvent objects don't serialize cleanly to ConfigFile's text format on their own,
## so we store just the essential fields per type and reconstruct the event on load
func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"type": "key", "keycode": event.physical_keycode if event.physical_keycode != 0 else event.keycode}
	elif event is InputEventMouseButton:
		return {"type": "mouse", "button_index": event.button_index}
	elif event is InputEventJoypadButton:
		return {"type": "joy", "button_index": event.button_index}
	return {}

func _deserialize_and_apply(action_name: String, data: Dictionary) -> void:
	var event: InputEvent
	match data.get("type", ""):
		"key":
			var e := InputEventKey.new()
			e.physical_keycode = data["keycode"]
			event = e
		"mouse":
			var e := InputEventMouseButton.new()
			e.button_index = data["button_index"]
			event = e
		"joy":
			var e := InputEventJoypadButton.new()
			e.button_index = data["button_index"]
			event = e
		_:
			return
	InputMap.action_erase_events(action_name)
	InputMap.action_add_event(action_name, event)
