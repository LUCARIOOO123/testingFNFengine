@tool
@icon('animate_symbol.svg')
class_name AnimateSymbol extends Node2D
## Node that lets you play Adobe Animate Texture Atlases
## in Godot.


## The folder path to the atlas that is loaded.
## [br][br][b]Note[/b]: This automatically reloads the atlas when
## changed.
@export_dir var atlas: String:
	set(v):
		atlas = v
		load_atlas(atlas)


## The current frame of the animation.
## [br][br][b]Note[/b]: This automatically redraws the entire
## atlas when changed.
@export var frame: int = 0:
	set(v):
		frame = v
		queue_redraw()

## The current symbol used by the animation. Empty uses the timeline symbol.
## [br][br][b]Note[/b]: This automatically sets [member frame] to 0 when
## changed. (Resetting the current animation)
@export var symbol: String = '':
	set(v):
		symbol = v
		symbol_changed.emit(v)
		frame = 0
		_timer = 0.0
		_continuous_frame = 0

## Keeps track of whether or not the sprite is being animated automatically.
@export var playing: bool = false

## Defines what happens when the end of the animation is reached.
## [br][br]Loop loops the animation forever and Play Once just stops.
@export_enum('Loop', 'Play Once') var loop_mode: String = 'Loop'

@export_tool_button('Cache Atlas', 'Save') var cache_atlas := _cache_atlas
@export_tool_button('Reload Atlas', 'Reload') var reload_atlas := _reload_atlas

var _timeline:
	get:
		if not is_instance_valid(_animation):
			return null
		return _animation.symbol_dictionary.get(symbol, _animation.timeline)

var _collections: Array[SpriteCollection]
var _animation: AtlasAnimation
var _timer: float = 0.0
var _current_transform: Transform2D = Transform2D.IDENTITY
var _canvas_items: Array[RID] = []
var _filters: Array[Filter] = []
var _frame_offset: int = 0
var _continuous_frame: int = 0
var _content_frame_lists: Dictionary = {}
var _loop_frame_lists: Dictionary = {}


signal finished
signal symbol_changed(symbol: String)


func _process(delta: float) -> void:
	if not is_instance_valid(_animation):
		if frame > 0:
			frame = 0
		return
	
	if not playing:
		return
	
	_timer += delta
	if _timer >= 1.0 / _animation.framerate:
		var frame_diff := _timer / (1.0 / _animation.framerate)
		frame += floori(frame_diff)
		_continuous_frame += floori(frame_diff)
		_timer -= (1.0 / _animation.framerate) * frame_diff
		if frame > _timeline.length - 1:
			match loop_mode:
				'Loop':
					frame = 0
				_:
					if playing:
						playing = false
						finished.emit()
					frame = _timeline.length - 1


