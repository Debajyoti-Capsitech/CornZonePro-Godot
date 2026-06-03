extends CanvasLayer

@onready var p1_total_score: Label = $"ScoreBoard/P1 Total Score"
@onready var p2_total_score: Label = $"ScoreBoard/P2 Total Score"

@onready var p1_turn_ui = $Player1TurnUI
@onready var p2_turn_ui = $Player2TurnUI

# Player 1 score labels
@onready var p1_scores: Array[Label] = [
	$"ScoreBoard/Player 1 Scores/p1/1st score",
	$"ScoreBoard/Player 1 Scores/p2/2nd score",
	$"ScoreBoard/Player 1 Scores/p3/3rd score",
	$"ScoreBoard/Player 1 Scores/p4/4th score"
]

# Player 2 score labels (same structure)
@onready var p2_scores: Array[Label] = [
	$"ScoreBoard/Player 2 Scores/p1/1st score",
	$"ScoreBoard/Player 2 Scores/p2/2nd score",
	$"ScoreBoard/Player 2 Scores/p3/3rd score",
	$"ScoreBoard/Player 2 Scores/p4/4th score"
]

var p1_score_history: Array[int] = []
var p2_score_history: Array[int] = []

func _ready() -> void:
	GameSession.pots_update.connect(_sync_total_scores)
	GameSession.bag_result_changed.connect(_on_bag_result_changed)
	GameSession.turn_changed.connect(_on_turn_changed)
	GameSession.turns_exhausted.connect(_on_match_over)
	_clear_labels()
	_sync_total_scores()
	if AnimateManager.has_signal("pot_scored_cinematic"):
		AnimateManager.pot_scored_cinematic.connect(_on_pot_scored_cinematic)
	p1_turn_ui.visible = true
	await get_tree().create_timer(1.0).timeout
	p1_turn_ui.visible = false
	print("Player ", GameSession.current_turn, "'s turn")

func _clear_labels() -> void:
	for label: Label in p1_scores:
		label.text = "-"
	for label: Label in p2_scores:
		label.text = "-"
	p1_score_history.clear()
	p2_score_history.clear()

func _sync_total_scores() -> void:
	p1_total_score.text = str(GameSession.score_p1)
	p2_total_score.text = str(GameSession.score_p2)

func _on_bag_result_changed(player: int, index: int, points: int) -> void:
	if player == 1:
		if index < 4:
			while p1_score_history.size() <= index:
				p1_score_history.append(0)
			p1_score_history[index] = points
			p1_scores[index].text = str(points)
	else:
		if index < 4:
			while p2_score_history.size() <= index:
				p2_score_history.append(0)
			p2_score_history[index] = points
			p2_scores[index].text = str(points)
	_sync_total_scores()

func _on_turn_changed(player: int) -> void:
	if player == 1:
		p1_turn_ui.visible = true
		await get_tree().create_timer(1.0).timeout
		p1_turn_ui.visible = false
	else:
		p2_turn_ui.visible = true
		await get_tree().create_timer(1.0).timeout
		p2_turn_ui.visible = false
	print("Player ", player, "'s turn")

func _on_match_over() -> void:
	SoundManager.play_game_over()
	_sync_total_scores()
	if UIManager.result_screen:
		UIManager.enable_canvas(UIManager.result_screen)


func _on_pause_button_pressed() -> void:
	GameSession.game_paused = true
	SoundManager.play_button_clicks()
	UIManager.toggle_canvas($"../PauseMenu")
	AnimateManager.pop_animation($"../PauseMenu/Control")

func _on_pot_scored_cinematic(is_perfect: bool) -> void:
	var flash = ColorRect.new()
	flash.name = "ScreenFlash"
	flash.anchor_right = 1.0
	flash.anchor_bottom = 1.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if is_perfect:
		flash.color = Color(1.0, 0.85, 0.2, 0.5)
	else:
		flash.color = Color(1.0, 1.0, 1.0, 0.4)
		
	add_child(flash)
	
	var fade_time = 0.45 if is_perfect else 0.35
	var tween = create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(flash, "color:a", 0.0, fade_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_callback(flash.queue_free)
	
