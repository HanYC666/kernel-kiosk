extends Node2D

const ARENA := Rect2(45, 118, 1062, 480)
const PLAYER_HALF := 18.0
const MOVE_SPEED := 250.0
const GRAVITY := 1250.0
const JUMP_SPEED := 510.0
const MAX_HEALTH := 25
const LEVEL_POINTS := [5, 10, 15]
const DECK_SIZE := 30
const QUESTIONS_PER_LEVEL := 10

var player := Vector2(105, 540)
var velocity := Vector2.ZERO
var on_ground := false
var platforms: Array[Rect2] = []
var signals: Array[Dictionary] = []
var answer_bubbles: Array[Dictionary] = []
var pending: Dictionary = {}
var score := 0
var health := MAX_HEALTH
var streak := 0
var round_number := 0
var level_index := 0
var question_index := 0
var level_decks: Array = []
var elapsed := 0.0
var game_active := true
var rng := RandomNumberGenerator.new()

var prompt: Panel
var prompt_title: Label
var prompt_body: Label
var prompt_hint: Label
var hud_score: Label
var hud_round: Label
var hud_health: Label
var health_bar: ProgressBar
var toast: Label
var feedback_color := Color.TRANSPARENT
var feedback_time := 0.0
var transition_time := 0.0
var transition_panel: Panel
var transition_title: Label
var transition_detail: Label

var route_anchors: Array[Vector2] = [
	Vector2(205, 438), Vector2(475, 373), Vector2(735, 438),
	Vector2(960, 348), Vector2(785, 268), Vector2(1030, 548)
]

func _ready() -> void:
	Session.game_id = "platform"
	Session.game_title = "PLATFORM BREACH"
	Session.replay_scene = "res://Main.tscn"
	rng.randomize()
	level_decks = build_level_decks()
	for deck in level_decks:
		assert(deck.size() == DECK_SIZE)
		deck.shuffle()
	build_platforms()
	build_ui()
	spawn_signals()
	queue_redraw()

func build_platforms() -> void:
	configure_level_arena()

func configure_level_arena() -> void:
	if level_index == 0:
		platforms = [
			Rect2(45, 570, 1062, 28), Rect2(120, 475, 190, 20), Rect2(390, 410, 170, 20),
			Rect2(650, 475, 170, 20), Rect2(875, 385, 170, 20), Rect2(700, 300, 170, 20)
		]
		route_anchors = [Vector2(205, 438), Vector2(475, 373), Vector2(735, 438), Vector2(960, 348), Vector2(785, 268), Vector2(1030, 548)]
	elif level_index == 1:
		platforms = [
			Rect2(45, 570, 230, 28), Rect2(350, 570, 170, 28), Rect2(600, 570, 170, 28), Rect2(845, 570, 262, 28),
			Rect2(95, 475, 130, 20), Rect2(305, 420, 125, 20), Rect2(515, 350, 125, 20), Rect2(710, 425, 125, 20), Rect2(900, 340, 135, 20)
		]
		route_anchors = [Vector2(160, 438), Vector2(367, 383), Vector2(577, 313), Vector2(772, 388), Vector2(967, 303), Vector2(1000, 538)]
	else:
		platforms = [
			Rect2(45, 570, 170, 28), Rect2(305, 570, 135, 28), Rect2(535, 570, 135, 28), Rect2(770, 570, 135, 28), Rect2(990, 570, 117, 28),
			Rect2(125, 485, 95, 20), Rect2(300, 420, 90, 20), Rect2(465, 470, 90, 20), Rect2(625, 405, 90, 20), Rect2(790, 455, 90, 20), Rect2(955, 390, 95, 20)
		]
		route_anchors = [Vector2(172, 453), Vector2(345, 388), Vector2(510, 438), Vector2(670, 373), Vector2(835, 423), Vector2(1002, 358)]

func audit(command: String, valid: bool, note: String) -> Dictionary:
	return {"type":"audit", "command":command, "correct":valid, "note":note}

func forge(base: String, correct: String, wrong: String) -> Dictionary:
	return {"type":"forge", "base":base, "correct":correct, "wrong":wrong, "note":"%s is a valid fragment for %s." % [correct, base]}

