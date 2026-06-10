extends CanvasLayer

@onready var room_code_label: Label = get_node_or_null("Control/RoomCodeLabel")
@onready var p1_name_label: Label = get_node_or_null("Control/LobbyHBox/P1Card/Margin/VBox/NameLabel")
@onready var p1_matches_val: Label = get_node_or_null("Control/LobbyHBox/P1Card/Margin/VBox/Stats/MatchesRow/Val")
@onready var p1_pots_val: Label = get_node_or_null("Control/LobbyHBox/P1Card/Margin/VBox/Stats/PotsRow/Val")
@onready var p1_avatar: TextureRect = get_node_or_null("Control/LobbyHBox/P1Card/Margin/VBox/Avatar")
@onready var p1_stats_container: VBoxContainer = get_node_or_null("Control/LobbyHBox/P1Card/Margin/VBox/Stats")

@onready var p2_name_label: Label = get_node_or_null("Control/LobbyHBox/P2Card/Margin/VBox/NameLabel")
@onready var p2_status_label: Label = get_node_or_null("Control/LobbyHBox/P2Card/Margin/VBox/StatusLabel")
@onready var p2_dots_label: Label = get_node_or_null("Control/LobbyHBox/P2Card/Margin/VBox/DotsLabel")
@onready var p2_avatar: TextureRect = get_node_or_null("Control/LobbyHBox/P2Card/Margin/VBox/Avatar")
@onready var p2_matches_val: Label = get_node_or_null("Control/LobbyHBox/P2Card/Margin/VBox/Stats/MatchesRow/Val")
@onready var p2_pots_val: Label = get_node_or_null("Control/LobbyHBox/P2Card/Margin/VBox/Stats/PotsRow/Val")
@onready var p2_stats_container: VBoxContainer = get_node_or_null("Control/LobbyHBox/P2Card/Margin/VBox/Stats")

@onready var players_count_label: Label = get_node_or_null("Control/InfoBadge/Margin/HBox/Players/Count")

var current_room_code: String = ""
var countdown_timer: Timer
var countdown_value: int = 3

func _ready() -> void:
	# Connect leave button
	var leave_btn = get_node_or_null("Control/LeaveButton")
	if leave_btn:
		leave_btn.pressed.connect(_on_leave_pressed)
		
	# Connect copy room code button
	var copy_btn = get_node_or_null("Control/CopyCodeButton")
	if copy_btn:
		copy_btn.pressed.connect(_on_copy_code_pressed)

	# Connect NetworkManager signals
	if not NetworkManager.player_connected.is_connected(_on_player_connected):
		NetworkManager.player_connected.connect(_on_player_connected)
	if not NetworkManager.player_disconnected.is_connected(_on_player_disconnected):
		NetworkManager.player_disconnected.connect(_on_player_disconnected)
	if not NetworkManager.server_disconnected.is_connected(_on_server_disconnected):
		NetworkManager.server_disconnected.connect(_on_server_disconnected)



func setup_lobby(code: String) -> void:
	current_room_code = code
	if room_code_label:
		room_code_label.text = "Room Code: " + code

	_reset_cards()
	
	if NetworkManager.is_host:
		_set_p1_as_local()
		_set_p2_waiting()
		_create_start_button()
	else:
		_set_p1_waiting()
		_set_p2_as_local()

	if players_count_label:
		players_count_label.text = "1 / 2"

	var opponent_id = 2 if NetworkManager.is_host else 1
	if NetworkManager.players.has(opponent_id):
		_on_player_connected(opponent_id)

func _create_start_button() -> void:
	if not NetworkManager.is_host: return
	var start_btn = get_node_or_null("Control/StartGameButton")
	if not start_btn:
		start_btn = Button.new()
		start_btn.name = "StartGameButton"
		start_btn.text = "WAITING..."
		start_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var font_size = 36
		start_btn.add_theme_font_size_override("font_size", font_size)
		start_btn.custom_minimum_size = Vector2(250, 80)
		start_btn.visible = false # Hidden until player joins
		var container = get_node_or_null("Control")
		if container:
			container.add_child(start_btn)
			start_btn.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			start_btn.offset_bottom = -150
			start_btn.offset_top = -230
			
	if not countdown_timer:
		countdown_timer = Timer.new()
		countdown_timer.name = "CountdownTimer"
		countdown_timer.one_shot = false
		add_child(countdown_timer)
		countdown_timer.timeout.connect(_on_countdown_tick)

func _start_countdown() -> void:
	if not NetworkManager.is_host: return
	if countdown_timer and not countdown_timer.is_stopped():
		return # Already counting down
		
	var start_btn = get_node_or_null("Control/StartGameButton")
	if start_btn:
		start_btn.visible = true
		countdown_value = 3
		start_btn.text = "STARTING IN " + str(countdown_value) + "..."
		if countdown_timer:
			countdown_timer.start(1.0)

func _on_countdown_tick() -> void:
	countdown_value -= 1
	var start_btn = get_node_or_null("Control/StartGameButton")
	if countdown_value > 0:
		if start_btn:
			start_btn.text = "STARTING IN " + str(countdown_value) + "..."
	else:
		if start_btn:
			start_btn.text = "STARTING MATCH!"
		if countdown_timer:
			countdown_timer.stop()
		NetworkManager.host_start_game_manually()

func _reset_cards() -> void:
	_set_p1_waiting()
	_set_p2_waiting()

