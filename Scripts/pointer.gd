extends Area3D

const SCORED_META := "pointer_scored"

func _ready() -> void:
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	
	if not (body is RigidBody3D):
		return
	if bool(body.get_meta(SCORED_META, false)):
		return
	if GameSession.mode_logic == null:
		return
	if not GameSession.mode_logic.has_method("on_ball_entered"):
		push_warning("[Pointer] Active mode cannot score bodies: " + GameSession.selected_mode)
		return
	
	SoundManager.play_bag_pot()
	if has_node("/root/AnimateManager"):
		AnimateManager.trigger_pot_cinematic(body, self)
	var scoring_player: int = int(body.get_meta("throw_player", GameSession.current_turn))
	var score_before: int = GameSession.score_p1 + GameSession.score_p2
	body.set_meta(SCORED_META, true)
	GameSession.mode_logic.on_ball_entered(body)
	var uses_bag_result_slots: bool = GameSession.selected_mode == "PassPlay" or GameSession.selected_mode == "Local" or GameSession.selected_mode == "Multiplayer"
	if uses_bag_result_slots and body.has_meta("bag_result_index"):
		GameSession.update_bag_result(scoring_player, int(body.get_meta("bag_result_index")), int(body.get_meta("awarded_points", 0)))

	var score_after: int = GameSession.score_p1 + GameSession.score_p2
	if score_after != score_before:
		GameSession.pots_update.emit()

func _on_body_exited(body: Node3D) -> void:
	AnimateManager.is_pot = true