func build_level_decks() -> Array:
	var level_one: Array[Dictionary] = [
		audit("ls -la", true, "ls accepts -l and -a."), audit("pwd --make-dir", false, "pwd cannot create directories."),
		audit("whoami", true, "whoami prints the current user."), audit("mkdir --file logs", false, "mkdir has no --file option."),
		audit("cat README.md", true, "cat reads a file."), audit("touch --folder cache", false, "touch creates files, not folders."),
		audit("cp source.txt backup.txt", true, "cp copies a file."), audit("mv old.txt new.txt", true, "mv renames or moves a file."),
		audit("echo hello", true, "echo prints text."), audit("date --clock-now", false, "date has no --clock-now option."),
		audit("uname -a", true, "uname -a prints system information."), audit("head -n 5 notes.txt", true, "head accepts a line count."),
		audit("tail --follow-now app.log", false, "tail uses -f or --follow, not --follow-now."), audit("find . -name \"*.gd\"", true, "find accepts -name."),
		audit("grep --delete cache.log", false, "grep searches; it does not delete files."),
		forge("ls", "--all", "--find-hidden"), forge("pwd", "--physical", "--directory"), forge("echo", "-n", "--print-later"),
		forge("mkdir", "--parents", "--parents-only"), forge("rm", "--force", "--force-all"), forge("cp", "--recursive", "--recursive-copy"),
		forge("mv", "--interactive", "--interactive-all"), forge("cat", "--number", "--line-numbers"), forge("date", "--utc", "--utc-time"),
		forge("uname", "--all", "--all-kernel"), forge("head", "--lines=5", "--lines-count"), forge("tail", "--follow", "--follow-now"),
		forge("touch", "--no-create", "--create-only"), forge("find", "-name", "--filename"), forge("grep", "--ignore-case", "--ignore-casing")
	]
	var level_two: Array[Dictionary] = [
		audit("grep -R \"TODO\" src", true, "grep -R searches recursively."), audit("chmod 755 deploy.sh", true, "755 is a valid permission mode."),
		audit("ps aux | grep ssh", true, "This pipe filters process output."), audit("curl -I https://example.com", true, "curl -I requests headers."),
		audit("tar -czf backup.tar.gz project", true, "tar accepts c, z and f together."), audit("grep --replace TODO DONE", false, "grep does not replace text."),
		audit("chmod --execute deploy.sh", false, "chmod needs a mode, not --execute."), audit("ps --kill ssh", false, "ps lists processes; it does not kill them."),
		audit("curl --headerless https://example.com", false, "curl has no --headerless flag."), audit("tar --compress-all files", false, "tar has no --compress-all flag."),
		audit("du -sh build", true, "du supports -s and -h."), audit("df -h", true, "df -h shows readable disk usage."),
		audit("sort -u names.txt", true, "sort -u removes adjacent duplicates."), audit("wc -l access.log", true, "wc -l counts lines."),
		audit("sed --delete-line 4 notes.txt", false, "sed has no --delete-line option."),
		forge("grep", "--recursive", "--delete"), forge("chmod", "755", "--make-executable"), forge("curl", "--head", "--headerless"),
		forge("tar", "-czf", "--zip-files"), forge("du", "--summarize", "--size-human"), forge("df", "--human-readable", "--human-size"),
		forge("sort", "--unique", "--unique-lines-only"), forge("wc", "--lines", "--line-total"), forge("sed", "--quiet", "--no-output-ever"),
		forge("awk", "-F", "--field-break"), forge("cut", "--delimiter=:", "--delimiter-only"), forge("xargs", "--max-args=1", "--batch-count"),
		forge("ssh", "-p", "--port-number"), forge("scp", "-r", "--recursive-copy"), forge("ping", "-c", "--count-only")
	]
	var level_three: Array[Dictionary] = [
		audit("find . -type f -name \"*.log\"", true, "find can filter files by name."), audit("journalctl -u ssh --since today", true, "journalctl accepts a unit and time filter."),
		audit("ss -tulpn", true, "ss accepts these socket display flags."), audit("ip addr show", true, "ip addr show displays interfaces."),
		audit("git log --oneline -5", true, "git log accepts --oneline and a count."),
		audit("find . --delete-name \"*.tmp\"", false, "find has no --delete-name option."), audit("journalctl --service ssh", false, "journalctl uses -u or --unit."),
		audit("ss --open-ports", false, "ss has no --open-ports option."), audit("ip --interfaces", false, "ip needs a subcommand such as addr."), audit("git log --latest 5", false, "git log has no --latest option."),
		audit("cut -d: -f1 /etc/passwd", true, "cut accepts a delimiter and fields."), audit("awk -F: '{print $1}' /etc/passwd", true, "awk accepts -F for field separators."),
		audit("sed -n '1,5p' README.md", true, "sed can print a line range."), audit("xargs -n 1 echo < names.txt", true, "xargs accepts a maximum argument count."),
		audit("git status --short", true, "git status supports --short."),
		forge("find . -type", "f", "--files-only"), forge("journalctl", "--unit=ssh", "--service"), forge("ss", "--tcp", "--open-ports"),
		forge("ip addr", "show", "--interfaces"), forge("git log", "--oneline", "--latest"), forge("cut", "-d:", "--separator"),
		forge("awk", "-F:", "--field-break"), forge("sed", "-n", "--no-output-ever"), forge("xargs", "-n 1", "--batch-count"),
		forge("git status", "--short", "--briefly"), forge("find . -maxdepth", "2", "--depth-limit"), forge("grep", "--line-number", "--line-index"),
		forge("sort", "--key=2", "--key-column"), forge("uniq", "--count", "--count-lines"), forge("tee", "--append", "--append-only")
	]
	return [level_one, level_two, level_three]

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := Panel.new()
	top.position = Vector2(24, 18)
	top.size = Vector2(1104, 76)
	top.add_theme_stylebox_override("panel", panel_style(Color("08130e"), Color("27e38a"), 2))
	layer.add_child(top)
	top.add_child(label("KERNEL KIOSK", Vector2(20, 12), Vector2(450, 28), 25, Color("76ffad")))
	top.add_child(label("PLATFORM BREACH // jump through signal routes", Vector2(22, 44), Vector2(360, 18), 12, Color("8bbfa0")))
	var rankings_button := Button.new()
	rankings_button.text = "RANKINGS"
	rankings_button.position = Vector2(390, 38)
	rankings_button.size = Vector2(100, 28)
	rankings_button.tooltip_text = "Open public rankings"
	rankings_button.add_theme_font_size_override("font_size", 11)
	rankings_button.add_theme_color_override("font_color", Color("d8ffe5"))
	rankings_button.add_theme_stylebox_override("normal", panel_style(Color("103d29"), Color("46ff9a"), 1))
	rankings_button.add_theme_stylebox_override("hover", panel_style(Color("185d3d"), Color("c6ffda"), 2))
	rankings_button.pressed.connect(open_rankings)
	top.add_child(rankings_button)
	hud_score = label("", Vector2(760, 14), Vector2(315, 27), 20, Color("f4ffb2"), HORIZONTAL_ALIGNMENT_RIGHT)
	top.add_child(hud_score)
	hud_round = label("", Vector2(760, 46), Vector2(315, 18), 12, Color("76ffad"), HORIZONTAL_ALIGNMENT_RIGHT)
	top.add_child(hud_round)
	hud_health = label("", Vector2(500, 13), Vector2(205, 20), 13, Color("ff9ca9"), HORIZONTAL_ALIGNMENT_RIGHT)
	top.add_child(hud_health)
	health_bar = ProgressBar.new()
	health_bar.position = Vector2(510, 39)
	health_bar.size = Vector2(195, 14)
	health_bar.max_value = MAX_HEALTH
	health_bar.show_percentage = false
	health_bar.add_theme_stylebox_override("background", panel_style(Color("270b0f"), Color("8e2634"), 1))
	health_bar.add_theme_stylebox_override("fill", panel_style(Color("ca334b"), Color("ff8394"), 1))
	top.add_child(health_bar)
	toast = label("", Vector2(66, 608), Vector2(1020, 26), 13, Color("b9d2c0"), HORIZONTAL_ALIGNMENT_CENTER)
	layer.add_child(toast)
	prompt = Panel.new()
	prompt.position = Vector2(194, 112)
	prompt.size = Vector2(764, 132)
	prompt.visible = false
	prompt.add_theme_stylebox_override("panel", panel_style(Color("091a12"), Color("46ff9a"), 2))
	layer.add_child(prompt)
	prompt_title = label("", Vector2(24, 15), Vector2(710, 25), 18, Color("76ffad"))
	prompt.add_child(prompt_title)
	prompt_body = label("", Vector2(24, 47), Vector2(710, 40), 17, Color("dcffe7"))
	prompt_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_child(prompt_body)
	prompt_hint = label("", Vector2(24, 100), Vector2(710, 18), 12, Color("9acbad"), HORIZONTAL_ALIGNMENT_CENTER)
	prompt.add_child(prompt_hint)
	transition_panel = Panel.new()
	transition_panel.position = Vector2(250, 270)
	transition_panel.size = Vector2(652, 116)
	transition_panel.visible = false
	transition_panel.add_theme_stylebox_override("panel", panel_style(Color("071521"), Color("46d9ff"), 2))
	layer.add_child(transition_panel)
	transition_title = label("", Vector2(20, 19), Vector2(612, 30), 23, Color("8ae9ff"), HORIZONTAL_ALIGNMENT_CENTER)
	transition_panel.add_child(transition_title)
	transition_detail = label("", Vector2(20, 62), Vector2(612, 22), 13, Color("c5f6ff"), HORIZONTAL_ALIGNMENT_CENTER)
	transition_panel.add_child(transition_detail)
	update_hud()

