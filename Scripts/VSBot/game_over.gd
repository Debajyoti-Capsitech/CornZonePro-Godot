extends CanvasLayer

@onready var winner_text: Label = $"Control/GameOver BG/Player Winner Declaration"
@onready var winner_avatar: TextureRect = $"Control/GameOver BG/WinnerAvatar"

func _ready() -> void:
	GameSession.turns_exhausted.connect(_update_results)

func _update_results() -> void:
	SoundManager.play_game_over()
	UIManager.enable_canvas(self)
	AnimateManager.pop_animation($Control)
	
	var p1_score: int = GameSession.score_p1
	var p2_score: int = GameSession.score_p2

	if p1_score > p2_score:
		winner_text.text = "You Win!"
		var profile_index := Prefs.get_int("profile_index", 0)
		if profile_index == 1:
			winner_avatar.texture = load("res://Texture Or Sprites/Profile Screen/FemaleIcon.png")
		else:
			winner_avatar.texture = load("res://Texture Or Sprites/Profile Screen/MaleIcon.png")
	elif p2_score > p1_score:
		winner_text.text = GameSession.bot_name + " Wins!"
		var bot_avatar := get_node_or_null("../InGame UI/VS_IntroPanel/BotCard/Avatar") as TextureRect
		if bot_avatar:
			winner_avatar.texture = bot_avatar.texture
	else:
		winner_text.text = "It's a Tie!"
		var profile_index := Prefs.get_int("profile_index", 0)
		if profile_index == 1:
			winner_avatar.texture = load("res://Texture Or Sprites/Profile Screen/FemaleIcon.png")
		else:
			winner_avatar.texture = load("res://Texture Or Sprites/Profile Screen/MaleIcon.png")

func _on_home_pressed() -> void:
	SoundManager.play_button_clicks()
	UIManager.home()

func _on_restart_pressed() -> void:
	SoundManager.play_button_clicks()
	UIManager.restart()
