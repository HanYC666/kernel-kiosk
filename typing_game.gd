extends Node2D

const QUESTIONS_PER_LEVEL := 8
const DECK_SIZE := 50
const LEVEL_POINTS := [5, 10, 15]
const MAX_HEALTH := 25

var decks: Array = []
var level := 0
var question := 0
var score := 0
var health := MAX_HEALTH
var streak := 0
var active: Dictionary = {}
var prompt_label: Label
var hint_label: Label
var status_label: Label
var hud_label: Label
var input: LineEdit
var submit: Button
var terminal: Panel
var feedback_time := 0.0
var feedback_color := Color.TRANSPARENT
var awaiting_advance := false

func _ready() -> void:
	Session.game_id = "typing"
	Session.game_title = "TYPING TERMINAL"
	Session.replay_scene = "res://TypingScene.tscn"
	decks = build_decks()
	for deck in decks:
		assert(deck.size() == DECK_SIZE)
		deck.shuffle()
	build_ui()
	load_question()
	queue_redraw()

func make_question(prompt: String, answer: String, hint: String) -> Dictionary:
	return {"prompt": prompt, "answer": answer, "hint": hint}

func build_decks() -> Array:
	var basic: Array[Dictionary] = []
	for item in [
		["Print the current directory", "pwd"], ["List files", "ls"], ["Show the current user", "whoami"], ["Print text", "echo"], ["Create an empty file", "touch"],
		["Create a directory", "mkdir"], ["Copy a file", "cp"], ["Move or rename a file", "mv"], ["Read a file", "cat"], ["Remove a file", "rm"],
		["Show the current date", "date"], ["Show system information", "uname"], ["Show the first lines of a file", "head"], ["Show the last lines of a file", "tail"], ["Search file contents", "grep"],
		["Find files in a directory tree", "find"], ["Count words or lines", "wc"], ["Sort text", "sort"], ["Remove adjacent duplicate lines", "uniq"], ["Print disk usage", "du"],
		["Show free disk space", "df"], ["Change file permissions", "chmod"], ["Change file owner", "chown"], ["Show running processes", "ps"], ["Stop a process", "kill"],
		["Show network sockets", "ss"], ["Show IP addresses", "ip"], ["Download a URL", "curl"], ["Securely connect to a host", "ssh"], ["Copy files over SSH", "scp"],
		["Archive files", "tar"], ["Compress a file", "gzip"], ["Extract a gzip archive", "gunzip"], ["Print environment variables", "env"], ["Set a shell variable", "export"],
		["Show command history", "history"], ["Clear the terminal", "clear"], ["Edit with a terminal editor", "nano"], ["Print a file one page at a time", "less"], ["Follow a log file", "tail -f"],
		["Show a file's type", "file"], ["Compare two files", "diff"], ["Create a symbolic link", "ln -s"], ["Change directory", "cd"], ["Return to home directory", "cd ~"],
		["List hidden files", "ls -a"], ["List detailed files", "ls -l"], ["Show all system details", "uname -a"], ["Show command help", "man"], ["Exit the shell", "exit"]
	]: basic.append(make_question(item[0], item[1], "Type the command only."))
	var flags: Array[Dictionary] = []
	for item in [
		["List all files with details", "ls -la"], ["Create nested directories logs/app", "mkdir -p logs/app"], ["Copy a directory recursively", "cp -r source backup"], ["Ask before overwriting with mv", "mv -i old new"], ["Number lines while printing notes.txt", "cat -n notes.txt"],
		["Print without a trailing newline", "echo -n hello"], ["Show five lines from app.log", "head -n 5 app.log"], ["Follow app.log", "tail -f app.log"], ["Find .gd files below this directory", "find . -name \"*.gd\""], ["Ignore case when searching TODO in README.md", "grep -i TODO README.md"],
		["Search TODO recursively in src", "grep -R TODO src"], ["Show line numbers when searching error", "grep -n error app.log"], ["Show disk usage in readable units", "du -sh build"], ["Show filesystem space in readable units", "df -h"], ["Count lines in access.log", "wc -l access.log"],
		["Sort names and remove duplicates", "sort -u names.txt"], ["Make deploy.sh executable for everyone", "chmod 755 deploy.sh"], ["Show process details for all users", "ps aux"], ["Request URL headers only", "curl -I https://example.com"], ["Create a gzip archive", "tar -czf backup.tar.gz project"],
		["Extract a gzip archive", "tar -xzf backup.tar.gz"], ["Print the first passwd field", "cut -d: -f1 /etc/passwd"], ["Use colon as awk's field separator", "awk -F: '{print $1}' /etc/passwd"], ["Print lines 1 through 5 with sed", "sed -n '1,5p' README.md"], ["Run echo once per name", "xargs -n 1 echo < names.txt"],
		["Connect to port 2222 over SSH", "ssh -p 2222 host"], ["Copy a directory with scp", "scp -r site host:/srv"], ["Send four ping packets", "ping -c 4 example.com"], ["Show git's short status", "git status --short"], ["Show the last five commits compactly", "git log --oneline -5"],
		["Create a new git branch", "git branch feature"], ["Switch to the main branch", "git switch main"], ["Stage all changed files", "git add ."], ["Create a git commit", "git commit -m \"message\""], ["Show changed lines", "git diff"],
		["Append output to build.log", "make >> build.log"], ["Send stderr to stdout", "command 2>&1"], ["Pipe a list into sort", "ls | sort"], ["Save and print output", "command | tee output.txt"], ["Print the current shell", "echo $SHELL"],
		["Show a directory tree one level deep", "find . -maxdepth 1"], ["Find directories only", "find . -type d"], ["Find regular files only", "find . -type f"], ["Show file permissions", "ls -l file.txt"], ["Set an environment value for one command", "DEBUG=1 command"],
		["Print the last 20 lines", "tail -n 20 app.log"], ["Sort by the second field", "sort -k 2 data.txt"], ["Count repeated lines", "uniq -c names.txt"], ["Append to a file with tee", "command | tee -a output.txt"], ["Show a service's journal", "journalctl -u ssh"]
	]: flags.append(make_question(item[0], item[1], "Match spaces, punctuation, and quotes exactly."))
	var ops: Array[Dictionary] = []
	for item in [
		["Show listening TCP and UDP sockets", "ss -tulpn"], ["Show all IP interfaces", "ip addr show"], ["Show the default route", "ip route show"], ["Show journal entries since today", "journalctl --since today"], ["Follow a service journal", "journalctl -u ssh -f"],
		["Restart the SSH service", "systemctl restart ssh"], ["Check a service status", "systemctl status ssh"], ["Enable a service at boot", "systemctl enable ssh"], ["Show memory usage", "free -h"], ["Show CPU and memory processes", "top"],
		["Show a process tree", "pstree"], ["Find the PID of nginx", "pgrep nginx"], ["Stop a process by name", "pkill nginx"], ["Show open files for a process", "lsof -p 1234"], ["Watch a command every second", "watch -n 1 date"],
		["Show block devices", "lsblk"], ["Show mounted filesystems", "mount"], ["Show UUIDs for block devices", "blkid"], ["Check a filesystem", "fsck /dev/sda1"], ["Show kernel messages", "dmesg"],
		["Show the hostname", "hostname"], ["Set the hostname", "hostnamectl set-hostname kiosk"], ["Show OS release data", "cat /etc/os-release"], ["Show kernel version", "uname -r"], ["Show uptime", "uptime"],
		["Show the current user's ID", "id"], ["Run a command as root", "sudo command"], ["Edit sudo rules safely", "visudo"], ["Add a user", "useradd kiosk"], ["Change a password", "passwd kiosk"],
		["Show network interfaces", "ip link show"], ["Test DNS lookup", "dig example.com"], ["Trace a route", "traceroute example.com"], ["Download a file with curl", "curl -O https://example.com/file"], ["Transfer a file with rsync", "rsync -av source/ backup/"],
		["Clone a git repository", "git clone https://example.com/repo.git"], ["Fetch remote changes", "git fetch origin"], ["Merge the main branch", "git merge main"], ["Show remote URLs", "git remote -v"], ["Push the current branch", "git push origin main"],
		["Show a commit's patch", "git show HEAD"], ["Restore one file", "git restore file.txt"], ["Stash current changes", "git stash"], ["Apply the latest stash", "git stash pop"], ["Show tags", "git tag"],
		["Find large log files", "find /var/log -type f -size +10M"], ["Delete temporary files", "find . -name \"*.tmp\" -delete"], ["Change every .sh file executable", "find . -name \"*.sh\" -exec chmod +x {} \\;"], ["Show five newest files", "ls -lt | head -n 5"], ["Archive logs with today's date", "tar -czf logs.tar.gz /var/log"]
	]: ops.append(make_question(item[0], item[1], "Type the full terminal command exactly."))
	return [basic, flags, ops]

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	terminal = Panel.new()
	terminal.position = Vector2(104, 72)
	terminal.size = Vector2(944, 510)
	terminal.add_theme_stylebox_override("panel", style(Color("06110b"), Color("46d9ff"), 2))
	layer.add_child(terminal)
	terminal.add_child(label("KERNEL KIOSK // TYPING TERMINAL", Vector2(28, 24), Vector2(560, 28), 22, Color("8ae9ff")))
	hud_label = label("", Vector2(590, 28), Vector2(324, 22), 14, Color("f4ffb2"), HORIZONTAL_ALIGNMENT_RIGHT)
	terminal.add_child(hud_label)
	terminal.add_child(label("root@kiosk:~$ training --interactive", Vector2(28, 80), Vector2(880, 22), 14, Color("76ffad")))
	prompt_label = label("", Vector2(28, 128), Vector2(888, 98), 22, Color("d8ffe5"))
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	terminal.add_child(prompt_label)
	hint_label = label("", Vector2(28, 240), Vector2(888, 22), 13, Color("9acbad"))
	terminal.add_child(hint_label)
	terminal.add_child(label("root@kiosk:~$", Vector2(28, 302), Vector2(165, 34), 17, Color("76ffad")))
	input = LineEdit.new()
	input.position = Vector2(196, 290)
	input.size = Vector2(688, 52)
	input.placeholder_text = "type answer and press Enter"
	input.add_theme_font_size_override("font_size", 18)
	input.add_theme_color_override("font_color", Color("e1ffea"))
	input.add_theme_stylebox_override("normal", style(Color("091a12"), Color("2e9e66"), 1))
	input.text_submitted.connect(func(_value): submit_answer())
	terminal.add_child(input)
	submit = Button.new()
	submit.text = "RUN"
	submit.position = Vector2(740, 370)
	submit.size = Vector2(144, 46)
	submit.add_theme_font_size_override("font_size", 14)
	submit.add_theme_stylebox_override("normal", style(Color("103d29"), Color("46ff9a"), 1))
	submit.pressed.connect(submit_answer)
	terminal.add_child(submit)
	var rankings := Button.new()
	rankings.text = "RANKINGS"
	rankings.position = Vector2(578, 370)
	rankings.size = Vector2(144, 46)
	rankings.pressed.connect(open_rankings)
	rankings.add_theme_stylebox_override("normal", style(Color("071521"), Color("46d9ff"), 1))
	terminal.add_child(rankings)
	status_label = label("", Vector2(28, 440), Vector2(888, 28), 14, Color("b9ffd2"))
	terminal.add_child(status_label)

