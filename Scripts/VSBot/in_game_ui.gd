extends CanvasLayer

const BOT_NAMES = [
	"STORM", "BLAZE", "NOVA", "CYBER", "ROGUE", "VEGA", "AXEL", "HUNTER",
	"MAVERICK", "ZEPHYR", "PHOENIX", "GLITCH", "SHADOW", "LUNA", "STRIKE", "DRIFT",
	"ROCKET", "PIXEL", "VIPER", "FROST", "BOLT", "BEAT", "RIPTIDE", "SCOUT",
	"DIESEL", "EMBER", "NIGHTFALL", "SOLAR", "ASTRO", "HAZE", "TITAN", "ECHO",
	"JOKER", "BANDIT", "PANDA", "KAIJU", "CRIMSON", "ONYX", "SAKURA", "YETI"
]

@onready var p1_total_score: Label = get_node_or_null("ScoreBoard/User Total Score")
@onready var p2_total_score: Label = get_node_or_null("ScoreBoard/Bot Total Score")

@onready var p1_turn_ui: TextureRect = $Player1TurnUI
@onready var p2_turn_ui: TextureRect = $Player2TurnUI

# VS Intro Panel references
@onready var vs_intro_panel: Control = $VS_IntroPanel
@onready var vs_countdown_label: Label = $VS_IntroPanel/BottomSection/CountdownLabel
@onready var vs_progress_bar: TextureProgressBar = $VS_IntroPanel/BottomSection/ProgressBar

@onready var p1_dots: Array[TextureRect] = [
	$"User  1 Scores/p1",
	$"User  1 Scores/p2",
	$"User  1 Scores/p3",
	$"User  1 Scores/p4"
]

@onready var p2_dots: Array[TextureRect] = [
	$"Bot 2 Scores/p1",
	$"Bot 2 Scores/p2",
	$"Bot 2 Scores/p3",
	$"Bot 2 Scores/p4"
]

func _ready() -> void:
	# Connect game signals
	GameSession.pots_update.connect(_update_scores)
	GameSession.turn_changed.connect(_on_turn_changed)
	GameSession.bag_result_changed.connect(_on_bag_result_changed)
	
	_clear_dots()
	
	# Initial score sync
	_update_scores()
	
	if GameSession.selected_mode == "Multiplayer":
		_setup_multiplayer_opponent()
	else:
		# Select random bot details and slice avatar
		_select_random_bot()

	# Update Player name on the VS Card
	var user_name_card := vs_intro_panel.get_node("YouCard/NameLabel") as Label
	if user_name_card and PlayerData.player_name != "":
		user_name_card.text = PlayerData.player_name

	# Update User stats from PlayerData (Matches Played and Total Pots)
	var user_stars := vs_intro_panel.get_node("YouCard/StarsRow/Val") as Label
	if user_stars:
		user_stars.text = " " + str(PlayerData.matches_played)
		
	var user_trophies := vs_intro_panel.get_node("YouCard/TrophiesRow/Val") as Label
	if user_trophies:
		user_trophies.text = " " + str(PlayerData.total_pots)

	# Update User avatar from Prefs
	var avatar_rect := vs_intro_panel.get_node("YouCard/Avatar") as TextureRect
	if avatar_rect:
		var profile_index := Prefs.get_int("profile_index", 0)
		if profile_index == 1:
			avatar_rect.texture = load("res://Texture Or Sprites/Profile Screen/FemaleIcon.png")
		else:
			avatar_rect.texture = load("res://Texture Or Sprites/Profile Screen/MaleIcon.png")

	# Hide VS intro panel initially
	vs_intro_panel.visible = false

func start_vs_bot_match() -> void:
	if GameSession.selected_mode == "Multiplayer":
		vs_intro_panel.visible = false
		if has_node("ScoreBoard"):
			$ScoreBoard.visible = true
		if has_node("User  1 Scores"):
			$"User  1 Scores".visible = true
		if has_node("Bot 2 Scores"):
			$"Bot 2 Scores".visible = true
		if has_node("Pause Button"):
			$"Pause Button".visible = true
		_on_turn_changed(GameSession.current_turn)
	else:
		vs_intro_panel.visible = true
		vs_intro_panel.modulate.a = 1.0
		_run_vs_countdown()
	
	# Start the spawn timer to spawn the first bag
	var current_scene = get_tree().current_scene
	if current_scene:
		var start_timer = current_scene.get_node_or_null("StartTimer")
		if start_timer:
			start_timer.start()