func label(text_value: String, pos: Vector2, size_value: Vector2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var control := Label.new()
	control.text = text_value
	control.position = pos
	control.size = size_value
	control.horizontal_alignment = align
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_color_override("font_color", color)
	return control

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

func spawn_signals() -> void:
	signals = [{"pos":random_route_position(Vector2(-1000, -1000), 0.0), "active":true}]
	toast.text = "A/D or arrows: move   SPACE / W / UP: jump   Touch a signal to start a breach."

func open_rankings() -> void:
	if OS.has_feature("web"):
		var browser_window := JavaScriptBridge.get_interface("window")
		browser_window.location.assign("/rankings.html?game=platform")
	else:
		OS.shell_open("http://127.0.0.1:8009/rankings.html?game=platform")

func _physics_process(delta: float) -> void:
	if not game_active:
		return
	if transition_time > 0.0:
		transition_time = maxf(0.0, transition_time - delta)
		feedback_time = transition_time
		if transition_time == 0.0:
			transition_panel.visible = false
			reactivate_distant_signal()
		queue_redraw()
		return
	move_player(delta)
	if player.y > ARENA.end.y + 100.0:
		handle_fall()
		queue_redraw()
		return
	if pending.is_empty():
		check_signal_touch()
	else:
		elapsed += delta
		check_answer_touch()
	if feedback_time > 0.0:
		feedback_time = maxf(0.0, feedback_time - delta)
	queue_redraw()

func move_player(delta: float) -> void:
	var axis := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): axis -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): axis += 1.0
	velocity.x = move_toward(velocity.x, axis * MOVE_SPEED, 1800.0 * delta)
	if on_ground and (Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)):
		velocity.y = -JUMP_SPEED
		on_ground = false
	velocity.y += GRAVITY * delta
	move_horizontally(delta)
	move_vertically(delta)
	player.x = clamp(player.x, ARENA.position.x + PLAYER_HALF, ARENA.end.x - PLAYER_HALF)