func load_question() -> void:
	active = decks[level][question]
	prompt_label.text = "TASK %02d: %s" % [question + 1, active.prompt]
	hint_label.text = active.hint
	status_label.text = "Terminal ready. Exact answers are required."
	input.text = ""
	input.grab_focus()
	update_hud()

func submit_answer() -> void:
	if awaiting_advance:
		return
	var given := input.text.strip_edges()
	if given.is_empty(): return
	if given == active.answer:
		score += LEVEL_POINTS[level]
		health = mini(MAX_HEALTH, health + 2)
		streak += 1
		status_label.text = "COMMAND ACCEPTED  +%d SCORE  // streak %d" % [LEVEL_POINTS[level], streak]
		begin_feedback(Color("1cae60"))
	else:
		score -= 2
		health -= 5
		streak = 0
		status_label.text = "COMMAND REJECTED  Expected: %s  // -2 SCORE -5 HEALTH" % active.answer
		begin_feedback(Color("d92f45"))
	update_hud()

func begin_feedback(color: Color) -> void:
	feedback_color = color
	feedback_time = 0.7
	awaiting_advance = true
	input.editable = false
	submit.disabled = true
	terminal.add_theme_stylebox_override("panel", style(Color("06110b").lerp(color.darkened(0.75), 0.52), color, 2))
	queue_redraw()

