extends CanvasLayer

var fps_label: Label
var mem_label: Label
var peak_label: Label
var peak_bytes: float = 0.0
var time_since_peak: float = 0.0
const PEAK_RESET_TIME: float = 300.0

func _enter_tree() -> void:
	Engine.max_fps = 144
	layer = 128
	fps_label = Label.new()
	fps_label.name = "FPSLabel"
	fps_label.add_theme_font_size_override("font_size", 16)
	fps_label.add_theme_color_override("font_color", Color.WHITE)
	fps_label.add_theme_constant_override("outline_size", 2)
	fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fps_label.position = Vector2(10, 10)
	add_child(fps_label)

	mem_label = Label.new()
	mem_label.name = "MemLabel"
	mem_label.add_theme_font_size_override("font_size", 16)
	mem_label.add_theme_color_override("font_color", Color.WHITE)
	mem_label.add_theme_constant_override("outline_size", 2)
	mem_label.add_theme_color_override("font_outline_color", Color.BLACK)
	mem_label.position = Vector2(10, 30)
	add_child(mem_label)

	peak_label = Label.new()
	peak_label.name = "PeakLabel"
	peak_label.add_theme_font_size_override("font_size", 16)
	peak_label.add_theme_color_override("font_color", Color.WHITE)
	peak_label.add_theme_constant_override("outline_size", 2)
	peak_label.add_theme_color_override("font_outline_color", Color.BLACK)
	peak_label.position = Vector2(10, 50)
	add_child(peak_label)

static func _format_bytes(bytes: float) -> String:
	var gb := bytes / (1024.0 * 1024.0 * 1024.0)
	if gb >= 1.0:
		return "%.2f GB" % gb
	var mb := bytes / (1024.0 * 1024.0)
	return "%.1f MB" % mb

func _process(delta: float) -> void:
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	fps_label.text = "FPS: %d" % fps
	if fps < 30:
		fps_label.add_theme_color_override("font_color", Color.RED)
	else:
		fps_label.add_theme_color_override("font_color", Color.WHITE)

	var mem_bytes := Performance.get_monitor(Performance.MEMORY_STATIC)
	mem_label.text = "Memory: %s" % _format_bytes(mem_bytes)

	time_since_peak += delta
	if mem_bytes > peak_bytes:
		peak_bytes = mem_bytes
		time_since_peak = 0.0
	elif time_since_peak >= PEAK_RESET_TIME:
		peak_bytes = mem_bytes
		time_since_peak = 0.0

	peak_label.text = "Memory Peak: %s" % _format_bytes(peak_bytes)
