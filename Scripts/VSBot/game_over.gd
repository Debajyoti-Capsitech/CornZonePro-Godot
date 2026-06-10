extends CanvasLayer

@onready var winner_text: Label = $"Control/GameOver BG/Player Winner Declaration"
@onready var winner_avatar: TextureRect = $"Control/GameOver BG/WinnerAvatar"

func _ready() -> void:
	GameSession.turns_exhausted.connect(_update_results)
	if not NetworkManager.rematch_requested.is_connected(_on_rematch_requested):
		NetworkManager.rematch_requested.connect(_on_rematch_requested)
	if not NetworkManager.rematch_declined.is_connected(_on_rematch_declined):
		NetworkManager.rematch_declined.connect(_on_rematch_declined)

func _update_results() -> void:
	SoundManager.play_game_over()
	UIManager.enable_canvas(self)
	AnimateManager.pop_animation($Control)
	
	var p1_score: int = GameSession.score_p1
	var p2_score: int = GameSession.score_p2

	var p1_name = "Player 1"
	var p2_name = "Player 2"
	if NetworkManager.players.has(1):
		var p1_data = NetworkManager.players[1]
		if typeof(p1_data) == TYPE_DICTIONARY and p1_data.has("name"):
			p1_name = p1_data["name"]
	if NetworkManager.players.has(2):
		var p2_data = NetworkManager.players[2]
		if typeof(p2_data) == TYPE_DICTIONARY and p2_data.has("name"):
			p2_name = p2_data["name"]

	var my_id := 1
	if GameSession.selected_mode == "Multiplayer":
		my_id = 1 if NetworkManager.is_host else 2
	else:
		my_id = 1 # In VSBot, local player is always Player 1

	if p1_score > p2_score:
		if my_id == 1:
			winner_text.text = "You Win!"
			_set_avatar_local()
		else:
			winner_text.text = p1_name + " Wins!"
			_set_avatar_opponent(1)
	elif p2_score > p1_score:
		if my_id == 2:
			winner_text.text = "You Win!"
			_set_avatar_local()
		else:
			if GameSession.selected_mode == "Multiplayer":
				winner_text.text = p2_name + " Wins!"
				_set_avatar_opponent(2)
			else:
				winner_text.text = GameSession.bot_name + " Wins!"
				var bot_avatar := get_node_or_null("../InGame UI/VS_IntroPanel/BotCard/Avatar") as TextureRect
				if bot_avatar:
					winner_avatar.texture = bot_avatar.texture
	else:
		winner_text.text = "It's a Tie!"
		_set_avatar_local()

func _set_avatar_local() -> void:
	var profile_index := Prefs.get_int("profile_index", 0)
	if profile_index == 1:
		winner_avatar.texture = load("res://Texture Or Sprites/Profile Screen/FemaleIcon.png")
	else:
		winner_avatar.texture = load("res://Texture Or Sprites/Profile Screen/MaleIcon.png")

func _set_avatar_opponent(opp_id: int) -> void:
	var opp_profile_index := 0
	if NetworkManager.players.has(opp_id):
		var opp_data = NetworkManager.players[opp_id]
		if typeof(opp_data) == TYPE_DICTIONARY and opp_data.has("profile_index"):
			opp_profile_index = int(opp_data["profile_index"])
	if opp_profile_index == 1:
		winner_avatar.texture = load("res://Texture Or Sprites/Profile Screen/FemaleIcon.png")
	else:
		winner_avatar.texture = load("res://Texture Or Sprites/Profile Screen/MaleIcon.png")

func _on_home_pressed() -> void:
	SoundManager.play_button_clicks()
	UIManager.home()

func _on_restart_pressed() -> void:
	SoundManager.play_button_clicks()
	if GameSession.selected_mode == "Multiplayer":
		var rematch_btn = get_node_or_null("Control/GameOver BG/Restart") as Button
		if rematch_btn:
			rematch_btn.disabled = true
		
		if NetworkManager.pending_rematch_requester_id > 0:
			# Accept incoming rematch request
			if multiplayer and multiplayer.is_server():
				NetworkManager.accept_rematch()
			else:
				NetworkManager.accept_rematch.rpc_id(1)
		else:
			# Send rematch request to opponent
			NetworkManager.send_rematch_request()
			winner_text.text = "Rematch requested..."
	else:
		UIManager.restart()

func _on_rematch_requested() -> void:
	winner_text.text = "Opponent wants a rematch!"
	var rematch_btn = get_node_or_null("Control/GameOver BG/Restart") as Button
	if rematch_btn:
		rematch_btn.disabled = false

func _on_rematch_declined(message: String) -> void:
	winner_text.text = message
	var rematch_btn = get_node_or_null("Control/GameOver BG/Restart") as Button
	if rematch_btn:
		rematch_btn.disabled = true
