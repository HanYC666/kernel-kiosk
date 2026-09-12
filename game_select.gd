extends Node2D

func _ready() -> void:
	build_ui()
	queue_redraw()

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := Panel.new()
	panel.position = Vector2(178, 110)
	panel.size = Vector2(796, 430)
	panel.add_theme_stylebox_override("panel", style(Color("08130e"), Color("46ff9a"), 2))
	layer.add_child(panel)
	panel.add_child(label("KERNEL KIOSK", Vector2(38, 34), Vector2(720, 42), 31, Color("76ffad"), HORIZONTAL_ALIGNMENT_CENTER))
	panel.add_child(label("SELECT A NETWORK DRILL", Vector2(38, 80), Vector2(720, 22), 14, Color("9acbad"), HORIZONTAL_ALIGNMENT_CENTER))
	var platform := button("PLATFORM BREACH", Vector2(66, 140), Vector2(310, 126), Color("46ff9a"))
	platform.tooltip_text = "Move, jump, and choose signal bubbles"
	platform.pressed.connect(func(): get_tree().change_scene_to_file("res://Main.tscn"))
	panel.add_child(platform)
	var typing := button("TYPING TERMINAL", Vector2(420, 140), Vector2(310, 126), Color("46d9ff"))
	typing.tooltip_text = "Type Linux command answers into a terminal"
	typing.pressed.connect(func(): get_tree().change_scene_to_file("res://TypingScene.tscn"))
	panel.add_child(typing)
	panel.add_child(label("MOVEMENT ROUTE", Vector2(66, 282), Vector2(310, 20), 13, Color("b9ffd2"), HORIZONTAL_ALIGNMENT_CENTER))
	panel.add_child(label("TERMINAL INPUT", Vector2(420, 282), Vector2(310, 20), 13, Color("b9f4ff"), HORIZONTAL_ALIGNMENT_CENTER))
	var rankings := button("VIEW RANKINGS", Vector2(273, 340), Vector2(250, 48), Color("f4ffb2"))
	rankings.pressed.connect(open_rankings)
	panel.add_child(rankings)

func open_rankings() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.get_interface("window").location.assign("/rankings.html?game=platform")
	else:
		OS.shell_open("http://127.0.0.1:8009/rankings.html?game=platform")

func label(value: String, pos: Vector2, label_size: Vector2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var node := Label.new()
	node.text = value
	node.position = pos
	node.size = label_size
	node.horizontal_alignment = align
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	return node

func button(value: String, pos: Vector2, button_size: Vector2, rim: Color) -> Button:
	var node := Button.new()
	node.text = value
	node.position = pos
	node.size = button_size
	node.add_theme_font_size_override("font_size", 16)
	node.add_theme_color_override("font_color", Color("d8ffe5"))
	node.add_theme_stylebox_override("normal", style(Color("103d29"), rim, 1))
	node.add_theme_stylebox_override("hover", style(Color("185d3d"), Color("e1ffea"), 2))
	return node

func style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.corner_radius_top_left = 3
	box.corner_radius_top_right = 3
	box.corner_radius_bottom_left = 3
	box.corner_radius_bottom_right = 3
	return box

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1152, 648)), Color("030805"))
	for x in range(24, 1152, 48): draw_line(Vector2(x, 0), Vector2(x, 648), Color("0a4328"), 1)
	for y in range(24, 648, 48): draw_line(Vector2(0, y), Vector2(1152, y), Color("0a4328"), 1)
