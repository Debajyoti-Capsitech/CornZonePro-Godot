extends CanvasLayer

@onready var feedback_label: Label = get_node_or_null("Control/FeedbackLabel")
@onready var code_input: LineEdit = get_node_or_null("Control/VBoxContainer/JoinRoomCard/MarginContainer/HBoxContainer/CodeInput")
@onready var online_players_label: Label = get_node_or_null("Control/OnlineBadge/Label")

var pending_join_room_id: String = ""
var search_active: bool = false

var _online_players_count: int = 12458
var _fluctuation_timer: Timer = null

func _ready() -> void:
	# Connect NetworkManager signals
	if not NetworkManager.server_found.is_connected(_on_server_found):
		NetworkManager.server_found.connect(_on_server_found)
	if not NetworkManager.connection_failed.is_connected(_on_connection_failed):
		NetworkManager.connection_failed.connect(_on_connection_failed)
	if not NetworkManager.room_join_failed.is_connected(_on_room_join_failed):
		NetworkManager.room_join_failed.connect(_on_room_join_failed)
	if not NetworkManager.player_connected.is_connected(_on_player_connected):
		NetworkManager.player_connected.connect(_on_player_connected)
	if not NetworkManager.game_ready.is_connected(_on_game_ready):
		NetworkManager.game_ready.connect(_on_game_ready)

	# Connect buttons
	var back_btn = get_node_or_null("Control/BackButton")
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
		
	var find_match_btn = get_node_or_null("Control/VBoxContainer/QuickMatchCard/MarginContainer/HBoxContainer/RightSection/FindMatchButton")
	if find_match_btn:
		find_match_btn.pressed.connect(_on_find_match_pressed)
		
	var create_room_btn = get_node_or_null("Control/VBoxContainer/CreateRoomCard/MarginContainer/HBoxContainer/RightSection/CreateRoomButton")
	if create_room_btn:
		create_room_btn.pressed.connect(_on_create_room_pressed)
		
	var join_btn = get_node_or_null("Control/VBoxContainer/JoinRoomCard/MarginContainer/HBoxContainer/JoinButton")
	if join_btn:
		join_btn.pressed.connect(_on_join_pressed)

	if feedback_label:
		feedback_label.text = ""

	# Setup dynamic/live online players count fluctuation
	_online_players_count = randi_range(11500, 13800)
	_update_online_players_label()
	
	_fluctuation_timer = Timer.new()
	_fluctuation_timer.wait_time = randf_range(3.0, 5.0)
	_fluctuation_timer.autostart = true
	_fluctuation_timer.timeout.connect(_on_fluctuation_timeout)
	add_child(_fluctuation_timer)


func _on_back_pressed() -> void:
	SoundManager.play_button_clicks()
	_cancel_search()
	NetworkManager.disconnect_game()
	if feedback_label:
		feedback_label.text = ""
	if code_input:
		code_input.text = ""
	if get_parent().has_method("show_mode_selection_ui"):
		get_parent().show_mode_selection_ui()

func _on_create_room_pressed() -> void:
	SoundManager.play_button_clicks()
	_cancel_search()
	
	var random_code = str(randi_range(1000, 9999))
	if code_input and code_input.text.strip_edges() != "":
		random_code = code_input.text.strip_edges().to_upper()
		
	_show_feedback("Creating room... Room Code: " + random_code)
	
	GameSession.selected_mode = "Multiplayer"
	NetworkManager.hosted_room_name = random_code
	NetworkManager.hosted_room_id = random_code
	await NetworkManager.host_game()
	
	_show_feedback("Room Hosted! Code: " + NetworkManager.hosted_room_id + ". Waiting for players...")
	if get_parent().has_method("show_waiting_screen"):
		get_parent().show_waiting_screen(NetworkManager.hosted_room_id)

func _on_join_pressed() -> void:
	SoundManager.play_button_clicks()
	var code = code_input.text.strip_edges().to_upper() if code_input else ""
	if code == "":
		_show_feedback("Please enter a room code first!")
		return

	_cancel_search()
	_show_feedback("Joining Room: " + code + "...")
	
	pending_join_room_id = code
	
	GameSession.selected_mode = "Multiplayer"
	await NetworkManager.join_game(code)
	if get_parent().has_method("show_waiting_screen"):
		get_parent().show_waiting_screen(code)
	_start_search_timeout()

func _on_find_match_pressed() -> void:
	SoundManager.play_button_clicks()
	_cancel_search()
	_show_feedback("Searching for available rooms...")
	NetworkManager.start_search()
	_start_search_timeout()

# Network callbacks
func _on_server_found(server: Dictionary) -> void:
	if not search_active:
		return
	
	_cancel_search()
	NetworkManager.stop_search()
	
	var code = server.get("room_id", "")
	if code == "":
		return
		
	_show_feedback("Found match! Joining Room: " + code + "...")
	pending_join_room_id = code
	
	GameSession.selected_mode = "Multiplayer"
	NetworkManager.join_game(code)
	if get_parent().has_method("show_waiting_screen"):
		get_parent().show_waiting_screen(code)

func _on_player_connected(id: int) -> void:
	_show_feedback("Opponent connected! ID: " + str(id))

func _on_game_ready() -> void:
	_show_feedback("Match starting...")

func _on_room_join_failed(message: String) -> void:
	_cancel_search()
	_show_feedback("Join failed: " + message)

func _on_connection_failed() -> void:
	_cancel_search()
	_show_feedback("Connection failed.")

# Search helpers
func _start_search_timeout() -> void:
	search_active = true
	await get_tree().create_timer(10.0).timeout
	if search_active:
		search_active = false
		_show_feedback("No room found or connection failed.")
		NetworkManager.stop_search()

func _cancel_search() -> void:
	search_active = false
	pending_join_room_id = ""

func _show_feedback(msg: String) -> void:
	if feedback_label:
		feedback_label.text = msg
		feedback_label.modulate.a = 1.0

func _on_fluctuation_timeout() -> void:
	var change := randi_range(-8, 8)
	_online_players_count = clamp(_online_players_count + change, 8000, 20000)
	_update_online_players_label()
	if _fluctuation_timer:
		_fluctuation_timer.wait_time = randf_range(3.0, 6.0)

func _update_online_players_label() -> void:
	if online_players_label:
		online_players_label.text = "● ONLINE PLAYERS: " + _format_number(_online_players_count)

func _format_number(number: int) -> String:
	var s = str(number)
	var result = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		result = s[i] + result
		count += 1
		if count == 3 and i > 0:
			result = "," + result
			count = 0
	return result