func move_horizontally(delta: float) -> void:
	var next_x := player.x + velocity.x * delta
	var next_rect := player_rect(Vector2(next_x, player.y))
	for platform in platforms:
		if next_rect.intersects(platform):
			if velocity.x > 0.0: next_x = platform.position.x - PLAYER_HALF
			elif velocity.x < 0.0: next_x = platform.end.x + PLAYER_HALF
			velocity.x = 0.0
			next_rect = player_rect(Vector2(next_x, player.y))
	player.x = next_x

func move_vertically(delta: float) -> void:
	var old_y := player.y
	var next_y := player.y + velocity.y * delta
	var next_rect := player_rect(Vector2(player.x, next_y))
	on_ground = false
	for platform in platforms:
		if next_rect.intersects(platform):
			if velocity.y > 0.0 and old_y + PLAYER_HALF <= platform.position.y + 6.0:
				next_y = platform.position.y - PLAYER_HALF
				on_ground = true
			elif velocity.y < 0.0 and old_y - PLAYER_HALF >= platform.end.y - 6.0:
				next_y = platform.end.y + PLAYER_HALF
			velocity.y = 0.0
			next_rect = player_rect(Vector2(player.x, next_y))
	player.y = next_y

func handle_fall() -> void:
	health -= 5
	streak = 0
	player = Vector2(105, 540)
	velocity = Vector2.ZERO
	flash_feedback(Color("d92f45"))
	toast.text = "ROUTE DROP  -5 HEALTH  //  RETURNED TO ENTRY NODE"
	update_hud()
	if health <= 0:
		end_game(false)

