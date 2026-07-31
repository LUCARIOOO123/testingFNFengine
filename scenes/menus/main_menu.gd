extends Node2D

const AnimateSymbol = preload("res://addons/gdanimate/animate_symbol.gd")

var omnitrix: AnimateSymbol
var menu_text: AnimateSymbol

const IDLE := "Omnitrix/Omnitrix Idle waiting"
const TURN_LEFT := "Omnitrix/Omnitrix TURN L"
const TURN_RIGHT := "Omnitrix/Omnitrix TURN R"
const ENTER_PRESSED := "Omnitrix/Omnitrix EnterPressed Anim"
const OPTION_SELECTED := "Omnitrix/Omnitrix OptionSelected Animation"

const MENU_ITEMS := [
	{ "idle": "Omnitrix/Omnitrix Storymode-IDLE", "text_frame": 0 },
	{ "idle": "Omnitrix/Omnitrix Freeplay-IDLE ", "text_frame": 1 },
	{ "idle": "Omnitrix/Omnitrix Settings-IDLE", "text_frame": 2 },
	{ "idle": "Omnitrix/Omnitrix Gallery-IDLE", "text_frame": 3 },
	{ "idle": "Omnitrix/Omnitrix Credits-IDLE", "text_frame": 4 },
]

enum MenuState { IDLE, TURNING, SELECTING, CONFIRMING }
var state: int = MenuState.IDLE
var current_index: int = 0


func _ready() -> void:
	omnitrix = AnimateSymbol.new()
	add_child(omnitrix)
	omnitrix.atlas = "res://assets/menus/main/omni_main_menu/"
	omnitrix.symbol = MENU_ITEMS[0].idle  # Default to Storymode
	omnitrix.playing = true
	omnitrix.loop_mode = "Loop"
	omnitrix.finished.connect(_on_animation_finished)

	menu_text = AnimateSymbol.new()
	add_child(menu_text)
	menu_text.atlas = "res://assets/menus/main/omni_main_menu/"
	menu_text.symbol = "Menu UI Text"
	menu_text.frame = 0
	menu_text.position = Vector2(415, 1067)


func _unhandled_input(event: InputEvent) -> void:
	if state != MenuState.IDLE:
		return

	if event.is_action_pressed("ui_left") or (event is InputEventKey and event.keycode == KEY_A and not event.echo):
		do_turn(-1)
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.keycode == KEY_D and not event.echo):
		do_turn(1)
	elif event.is_action_pressed("ui_accept"):
		do_select()


func do_turn(dir: int) -> void:
	current_index = (current_index + dir + len(MENU_ITEMS)) % len(MENU_ITEMS)
	state = MenuState.TURNING
	omnitrix.symbol = TURN_LEFT if dir < 0 else TURN_RIGHT
	omnitrix.playing = true
	omnitrix.loop_mode = "Play Once"


func do_select() -> void:
	state = MenuState.SELECTING
	omnitrix.symbol = ENTER_PRESSED
	omnitrix.playing = true
	omnitrix.loop_mode = "Play Once"


func _on_animation_finished() -> void:
	match state:
		MenuState.TURNING:
			state = MenuState.IDLE
			var item: Dictionary = MENU_ITEMS[current_index]
			omnitrix.symbol = item.idle
			omnitrix.playing = true
			omnitrix.loop_mode = "Loop"
			menu_text.frame = item.text_frame

		MenuState.SELECTING:
			state = MenuState.CONFIRMING
			omnitrix.symbol = OPTION_SELECTED
			omnitrix.playing = true
			omnitrix.loop_mode = "Play Once"

		MenuState.CONFIRMING:
			state = MenuState.IDLE
			match current_index:
				0:
					get_tree().change_scene_to_file("res://songs/hero-destruction/hero_destruction.tscn")
				1:
					print("Freeplay — not implemented yet")
				2:
					print("Settings — not implemented yet")
				3:
					print("Gallery — not implemented yet")
				4:
					print("Credits — not implemented yet")

		_:
			state = MenuState.IDLE
			omnitrix.symbol = MENU_ITEMS[0].idle  # Storymode as default
			omnitrix.playing = true
			omnitrix.loop_mode = "Loop"
