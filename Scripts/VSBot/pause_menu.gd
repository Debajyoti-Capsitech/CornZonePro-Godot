extends CanvasLayer

func _ready() -> void:
	GameSession.pots_update.connect(_sync_total_scores)
	_sync_total_scores()

func _on_resume_pressed() -> void:
	GameSession.game_paused = false
	SoundManager.play_button_clicks()
	UIManager.toggle_canvas($".")

func _on_cross_pressed() -> void:
	GameSession.game_paused = false
	SoundManager.play_button_clicks()
	UIManager.toggle_canvas($".")

func _on_restart_pressed() -> void:
	GameSession.game_paused = false
	SoundManager.play_button_clicks()
	UIManager.restart()

func _on_home_pressed() -> void:
	GameSession.game_paused = false
	SoundManager.play_button_clicks()
	UIManager.home()

func _sync_total_scores() -> void:
	$"Control/PausePanel BG/Dash/Player 1 Score".text = str(GameSession.score_p1)
	$"Control/PausePanel BG/Dash/Player 2 Score".text = str(GameSession.score_p2)