func _select_random_bot() -> void:
	randomize()
	var bot_index := randi() % 40
	var bot_name: String = BOT_NAMES[bot_index]
	
	# Save the bot name globally in the match session
	GameSession.bot_name = bot_name
	
	# Randomize difficulty label prefix
	var diffs = ["EASY BOT", "HARD BOT", "PRO BOT"]
	var right_header_label := vs_intro_panel.get_node("BotCard/HeaderLabel") as Label
	if right_header_label:
		var difficulty_str = diffs[randi() % diffs.size()]
		right_header_label.text = difficulty_str
		GameSession.bot_difficulty = difficulty_str

	# Update Bot name in matchmaking card
	var bot_name_card := vs_intro_panel.get_node("BotCard/NameLabel") as Label
	if bot_name_card:
		bot_name_card.text = bot_name
		
	# Update Bot Heading on in-game HUD ScoreBoard
	var bot_scoreboard_label := $"Bot 2 Scores/Player 2 Heading" as Label
	if bot_scoreboard_label:
		bot_scoreboard_label.text = bot_name
		
	# Set Bot's turn UI indicator text to match the specific bot name
	if p2_turn_ui and p2_turn_ui.has_node("Text"):
		p2_turn_ui.get_node("Text").text = bot_name + "'s Turn"

	# Randomize Bot stats
	var bot_lvl := vs_intro_panel.get_node("BotCard/LevelBadge") as Label
	if bot_lvl:
		bot_lvl.text = str(randi_range(5, 15))
		
	var bot_stars := vs_intro_panel.get_node("BotCard/StarsRow/Val") as Label
	if bot_stars:
		bot_stars.text = " " + str(randi_range(30, 120)) # Bot's matches played
		
	var bot_trophies := vs_intro_panel.get_node("BotCard/TrophiesRow/Val") as Label
	if bot_trophies:
		bot_trophies.text = " " + str(randi_range(80, 400)) # Bot's total pots

	# Load the bot avatars sheet and crop the specific cell
	var sheet_texture = load("res://Texture Or Sprites/VS_Intro/bot_avatars_sheet.jpg")
	if sheet_texture:
		var col := bot_index % 8
		var row := bot_index / 8
		
		# Cell coordinates calculated from resolution scans:
		var col_step := 122.625
		var row_step := 123.2
		var x_pos := 18.0 + col * col_step + 6.0
		var y_pos := 51.0 + row * row_step + 6.0
		
		var atlas_tex := AtlasTexture.new()
		atlas_tex.atlas = sheet_texture
		atlas_tex.region = Rect2(x_pos, y_pos, 104.0, 92.0)
		
		var bot_avatar_rect := vs_intro_panel.get_node("BotCard/Avatar") as TextureRect
		if bot_avatar_rect:
			bot_avatar_rect.texture = atlas_tex

func _setup_multiplayer_opponent() -> void:
	# Get Player names
	var p1_name = "Player 1"
	var p2_name = "Player 2"
	var p2_profile_index = 0
	
	if NetworkManager.players.has(1):
		var p1_data = NetworkManager.players[1]
		if typeof(p1_data) == TYPE_DICTIONARY and p1_data.has("name"):
			p1_name = p1_data["name"]
	if NetworkManager.players.has(2):
		var p2_data = NetworkManager.players[2]
		if typeof(p2_data) == TYPE_DICTIONARY:
			if p2_data.has("name"):
				p2_name = p2_data["name"]
			if p2_data.has("profile_index"):
				p2_profile_index = p2_data["profile_index"]

	# Update Opponent name in matchmaking card (which is BotCard for the local player)
	var opponent_name = p2_name if NetworkManager.is_host else p1_name
	var opponent_profile_index = p2_profile_index if NetworkManager.is_host else (NetworkManager.players[1].get("profile_index", 0) if NetworkManager.players.has(1) else 0)
	
	var bot_name_card := vs_intro_panel.get_node("BotCard/NameLabel") as Label
	if bot_name_card:
		bot_name_card.text = opponent_name
		
	# Update Headings on in-game HUD ScoreBoard
	var p1_heading := get_node_or_null("User  1 Scores/Player 1 Heading") as Label
	if p1_heading:
		p1_heading.text = p1_name
		
	var p2_heading := get_node_or_null("Bot 2 Scores/Player 2 Heading") as Label
	if p2_heading:
		p2_heading.text = p2_name
		
	# Set turn UI indicator text based on local player ID
	var my_id = 1 if NetworkManager.is_host else 2
	
	if p1_turn_ui and p1_turn_ui.has_node("Text"):
		var p1_turn_text = p1_turn_ui.get_node("Text") as Label
		if my_id == 1:
			p1_turn_text.text = "Your Turn"
		else:
			p1_turn_text.text = p1_name + "'s Turn"
			
	if p2_turn_ui and p2_turn_ui.has_node("Text"):
		var p2_turn_text = p2_turn_ui.get_node("Text") as Label
		if my_id == 2:
			p2_turn_text.text = "Your Turn"
		else:
			p2_turn_text.text = p2_name + "'s Turn"

	# Hide bot-specific difficulty
	var right_header_label := vs_intro_panel.get_node("BotCard/HeaderLabel") as Label
	if right_header_label:
		right_header_label.text = "ONLINE MATCH"

	# Hide stats for now since we don't sync them yet
	var bot_lvl := vs_intro_panel.get_node("BotCard/LevelBadge") as Label
	if bot_lvl:
		bot_lvl.text = ""
	var bot_stars := vs_intro_panel.get_node("BotCard/StarsRow/Val") as Label
	if bot_stars:
		bot_stars.text = " -"
	var bot_trophies := vs_intro_panel.get_node("BotCard/TrophiesRow/Val") as Label
	if bot_trophies:
		bot_trophies.text = " -"

	# Set default avatar for opponent
	var bot_avatar_rect := vs_intro_panel.get_node("BotCard/Avatar") as TextureRect
	if bot_avatar_rect:
		if opponent_profile_index == 1:
			bot_avatar_rect.texture = load("res://Texture Or Sprites/Profile Screen/FemaleIcon.png")
		else:
			bot_avatar_rect.texture = load("res://Texture Or Sprites/Profile Screen/MaleIcon.png")

