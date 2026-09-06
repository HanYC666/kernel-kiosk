extends Node2D

@export var won := false

var title: Label
var detail: Label
var status: Label
var name_input: LineEdit
var publish: Button
var replay: Button
var rankings: Button

func _ready() -> void:
	build_ui()
	queue_redraw()

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := Panel.new()
	panel.position = Vector2(202, 142)
	panel.size = Vector2(748, 398)
	panel.add_theme_stylebox_override("panel", panel_style(Color("091a12"), accent(), 2))
	layer.add_child(panel)
	title = Label.new()
	title.position = Vector2(38, 38)
	title.size = Vector2(672, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 29)
	title.add_theme_color_override("font_color", accent())
	title.text = "ROOT ACCESS GRANTED" if won else "CONNECTION TERMINATED"
	panel.add_child(title)
	detail = Label.new()
	detail.position = Vector2(54, 103)
	detail.size = Vector2(640, 74)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 17)
	detail.add_theme_color_override("font_color", Color("dcffe7"))
	detail.text = "The network is stable. You earned %d score points." % Session.final_score if won else "Health reached zero. The kiosk locked your session at %d score points." % Session.final_score
	panel.add_child(detail)
	status = Label.new()
	status.position = Vector2(48, 191)
	status.size = Vector2(650, 25)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 13)
	status.add_theme_color_override("font_color", Color("9acbad"))
	status.text = "Publish your score to the public board, or keep this session local."
	panel.add_child(status)
	name_input = LineEdit.new()
	name_input.position = Vector2(54, 231)
	name_input.size = Vector2(430, 48)
	name_input.visible = false
	name_input.placeholder_text = "public display name"
	name_input.add_theme_font_size_override("font_size", 17)
	name_input.add_theme_stylebox_override("normal", panel_style(Color("06110b"), Color("2e9e66"), 1))
	name_input.text_submitted.connect(func(_text): submit_score())
	panel.add_child(name_input)
	publish = make_button("PUBLISH SCORE", Vector2(54, 244), Vector2(205, 52))
	publish.pressed.connect(on_publish_pressed)
	panel.add_child(publish)
	rankings = make_button("RANKINGS", Vector2(271, 244), Vector2(205, 52))
	rankings.pressed.connect(open_rankings)
	panel.add_child(rankings)
	replay = make_button("PLAY AGAIN", Vector2(488, 244), Vector2(206, 52))
	replay.pressed.connect(func(): get_tree().change_scene_to_file("res://Main.tscn"))
	panel.add_child(replay)

func on_publish_pressed() -> void:
	if name_input.visible:
		submit_score()
	else:
		show_name_field()

func show_name_field() -> void:
	name_input.visible = true
	name_input.grab_focus()
	publish.text = "SUBMIT SCORE"
	publish.position = Vector2(500, 231)
	publish.size = Vector2(194, 48)
	rankings.position = Vector2(54, 295)
	rankings.size = Vector2(314, 44)
	replay.position = Vector2(380, 295)
	replay.size = Vector2(314, 44)
	status.text = "Only the chosen display name and final score are sent. Rankings and replay remain available."

func submit_score() -> void:
	var player_name := name_input.text.strip_edges().substr(0, 24)
	if player_name.is_empty():
		status.text = "Enter a display name before submitting."
		return
	navigate_to_rankings("/rankings.html?name=" + player_name.uri_encode() + "&score=" + str(Session.final_score))
	status.text = "Opening rankings to publish your score..."
	publish.disabled = true

func open_rankings(query := "") -> void:
	navigate_to_rankings("/rankings.html" + query)

func navigate_to_rankings(page: String) -> void:
	if OS.has_feature("web"):
		var browser_window := JavaScriptBridge.get_interface("window")
		browser_window.location.assign(page)
	else:
		OS.shell_open("http://127.0.0.1:8009" + page)

func make_button(button_text: String, pos: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = button_text
	button.position = pos
	button.size = button_size
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color("d8ffe5"))
	button.add_theme_stylebox_override("normal", panel_style(Color("103d29"), accent(), 1))
	button.add_theme_stylebox_override("hover", panel_style(Color("185d3d"), Color("c6ffda"), 2))
	return button

func panel_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style

func accent() -> Color:
	return Color("76ffad") if won else Color("ff5a73")

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1152, 648)), Color("030805"))
	for x in range(40, 1152, 46): draw_line(Vector2(x, 0), Vector2(x, 648), Color("0c3c23"), 1)
	for y in range(30, 648, 46): draw_line(Vector2(0, y), Vector2(1152, y), Color("0c3c23"), 1)
	for i in 14:
		var position := Vector2(70 + (i * 79) % 1020, 80 + (i * 113) % 500)
		draw_circle(position, 3 + (i % 3), accent().darkened(0.45))
	if won:
		draw_string(ThemeDB.fallback_font, Vector2(462, 574), "// SYSTEM RESTORED //", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("76ffad"))
	else:
		draw_string(ThemeDB.fallback_font, Vector2(432, 574), "// ACCESS REVOKED //", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ff8394"))