func player_rect(center: Vector2) -> Rect2:
	return Rect2(center - Vector2(PLAYER_HALF, PLAYER_HALF), Vector2(PLAYER_HALF * 2.0, PLAYER_HALF * 2.0))

func check_signal_touch() -> void:
	for signal_node in signals:
		if signal_node.active and player.distance_to(signal_node.pos) < 42.0:
			signal_node.active = false
			start_round()
			return

func check_answer_touch() -> void:
	for answer in answer_bubbles:
		if player.distance_to(answer.pos) < 42.0:
			answer_bubbles.clear()
			resolve_answer(answer.correct)
			return

func start_round() -> void:
	round_number += 1
	elapsed = 0.0
	prompt.visible = true
	var challenge: Dictionary = level_decks[level_index][question_index]
	if challenge.type == "forge":
		pending = challenge
		prompt_title.text = "MINIGAME 02 // FLAG FORGE"
		prompt_body.text = "Which fragment creates a valid command?\n\n> " + challenge.base + " [ choose one bubble ]"
		spawn_answer_bubbles(challenge.correct, challenge.wrong)
	else:
		pending = challenge
		prompt_title.text = "MINIGAME 01 // COMMAND AUDIT"
		prompt_body.text = "Does this command and syntax exist?\n\n> " + challenge.command
		spawn_answer_bubbles("VALID", "BROKEN")
	prompt_hint.text = "JUMP INTO THE CORRECT SIGNAL BUBBLE  //  CORRECT: +%d SCORE, +3 HEALTH" % LEVEL_POINTS[level_index]

func spawn_answer_bubbles(correct_label: String, wrong_label: String) -> void:
	var positions := random_route_positions(2, 120.0)
	var left_correct := rng.randi_range(0, 1) == 0
	answer_bubbles = [
		{"pos":positions[0], "correct":left_correct, "label":correct_label if left_correct else wrong_label},
		{"pos":positions[1], "correct":not left_correct, "label":wrong_label if left_correct else correct_label}
	]

func random_route_position(origin: Vector2, minimum_distance: float) -> Vector2:
	var candidates := route_anchors.duplicate()
	candidates.shuffle()
	for candidate in candidates:
		if candidate.distance_to(origin) >= minimum_distance:
			return candidate
	return candidates[0]

func random_route_positions(count: int, minimum_distance: float) -> Array[Vector2]:
	var candidates := route_anchors.duplicate()
	candidates.shuffle()
	var positions: Array[Vector2] = []
	for candidate in candidates:
		if candidate.distance_to(player) >= minimum_distance:
			positions.append(candidate)
			if positions.size() == count:
				return positions
	for candidate in candidates:
		if not positions.has(candidate):
			positions.append(candidate)
			if positions.size() == count:
				return positions
	return positions

func resolve_answer(answer_is_correct: bool) -> void:
	var correct := answer_is_correct
	if pending.type == "audit":
		correct = answer_is_correct == pending.correct
	if correct:
		award_points()
	else:
		penalty("BAD BREACH: " + pending.note)

func award_points() -> void:
	var gained: int = LEVEL_POINTS[level_index]
	score += gained
	health = mini(health + 3, MAX_HEALTH)
	streak += 1
	flash_feedback(Color("1cae60"))
	toast.text = "BREACH ACCEPTED  +%d SCORE  +3 HEALTH  // streak %d" % [gained, streak]
	finish_round()

func penalty(message: String) -> void:
	score -= 2
	health -= 5
	streak = 0
	flash_feedback(Color("d92f45"))
	toast.text = message + "  -2 SCORE  -5 HEALTH"
	if health <= 0:
		end_game(false)
	else:
		finish_round()

func flash_feedback(color: Color) -> void:
	feedback_color = color
	feedback_time = 0.65

func finish_round() -> void:
	prompt.visible = false
	pending.clear()
	answer_bubbles.clear()
	question_index += 1
	if question_index >= QUESTIONS_PER_LEVEL:
		level_index += 1
		question_index = 0
		if level_index >= level_decks.size():
			end_game(true)
			return
		begin_level_transition()
		update_hud()
		return
	update_hud()
	reactivate_distant_signal()

func begin_level_transition() -> void:
	configure_level_arena()
	player = Vector2(105, 540)
	velocity = Vector2.ZERO
	on_ground = false
	transition_time = 2.2
	feedback_color = Color("19bce5")
	feedback_time = transition_time
	transition_panel.visible = true
	transition_title.text = "LEVEL %d // FIREWALL RECONFIGURED" % [level_index + 1]
	transition_detail.text = "ROUTE MAP SHIFTED  //  NARROWER NODES  //  +%d SCORE PER BREACH" % LEVEL_POINTS[level_index]
	toast.text = "NETWORK TOPOLOGY SHIFT IN PROGRESS"

