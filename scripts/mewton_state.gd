extends Node

## Tracks whether Issac is currently "at home" (mewton_house.tscn, idle) or "at work"
## (town_room.tscn, working). The state only ever flips at the exact moment the player
## leaves BOTH of his locations - never while the player is standing in one of his rooms
## watching him - which creates the illusion that he travels between them off-screen.

signal state_changed(new_state: int)

enum State { AT_HOME, AT_WORK }

var current_state: State = State.AT_HOME

const HOME_SCENE_PATH := "res://scenes/rooms/mewton_house.tscn"
const WORK_SCENE_PATH := "res://scenes/rooms/town_room.tscn"

var _was_in_mewton_location := false

func _process(_delta: float) -> void:
	var tree := get_tree()
	if not tree or not tree.current_scene:
		return

	var path := tree.current_scene.scene_file_path
	var in_location := path == HOME_SCENE_PATH or path == WORK_SCENE_PATH

	if _was_in_mewton_location and not in_location:
		_toggle_state() # the player just left one of Issac's locations - safe to move him now
	_was_in_mewton_location = in_location

func _toggle_state() -> void:
	current_state = State.AT_WORK if current_state == State.AT_HOME else State.AT_HOME
	state_changed.emit(current_state)
