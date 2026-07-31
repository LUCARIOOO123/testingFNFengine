extends Node2D

const OMNITRIX_PNG := "res://assets/menu/omnitrix/omnitrix_menu.png"
const OMNITRIX_XML := "res://assets/menu/omnitrix/omnitrix_menu.xml"

const IDLE := "Idle waiting"
const TURN_LEFT := "TURN L"
const TURN_RIGHT := "TURN R"
const ENTER_PRESSED := "EnterPressed Anim"
const OPTION_SELECTED := "OptionSelected Anim"

const MENU_ITEMS := [
	{ "idle": "Storymode-IDLE" },
	{ "idle": "Freeplay-IDLE" },
	{ "idle": "Settings-IDLE" },
	{ "idle": "Gallery-IDLE" },
	{ "idle": "Credits-IDLE" },
]

enum MenuState { IDLE, TURNING, SELECTING, CONFIRMING }
var state: int = MenuState.IDLE
var current_index: int = 0

var omnitrix_sprite: AnimatedSprite2D


func _ready() -> void:
	var sprite_frames := _build_sprite_frames(OMNITRIX_PNG, OMNITRIX_XML)

	omnitrix_sprite = AnimatedSprite2D.new()
	omnitrix_sprite.sprite_frames = sprite_frames
	omnitrix_sprite.animation_finished.connect(_on_animation_finished)
	omnitrix_sprite.scale = Vector2(0.55, 0.55)
	omnitrix_sprite.position = Vector2(683, 384)
	add_child(omnitrix_sprite)

	omnitrix_sprite.play(MENU_ITEMS[0].idle)


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
	omnitrix_sprite.sprite_frames.set_animation_loop(TURN_LEFT, false)
	omnitrix_sprite.sprite_frames.set_animation_loop(TURN_RIGHT, false)
	omnitrix_sprite.play(TURN_LEFT if dir < 0 else TURN_RIGHT)


func do_select() -> void:
	state = MenuState.SELECTING
	omnitrix_sprite.sprite_frames.set_animation_loop(ENTER_PRESSED, false)
	omnitrix_sprite.play(ENTER_PRESSED)


func _on_animation_finished() -> void:
	match state:
		MenuState.TURNING:
			state = MenuState.IDLE
			var item: Dictionary = MENU_ITEMS[current_index]
			omnitrix_sprite.play(item.idle)

		MenuState.SELECTING:
			state = MenuState.CONFIRMING
			omnitrix_sprite.sprite_frames.set_animation_loop(OPTION_SELECTED, false)
			omnitrix_sprite.play(OPTION_SELECTED)

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
			omnitrix_sprite.play(MENU_ITEMS[0].idle)


func _build_sprite_frames(png_path: String, xml_path: String) -> SpriteFrames:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(png_path))
	var texture: ImageTexture = ImageTexture.create_from_image(image)

	var regex := RegEx.new()
	regex.compile("\\d+$")

	var frame_groups := {}
	var anim_order: Array[String] = []

	var xml := XMLParser.new()
	xml.open(ProjectSettings.globalize_path(xml_path))

	while xml.read() == OK:
		if xml.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		if xml.get_node_name().to_lower() != "subtexture":
			continue

		var full_name: String = xml.get_named_attribute_value("name")
		var region := Rect2(
			xml.get_named_attribute_value("x").to_float(),
			xml.get_named_attribute_value("y").to_float(),
			xml.get_named_attribute_value("width").to_float(),
			xml.get_named_attribute_value("height").to_float()
		)

		var margin := Rect2(0, 0, 0, 0)
		if xml.has_attribute("frameX"):
			margin = Rect2(
				-xml.get_named_attribute_value("frameX").to_float(),
				-xml.get_named_attribute_value("frameY").to_float(),
				xml.get_named_attribute_value("frameWidth").to_float() - region.size.x,
				xml.get_named_attribute_value("frameHeight").to_float() - region.size.y
			)

		var idx: int = 0
		var anim_name: String = full_name
		var match: RegExMatch = regex.search(full_name)
		if match:
			idx = int(match.get_string())
			anim_name = full_name.substr(0, full_name.length() - match.get_string().length())
		anim_name = anim_name.strip_edges()

		if not frame_groups.has(anim_name):
			frame_groups[anim_name] = []
			anim_order.append(anim_name)

		var last_frames: Array = frame_groups[anim_name]
		if last_frames.size() > 0:
			var last: Dictionary = last_frames.back()
			if last["region"] == region:
				last["duration"] += 1
				continue

		frame_groups[anim_name].append({
			"index": idx,
			"region": region,
			"margin": margin,
			"duration": 1,
		})

	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation("default")

	var loop_anims: Array[String] = [
		"Idle waiting",
		"Storymode-IDLE",
		"Freeplay-IDLE",
		"Settings-IDLE",
		"Gallery-IDLE",
		"Credits-IDLE",
	]

	# Animations whose spritesheet contains only one direction of a cycle
	# (glowing orb grows/pulses then must return). Played forward + reversed
	# so the loop point is seamless instead of jumping back to the start.
	var ping_pong_anims: Array[String] = [
		"Idle waiting",
	]

	for anim_name in anim_order:
		sprite_frames.add_animation(anim_name)
		sprite_frames.set_animation_speed(anim_name, 24.0)
		sprite_frames.set_animation_loop(anim_name, anim_name in loop_anims)

		var frames: Array = frame_groups[anim_name]
		frames.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["index"] < b["index"])

		var ordered_frames: Array = []
		if anim_name in ping_pong_anims and frames.size() > 1:
			ordered_frames.append_array(frames)
			for i in range(frames.size() - 2, 0, -1):
				ordered_frames.append(frames[i])
		else:
			ordered_frames = frames

		for frame_data: Dictionary in ordered_frames:
			var atlas_tex := AtlasTexture.new()
			atlas_tex.atlas = texture
			atlas_tex.region = frame_data["region"]
			atlas_tex.filter_clip = true
			if frame_data["margin"] != Rect2(0, 0, 0, 0):
				atlas_tex.margin = frame_data["margin"]
			sprite_frames.add_frame(anim_name, atlas_tex, frame_data["duration"])

	return sprite_frames
