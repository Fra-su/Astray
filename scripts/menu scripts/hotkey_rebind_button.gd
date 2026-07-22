class_name HotkeyRebindButton
extends Control

@onready var label: Label = $HBoxContainer/Label
@onready var button: Button = $HBoxContainer/Button
@export var action_name : String = "left"

## put whatever labels you need here - keyboard actions like "left", "jump",
## mouse actions like "mouse_attack", and controller actions like "con_jump"
## are just separate entries, no relationship assumed
const ACTION_LABELS := {
	"left": "Move Left",
	"right": "Move Right",
	"down": "Crouch",
	"jump": "Jump",
	"attack": "Attack",
	"skill": "Skill",
	"heal": "Heal",
	"con_jump": "Jump (Controller)",
	"con_attack": "Attack (Controller)",
	"con_skill": "Skill (Controller)",
	"con_heal": "Heal (Controller)",
}

const JOYPAD_BUTTON_NAMES := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_DPAD_UP: "D-Pad Up",
	JOY_BUTTON_DPAD_DOWN: "D-Pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-Pad Left",
	JOY_BUTTON_DPAD_RIGHT: "D-Pad Right",
}

const MOUSE_BUTTON_NAMES := {
	MOUSE_BUTTON_LEFT: "Left Click",
	MOUSE_BUTTON_RIGHT: "Right Click",
	MOUSE_BUTTON_MIDDLE: "Middle Click",
	MOUSE_BUTTON_WHEEL_UP: "Scroll Up",
	MOUSE_BUTTON_WHEEL_DOWN: "Scroll Down",
}

var listening := false

func _ready():
	set_process_input(false)
	button.toggle_mode = false # plain momentary button - no toggle state at all
	button.pressed.connect(_on_button_pressed)
	set_action_name()
	set_text_for_key()

func set_action_name() -> void:
	label.text = ACTION_LABELS.get(action_name, "Unassigned")

func _is_controller_row() -> bool:
	return action_name.begins_with("con_")

func _text_for_event(event: InputEvent) -> String:
	if event is InputEventKey:
		var kc: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		return OS.get_keycode_string(kc)
	elif event is InputEventMouseButton:
		return MOUSE_BUTTON_NAMES.get(event.button_index, "Mouse Button %d" % event.button_index)
	elif event is InputEventJoypadButton:
		return JOYPAD_BUTTON_NAMES.get(event.button_index, "Button %d" % event.button_index)
	return "Unbound"

func set_text_for_key() -> void:
	var events := InputMap.action_get_events(action_name)
	button.text = _text_for_event(events[0]) if events.size() > 0 else "Unbound"

func _on_button_pressed() -> void:
	if listening:
		return # ignore repeat presses while already listening
	listening = true

	if _is_controller_row():
		button.text = "Press a controller button..."
	else:
		button.text = "Press any key..."

	set_process_input(true)
	for i in get_tree().get_nodes_in_group("hotkey_button"):
		if i is HotkeyRebindButton and i != self:
			i.button.disabled = true

## uses _input() (not _unhandled_input) so the click is intercepted BEFORE the Button's own
## GUI processing can consume it - this is what lets you rebind to a click on the button itself
func _input(event: InputEvent) -> void:
	if not listening:
		return

	if _is_controller_row():
		if event is InputEventJoypadButton:
			_finish_rebind(event)
	else:
		if event is InputEventKey:
			_finish_rebind(event)
		elif event is InputEventMouseButton and event.pressed:
			_finish_rebind(event)
			get_viewport().set_input_as_handled() # prevent this same click from also re-triggering the button's own pressed state

func _finish_rebind(event: InputEvent) -> void:
	InputMap.action_erase_events(action_name)
	InputMap.action_add_event(action_name, event.duplicate())
	SettingsSignalBus.notify_keybind_changed(action_name)

	listening = false
	set_process_input(false)
	set_text_for_key()
	set_action_name()

	for i in get_tree().get_nodes_in_group("hotkey_button"):
		if i is HotkeyRebindButton and i != self:
			i.button.disabled = false