func _update_scores() -> void:
	if is_instance_valid(p1_total_score):
		p1_total_score.text = str(GameSession.score_p1)
	if is_instance_valid(p2_total_score):
		p2_total_score.text = str(GameSession.score_p2)

func _on_turn_changed(player: int) -> void:
	if vs_intro_panel.visible:
		return
		
	if player == 1:
		p1_turn_ui.visible = true
		p2_turn_ui.visible = false
	else:
		p1_turn_ui.visible = false
		p2_turn_ui.visible = true

func _on_pause_button_pressed() -> void:
	SoundManager.play_button_clicks()
	GameSession.game_paused = true
	UIManager.toggle_canvas(UIManager.pause_screen)

func _on_vs_close_pressed() -> void:
	SoundManager.play_button_clicks()
	UIManager.home()

func _run_vs_countdown() -> void:
	# Hide gameplay HUD during intro sequence
	if has_node("ScoreBoard"):
		$ScoreBoard.visible = false
	if has_node("User  1 Scores"):
		$"User  1 Scores".visible = false
	if has_node("Bot 2 Scores"):
		$"Bot 2 Scores".visible = false
	$"Pause Button".visible = false
	p1_turn_ui.visible = false
	p2_turn_ui.visible = false
	
	# Animate the progress bar and update countdown label
	var tween = create_tween()
	vs_progress_bar.value = 100
	tween.tween_property(vs_progress_bar, "value", 0, 5.0)
	
	for i in range(5, 0, -1):
		vs_countdown_label.text = "Match starting in %d..." % i
		await get_tree().create_timer(1.0).timeout
	
	# Fade out matchmaking screen
	var fade_tween = create_tween()
	fade_tween.tween_property(vs_intro_panel, "modulate:a", 0.0, 0.4)
	await fade_tween.finished
	
	vs_intro_panel.visible = false
	
	# Restore gameplay HUD
	if has_node("ScoreBoard"):
		$ScoreBoard.visible = true
	if has_node("User  1 Scores"):
		$"User  1 Scores".visible = true
	if has_node("Bot 2 Scores"):
		$"Bot 2 Scores".visible = true
	$"Pause Button".visible = true
	_on_turn_changed(GameSession.current_turn)

func _clear_dots() -> void:
	for dot in p1_dots:
		if is_instance_valid(dot):
			dot.self_modulate = Color(1.0, 1.0, 1.0)
	for dot in p2_dots:
		if is_instance_valid(dot):
			dot.self_modulate = Color(1.0, 1.0, 1.0)

func _on_bag_result_changed(player: int, index: int, points: int) -> void:
	if index < 0 or index >= 4:
		return
	
	var target_dot: TextureRect = null
	if player == 1:
		target_dot = p1_dots[index]
	else:
		target_dot = p2_dots[index]
		
	if is_instance_valid(target_dot):
		if points == 3:
			target_dot.self_modulate = Color(0.2, 0.8, 0.2) # Green for in the hole
		else:
			target_dot.self_modulate = Color(0.8, 0.2, 0.2) # Red for board/miss