func _cache_atlas() -> void:
	var parsed: ParsedAtlas = ParsedAtlas.new()
	parsed.collections = _collections
	parsed.animation = _animation
	
	var atlas_directory := atlas
	if not atlas_directory.get_extension().is_empty():
		atlas_directory = atlas_directory.get_base_dir()
	
	var err := ResourceSaver.save(parsed, \
			'%s/Animation.res' % [atlas_directory], ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		printerr(err)


func _reload_atlas() -> void:
	var atlas_directory := atlas
	if not atlas_directory.get_extension().is_empty():
		atlas_directory = atlas_directory.get_base_dir()
	load_atlas(atlas_directory, false)


## Loads a new atlas from the specified [param path].
func load_atlas(path: String, use_cache: bool = true) -> void:
	_collections.clear()
	_animation = null
	
	var atlas_directory := path
	if not atlas_directory.get_extension().is_empty():
		atlas_directory = atlas_directory.get_base_dir()
	
	var parsed_path := '%s/Animation.res' % atlas_directory
	if ResourceLoader.exists(parsed_path) and use_cache:
		var parsed: ParsedAtlas = load(parsed_path)
		_animation = parsed.animation
		_collections = parsed.collections
		_clear_items()
		_continuous_frame = 0
		frame = 0
		return
	
	var files := ResourceLoader.list_directory(atlas_directory)
	for file in files:
		if file.begins_with('spritemap') and file.ends_with('.json'):
			var spritemap_string := FileAccess.get_file_as_string('%s/%s' % [atlas_directory, file])
			var spritemap_json: Variant = JSON.parse_string(spritemap_string)
			if spritemap_json == null:
				printerr('Failed to parse %s' % file)
				return
			var sprite_collection := SpriteCollection.load_from_json(
				spritemap_json,
				load('%s/%s.png' % [atlas_directory, file.get_basename()])
			)
			_collections.push_back(sprite_collection)
	
	var animation_string := FileAccess.get_file_as_string('%s/Animation.json' % [atlas_directory])
	if animation_string.is_empty():
		return
	
	var animation_json: Variant = JSON.parse_string(animation_string)
	if animation_json == null:
		return
	_animation = AtlasAnimation.load_from_json(animation_json)
	_continuous_frame = 0
	frame = 0


func _draw_symbol(element: Element) -> void:
	var draw_name: StringName = element.name
	if draw_name == "glowing orb Fast":
		draw_name = "glowing orb"
	if not _animation.symbol_dictionary.has(draw_name):
		printerr('Tried to draw invalid symbol "%s"' % [draw_name])
		return
	
	_filters = element.filters
	var symbol_timeline: Timeline = _animation.symbol_dictionary.get(draw_name)
	var sym := element as SymbolElement
	var nested_frame: int = sym.frame + _frame_offset
	
	if symbol_timeline.length > 0 and sym != null:
		match sym.loop_mode:
			SymbolElement.SymbolLoopMode.LOOP:
				if draw_name == "glowing orb":
					var orb_content := _get_content_frames(symbol_timeline)
					orb_content = orb_content.filter(func(f): return f >= 7 and f <= 15)
					if not orb_content.is_empty():
						var cycle_len := orb_content.size() * 2 - 2
						var idx := _continuous_frame % cycle_len
						idx = idx if idx < orb_content.size() else cycle_len - idx
						nested_frame = orb_content[idx]
					else:
						nested_frame = 0
				else:
					var content := _get_content_frames(symbol_timeline)
					if not content.is_empty():
						var idx := (_continuous_frame + sym.frame) % content.size()
						if content.size() > 1:
							var cycle_len := content.size() * 2 - 2
							idx = (_continuous_frame + sym.frame) % cycle_len
							idx = idx if idx < content.size() else cycle_len - idx
						nested_frame = content[idx]
					else:
						nested_frame = 0
			SymbolElement.SymbolLoopMode.ONE_SHOT:
				nested_frame = mini(nested_frame, symbol_timeline.length - 1)
			SymbolElement.SymbolLoopMode.FREEZE_FRAME:
				nested_frame = sym.frame
			_:
				nested_frame = mini(nested_frame, symbol_timeline.length - 1)
	
	var saved_offset := _frame_offset
	_frame_offset = 0
	_draw_timeline(symbol_timeline, nested_frame)
	_frame_offset = saved_offset


func _draw_sprite(element: Element) -> void:
	for collection in _collections:
		if not collection.map.has(element.name):
			continue
		var use_item: bool = false
		var sprite: CollectedSprite = collection.map.get(element.name)
		var item: RID
		if use_item:
			item = RenderingServer.canvas_item_create()
			_canvas_items.push_back(item)
			RenderingServer.canvas_item_set_z_index(item, 
					mini(_canvas_items.size() - 1, RenderingServer.CANVAS_ITEM_Z_MAX))
			RenderingServer.canvas_item_set_parent(item, get_canvas_item())
			RenderingServer.canvas_item_set_transform(item, _current_transform)
			
			#if not _filters.is_empty():
				#var filter_material: ShaderMaterial = _filter_material.duplicate()
				#RenderingServer.canvas_item_set_material(item, filter_material.get_rid())
				#
				#for filter in _filters:
					#match filter.type:
						#Filter.FilterType.BLUR:
							#filter_material.set_shader_parameter('test', 4.0)
		else:
			draw_set_transform_matrix(_current_transform)
		
		if is_instance_valid(sprite.custom_texture):
			if use_item:
				RenderingServer.canvas_item_add_texture_rect(
					item,
					Rect2(
						Vector2.ZERO,
						Vector2(sprite.rect.size.y, sprite.rect.size.x) \
								* (Vector2.ONE / collection.scale)
					),
					sprite.custom_texture
				)
			else:
				draw_texture_rect(
					sprite.custom_texture,
					Rect2(
						Vector2.ZERO,
						Vector2(sprite.rect.size.y, sprite.rect.size.x) \
								* (Vector2.ONE / collection.scale)
					),
					false
				)
		else:
			if use_item:
				RenderingServer.canvas_item_add_texture_rect_region(
					item,
					Rect2(Vector2.ZERO, Vector2(sprite.rect.size) * (Vector2.ONE / collection.scale)),
					collection.texture,
					Rect2(sprite.rect)
				)
			else:
				draw_texture_rect_region(
					collection.texture,
					Rect2(Vector2.ZERO, Vector2(sprite.rect.size) * (Vector2.ONE / collection.scale)),
					Rect2(sprite.rect),
				)
		return
	printerr('Tried to draw invalid sprite "%s"' % [element.name])


func _get_content_frames(timeline: Timeline) -> Array[int]:
	if _content_frame_lists.has(timeline):
		return _content_frame_lists[timeline]
	var result: Array[int] = []
	for i in timeline.length:
		var has_content := false
		for layer in timeline.layers:
			for lf in layer.frames:
				if lf.index <= i and i < lf.index + lf.duration:
					if not lf.elements.is_empty():
						has_content = true
						break
			if has_content:
				break
		if has_content:
			result.push_back(i)
	_content_frame_lists[timeline] = result
	return result


func _is_identity_frame(timeline: Timeline, frame_idx: int) -> bool:
	for layer in timeline.layers:
		for lf in layer.frames:
			if lf.index <= frame_idx and frame_idx < lf.index + lf.duration:
				if lf.elements.is_empty():
					return true
				for e in lf.elements:
					if e.transform != Transform2D.IDENTITY:
						return false
	return true


func _get_loop_frames(timeline: Timeline) -> Array[int]:
	if _loop_frame_lists.has(timeline):
		return _loop_frame_lists[timeline]
	var all_content := _get_content_frames(timeline)
	var start := 0
	while start < all_content.size() and _is_identity_frame(timeline, all_content[start]):
		start += 1
	var end := all_content.size() - 1
	while end >= start and _is_identity_frame(timeline, all_content[end]):
		end -= 1
	var result := all_content.slice(start, end + 1)
	_loop_frame_lists[timeline] = result
	return result


func _draw_timeline(timeline: Timeline, target_frame: int) -> void:
	var layer_transform := _current_transform
	for i in timeline.layers.size():
		var layer: Layer = timeline.layers[timeline.layers.size() - (i + 1)]
		for layer_frame in layer.frames:
			if target_frame < layer_frame.index:
				continue
			if target_frame > layer_frame.index + layer_frame.duration - 1:
				continue
			_frame_offset = target_frame - layer_frame.index
			for element in layer_frame.elements:
				var prev := _current_transform
				_current_transform = layer_transform
				_current_transform *= element.transform
				match element.type:
					Element.ElementType.SYMBOL:
						_draw_symbol(element)
					Element.ElementType.SPRITE:
						_draw_sprite(element)


func _clear_items() -> void:
	RenderingServer.canvas_item_clear(get_canvas_item())
	while not _canvas_items.is_empty():
		var item: RID = _canvas_items.pop_back()
		RenderingServer.free_rid(item)


func _exit_tree() -> void:
	_clear_items()


func _draw() -> void:
	_clear_items()
	
	if not is_instance_valid(_timeline):
		return
	_current_transform = Transform2D.IDENTITY
	_frame_offset = 0
	_draw_timeline(_timeline, frame)