func _set_p1_as_local() -> void:
	if p1_name_label: p1_name_label.text = PlayerData.player_name if PlayerData.player_name != "" else "YOU"
	if p1_matches_val: p1_matches_val.text = str(PlayerData.matches_played)
	if p1_pots_val: p1_pots_val.text = str(PlayerData.total_pots)
	if p1_avatar:
		var idx = Prefs.get_int("profile_index", 0)
		p1_avatar.texture = load("res://Texture Or Sprites/Profile Screen/FemaleIcon.png") if idx == 1 else load("res://Texture Or Sprites/Profile Screen/MaleIcon.png")
		p1_avatar.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	if p1_stats_container: p1_stats_container.visible = true

func _set_p2_as_local() -> void:
	if p2_name_label: p2_name_label.text = PlayerData.player_name if PlayerData.player_name != "" else "YOU"
	if p2_status_label: p2_status_label.text = "READY"
	if p2_dots_label: p2_dots_label.visible = false
	if p2_avatar:
		var idx = Prefs.get_int("profile_index", 0)
		p2_avatar.texture = load("res://Texture Or Sprites/Profile Screen/FemaleIcon.png") if idx == 1 else load("res://Texture Or Sprites/Profile Screen/MaleIcon.png")
		p2_avatar.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
		p2_avatar.visible = true
	if p2_matches_val: p2_matches_val.text = str(PlayerData.matches_played)
	if p2_pots_val: p2_pots_val.text = str(PlayerData.total_pots)
	if p2_stats_container: p2_stats_container.visible = true

func _set_p1_waiting() -> void:
	if p1_name_label: p1_name_label.text = "HOST"
	if p1_matches_val: p1_matches_val.text = "0"
	if p1_pots_val: p1_pots_val.text = "0"
	if p1_avatar:
		p1_avatar.texture = load("res://Texture Or Sprites/Profile Screen/MaleIcon.png")
		p1_avatar.self_modulate = Color(0.04, 0.04, 0.08, 0.65)
	if p1_stats_container: p1_stats_container.visible = false

func _set_p2_waiting() -> void:
	if p2_name_label: p2_name_label.text = "PLAYER 2"
	if p2_status_label: p2_status_label.text = "WAITING..."
	if p2_dots_label:
		p2_dots_label.text = "● ● ●"
		p2_dots_label.visible = true
	if p2_avatar:
		p2_avatar.texture = load("res://Texture Or Sprites/Profile Screen/MaleIcon.png")
		p2_avatar.self_modulate = Color(0.04, 0.04, 0.08, 0.65)
		p2_avatar.visible = true
	if p2_stats_container: p2_stats_container.visible = false

func _on_player_connected(id: int) -> void:
	if id == NetworkManager.my_id: return
	
	var opp_name = "OPPONENT"
	var profile_index = 0
	var opp_matches = 0
	var opp_pots = 0
	if NetworkManager.players.has(id):
		var opp_data = NetworkManager.players[id]
		if typeof(opp_data) == TYPE_DICTIONARY:
			opp_name = opp_data.get("name", "OPPONENT")
			if opp_data.has("profile_index"):
				profile_index = opp_data["profile_index"]
			opp_matches = opp_data.get("matches_played", 0)
			opp_pots = opp_data.get("total_pots", 0)

	if NetworkManager.is_host:
		if p2_name_label: p2_name_label.text = opp_name
		if p2_status_label: p2_status_label.text = "CONNECTED!"
		if p2_dots_label: p2_dots_label.visible = false
		if p2_avatar:
			p2_avatar.texture = load("res://Texture Or Sprites/Profile Screen/FemaleIcon.png") if profile_index == 1 else load("res://Texture Or Sprites/Profile Screen/MaleIcon.png")
			p2_avatar.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
			p2_avatar.visible = true
		if p2_matches_val: p2_matches_val.text = str(int(opp_matches))
		if p2_pots_val: p2_pots_val.text = str(int(opp_pots))
		if p2_stats_container: p2_stats_container.visible = true
		
		# Start Countdown if WebRTC is connected
		if NetworkManager.multiplayer.get_peers().size() > 0:
			_start_countdown()
		else:
			var start_btn = get_node_or_null("Control/StartGameButton")
			if start_btn:
				start_btn.visible = true
				start_btn.text = "CONNECTING..."
	else:
		if p1_name_label: p1_name_label.text = opp_name
		if p1_avatar:
			p1_avatar.texture = load("res://Texture Or Sprites/Profile Screen/FemaleIcon.png") if profile_index == 1 else load("res://Texture Or Sprites/Profile Screen/MaleIcon.png")
			p1_avatar.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
		if p1_matches_val: p1_matches_val.text = str(int(opp_matches))
		if p1_pots_val: p1_pots_val.text = str(int(opp_pots))
		if p1_stats_container: p1_stats_container.visible = true

	if players_count_label:
		players_count_label.text = "2 / 2"

func _on_player_disconnected(id: int) -> void:
	if NetworkManager.is_host:
		_set_p2_waiting()
		var start_btn = get_node_or_null("Control/StartGameButton")
		if start_btn: start_btn.visible = false
		if countdown_timer:
			countdown_timer.stop()
	else:
		_set_p1_waiting()
		
	if players_count_label:
		players_count_label.text = "1 / 2"

func _on_server_disconnected() -> void:
	_on_leave_pressed()

func _on_leave_pressed() -> void:
	SoundManager.play_button_clicks()
	NetworkManager.disconnect_game()
	if get_parent().has_method("hide_waiting_screen"):
		get_parent().hide_waiting_screen()

func _on_copy_code_pressed() -> void:
	SoundManager.play_button_clicks()
	if current_room_code != "":
		DisplayServer.clipboard_set(current_room_code)
		# Update room code label briefly to show feedback
		if room_code_label:
			room_code_label.text = "CODE COPIED!"
			await get_tree().create_timer(1.0).timeout
			room_code_label.text = "Room Code: " + current_room_code