func reactivate_distant_signal() -> void:
	signals = [{"pos":random_route_position(player, 220.0), "active":true}]

func end_game(won: bool) -> void:
	game_active = false
	Session.final_score = score
	Session.completed_game_id = Session.game_id
	Session.completed_game_title = Session.game_title
	Session.completed_replay_scene = Session.replay_scene
	get_tree().change_scene_to_file("res://WinScene.tscn" if won else "res://DeathScene.tscn")

func update_hud() -> void:
	hud_score.text = "SCORE  %03d" % score
	hud_health.text = "HEALTH  %02d / %02d" % [health, MAX_HEALTH]
	health_bar.value = health
	hud_round.text = "LEVEL %d  //  %02d / %02d  //  +%d SCORE" % [level_index + 1, question_index + 1, QUESTIONS_PER_LEVEL, LEVEL_POINTS[level_index]]

func _draw() -> void:
	var flash_duration := 2.2 if transition_time > 0.0 else 0.65
	var flash_strength := feedback_time / flash_duration
	var arena_fill := Color("07140d").lerp(feedback_color.darkened(0.58), flash_strength)
	var arena_border := Color("1f9d5b").lerp(feedback_color.lightened(0.1), flash_strength)
	draw_rect(Rect2(Vector2.ZERO, Vector2(1152, 648)), Color("030805").lerp(feedback_color.darkened(0.86), flash_strength))
	draw_rect(ARENA, arena_fill, true)
	draw_rect(ARENA, arena_border, false, 2)
	for x in range(int(ARENA.position.x), int(ARENA.end.x), 44): draw_line(Vector2(x, ARENA.position.y), Vector2(x, ARENA.end.y), Color(0.08, 0.28, 0.16, 0.3), 1)
	for y in range(int(ARENA.position.y), int(ARENA.end.y), 44): draw_line(Vector2(ARENA.position.x, y), Vector2(ARENA.end.x, y), Color(0.08, 0.28, 0.16, 0.3), 1)
	if transition_time > 0.0:
		var scan_y := ARENA.position.y + (2.2 - transition_time) / 2.2 * ARENA.size.y
		draw_line(Vector2(ARENA.position.x, scan_y), Vector2(ARENA.end.x, scan_y), Color("8ae9ff"), 3)
		for x in range(int(ARENA.position.x), int(ARENA.end.x), 88):
			draw_line(Vector2(x, ARENA.position.y), Vector2(x, ARENA.end.y), Color(0.18, 0.82, 1.0, 0.22), 1)
	for platform in platforms:
		draw_rect(platform, Color("0b3b24"), true)
		draw_rect(platform, Color("41d982"), false, 2)
		draw_line(platform.position + Vector2(8, 8), Vector2(platform.end.x - 8, platform.position.y + 8), Color("1e8c55"), 1)
	for signal_node in signals:
		if signal_node.active:
			draw_signal(signal_node.pos, "?", Color("67ffa6"))
	for answer in answer_bubbles:
		draw_signal(answer.pos, answer.label, Color("f4ffb2"))
	draw_circle(player, PLAYER_HALF, Color("071d10"))
	draw_circle(player, PLAYER_HALF, Color("84ffb1"), false, 2)
	draw_rect(Rect2(player + Vector2(-11, -7), Vector2(22, 14)), Color("1ec969"), false, 1)
	draw_string(ThemeDB.fallback_font, player + Vector2(-8, 5), ">_", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("b9ffd2"))

func draw_signal(pos: Vector2, signal_label: String, rim: Color) -> void:
	var pulse := sin(Time.get_ticks_msec() / 420.0 + pos.x) * 2.0
	draw_circle(pos, 24 + pulse, Color(rim, 0.14))
	draw_circle(pos, 17, Color("0e5933"))
	draw_arc(pos, 17, 0, TAU, 18, rim, 2)
	var width := 100.0 if signal_label.length() > 4 else 32.0
	draw_string(ThemeDB.fallback_font, pos + Vector2(-width / 2.0, 5), signal_label, HORIZONTAL_ALIGNMENT_CENTER, width, 12, Color("e1ffea"))