func _process(delta: float) -> void:
	if feedback_time <= 0.0:
		return
	feedback_time = maxf(0.0, feedback_time - delta)
	queue_redraw()
	if feedback_time == 0.0:
		advance_after_feedback()

func advance_after_feedback() -> void:
	terminal.add_theme_stylebox_override("panel", style(Color("06110b"), Color("46d9ff"), 2))
	if health <= 0:
		end_game(false)
		return
	question += 1
	if question >= QUESTIONS_PER_LEVEL:
		level += 1
		question = 0
		if level >= decks.size():
			end_game(true)
			return
		decks[level].shuffle()
	awaiting_advance = false
	input.editable = true
	submit.disabled = false
	load_question()

func update_hud() -> void:
	hud_label.text = "SCORE %03d  // HEALTH %02d  // LEVEL %d  %02d/%02d" % [score, health, level + 1, question + 1, QUESTIONS_PER_LEVEL]

func end_game(won: bool) -> void:
	Session.final_score = score
	Session.completed_game_id = Session.game_id
	Session.completed_game_title = Session.game_title
	Session.completed_replay_scene = Session.replay_scene
	get_tree().change_scene_to_file("res://WinScene.tscn" if won else "res://DeathScene.tscn")

func open_rankings() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.get_interface("window").location.assign("/rankings.html?game=typing")
	else:
		OS.shell_open("http://127.0.0.1:8009/rankings.html?game=typing")

func label(value: String, pos: Vector2, label_size: Vector2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var node := Label.new()
	node.text = value
	node.position = pos
	node.size = label_size
	node.horizontal_alignment = align
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
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
	var flash_strength := feedback_time / 0.7
	draw_rect(Rect2(Vector2.ZERO, Vector2(1152, 648)), Color("030805").lerp(feedback_color.darkened(0.82), flash_strength))
	for y in range(24, 648, 34): draw_line(Vector2(0, y), Vector2(1152, y), Color(0.04, 0.25, 0.15, 0.24), 1)
