extends Node

const BAGS_PER_PLAYER := 4

var p1_bags_thrown: int = 0
var p2_bags_thrown: int = 0
var results_saved: bool = false


func is_network_game() -> bool:
	return GameSession.selected_mode == "Local" or GameSession.selected_mode == "Multiplayer"


func is_host() -> bool:
	return multiplayer != null and multiplayer.multiplayer_peer != null and multiplayer.is_server()


func on_ball_entered(body: Node3D) -> void:
	if not is_network_game():
		_apply_score(body)
		return

	if not is_host():
		return

	_apply_score(body)
	sync_match_state()


func on_bag_thrown() -> void:
	if not is_network_game():
		_apply_bag_thrown()
		return

	if not is_host():
		return

	_apply_bag_thrown()
	sync_match_state()


func sync_match_state() -> void:
	if not is_network_game() or not is_host():
		return

	sync_match_state_rpc.rpc(
		GameSession.current_turn,
		p1_bags_thrown,
		p2_bags_thrown,
		GameSession.score_p1,
		GameSession.score_p2,
		GameSession.p1_bag_results.duplicate(),
		GameSession.p2_bag_results.duplicate(),
		GameSession.match_over
	)


func _apply_bag_thrown() -> void:
	if GameSession.current_turn == 1:
		p1_bags_thrown += 1
	else:
		p2_bags_thrown += 1

	if p1_bags_thrown >= BAGS_PER_PLAYER and p2_bags_thrown >= BAGS_PER_PLAYER:
		_save_scores()
		GameSession.end_match()
		GameSession.turns_exhausted.emit()
		return

	var next_turn := 2 if GameSession.current_turn == 1 else 1
	GameSession.current_turn = next_turn
	GameSession.turn_changed.emit(next_turn)

#  THIS LINE IS THE FIX
	sync_turn.rpc(next_turn)


func on_match_end() -> void:
	if not results_saved and (GameSession.score_p1 > 0 or GameSession.score_p2 > 0):
		_save_scores()
	_reset_round()


func _reset_round() -> void:
	p1_bags_thrown = 0
	p2_bags_thrown = 0
	results_saved = false


func _save_scores() -> void:
	if results_saved:
		return

	Prefs.set_int("last_score_p1", GameSession.score_p1)
	Prefs.set_int("last_score_p2", GameSession.score_p2)

	if GameSession.score_p1 > GameSession.score_p2:
		var wins: int = int(Prefs.get_int("p1_wins", 0))
		Prefs.set_int("p1_wins", wins + 1)
	elif GameSession.score_p2 > GameSession.score_p1:
		var wins: int = int(Prefs.get_int("p2_wins", 0))
		Prefs.set_int("p2_wins", wins + 1)

	Prefs.save()
	results_saved = true


@rpc("authority", "reliable")
func sync_match_state_rpc(
	turn: int,
	p1_count: int,
	p2_count: int,
	score_p1: int,
	score_p2: int,
	p1_results: Array,
	p2_results: Array,
	match_over: bool
) -> void:
	var was_match_over: bool = GameSession.match_over

	GameSession.current_turn = turn
	p1_bags_thrown = p1_count
	p2_bags_thrown = p2_count
	GameSession.score_p1 = score_p1
	GameSession.score_p2 = score_p2
	GameSession.p1_bag_results = p1_results.duplicate()
	GameSession.p2_bag_results = p2_results.duplicate()
	GameSession.match_over = match_over

	GameSession.pots_update.emit()
	GameSession.turn_changed.emit(turn)
	_emit_bag_result_changes(1, GameSession.p1_bag_results)
	_emit_bag_result_changes(2, GameSession.p2_bag_results)

	if GameSession.match_over and not was_match_over:
		GameSession.turns_exhausted.emit()


func _emit_bag_result_changes(player: int, results: Array) -> void:
	for index in range(results.size()):
		GameSession.bag_result_changed.emit(player, index, int(results[index]))


func _apply_score(body: Node3D) -> void:
	var scoring_player: int = GameSession.current_turn
	if body.has_meta("throw_player"):
		scoring_player = int(body.get_meta("throw_player"))

	var awarded_points: int = int(body.get_meta("awarded_points", 0))
	var delta: int = maxi(0, 3 - awarded_points)

	body.set_meta("awarded_points", 3)
	GameSession.add_score(scoring_player, delta)

@rpc("authority", "reliable")
func sync_turn(turn: int):
	GameSession.current_turn = turn
	print("Synced turn:", turn)
