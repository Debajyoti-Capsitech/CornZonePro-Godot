extends Node

const BAGS_PER_PLAYER := 4

var p1_bags_thrown: int = 0
var p2_bags_thrown: int = 0
var bot_pots_count: int = 0
var results_saved: bool = false
var _cached_hole_node: CollisionShape3D = null

func on_ball_entered(body: Node3D) -> void:
	var scoring_player := GameSession.current_turn
	if body.has_meta("throw_player"):
		scoring_player = int(body.get_meta("throw_player"))
	var awarded_points := int(body.get_meta("awarded_points", 0))
	var delta: int = maxi(0, 3 - awarded_points)
	body.set_meta("awarded_points", 3)
	GameSession.add_score(scoring_player, delta)
	
	if scoring_player == 2 and awarded_points < 3:
		bot_pots_count += 1
		print("[VSBotMode] Bot Potted! Total pots this match: ", bot_pots_count)

func on_bag_thrown() -> void:
	if GameSession.current_turn == 1:
		p1_bags_thrown += 1
	else:
		p2_bags_thrown += 1

	if p1_bags_thrown >= BAGS_PER_PLAYER and p2_bags_thrown >= BAGS_PER_PLAYER:
		_save_results()
		GameSession.end_match()
		GameSession.turns_exhausted.emit()
		return

	# Alternate turn
	GameSession.current_turn = 2 if GameSession.current_turn == 1 else 1
	GameSession.turn_changed.emit(GameSession.current_turn)

	# If it is the Bot's turn (Player 2), trigger the bot throw
	if GameSession.current_turn == 2 and not GameSession.match_over:
		if GameSession.selected_mode != "Multiplayer":
			trigger_bot_throw()

func trigger_bot_throw() -> void:
	# Wait for the bag to spawn and add a natural delay for bot thinking
	await get_tree().create_timer(0.6).timeout

	if GameSession.match_over:
		return

	# Find the active bag for Player 2 (Bot)
	var active_bags = get_tree().get_nodes_in_group("active_bag")
	if active_bags.is_empty():
		push_error("[VSBotMode] Bot active bag not found!")
		return
	var bot_bag := active_bags[0] as RigidBody3D
	if not is_instance_valid(bot_bag):
		return

	var start_pos := bot_bag.global_position

	# Retrieve the hole position dynamically, fallback if not found
	var hole_shape = _get_hole_node()
	var target_pos := Vector3.ZERO
	if hole_shape != null:
		target_pos = hole_shape.global_position
	else:
		push_warning("[VSBotMode] Board hole node not found! Using fallback target position.")
		target_pos = Vector3(0, 1.23, 35.47)

	# Calculate direction vector to target
	var to_target := target_pos - start_pos
	var forward_dir := Vector3(to_target.x, 0.0, to_target.z).normalized()
	if forward_dir.is_zero_approx():
		forward_dir = Vector3.FORWARD
	var lateral_dir := Vector3(-forward_dir.z, 0.0, forward_dir.x)

	# Super Human Brain Decision Making
	var difficulty = GameSession.bot_difficulty
	var p1_score := GameSession.score_p1
	var p2_score := GameSession.score_p2
	var score_diff := p1_score - p2_score
	var bags_remaining := BAGS_PER_PLAYER - p2_bags_thrown
	
	# Determine intended play type (POT, BOARD, or MISS)
	var play_type = "BOARD" # Default fallback
	
	# Decision 1: Last throw clutch check
	if bags_remaining == 1:
		if score_diff >= 2 and score_diff <= 3:
			# Needs a pot to draw or win! Go all-in.
			if difficulty != "EASY BOT":
				play_type = "POT"
				print("[VSBotMode AI] Clutch Decision: Going all-in for POT to catch up!")
		elif score_diff == 1:
			# Needs at least a board hit to draw. Play safe.
			play_type = "BOARD"
			print("[VSBotMode AI] Clutch Decision: Playing safe on the BOARD to secure points!")
	
	# If not clutched, determine based on difficulty and score difference
	if play_type == "BOARD" or bags_remaining > 1:
		var pot_chance := 0.0
		var board_chance := 0.0
		
		match difficulty:
			"PRO BOT":
				# Base: 45% Pot, 47% Board, 8% Miss
				pot_chance = 0.45
				var base_miss := 0.08
				if score_diff > 0:
					pot_chance += score_diff * 0.15
					base_miss -= score_diff * 0.02 # Misses even less when focused
				else:
					pot_chance += score_diff * 0.08
					base_miss -= score_diff * 0.02 # Misses slightly more when relaxed
				pot_chance = clamp(pot_chance, 0.20, 0.95)
				var miss_chance = clamp(base_miss, 0.02, 0.15)
				board_chance = 1.0 - pot_chance - miss_chance
				
			"HARD BOT":
				# Base: 25% Pot, 55% Board, 20% Miss
				pot_chance = 0.25
				var base_miss := 0.20
				if score_diff > 0:
					pot_chance += score_diff * 0.10
					base_miss -= score_diff * 0.03
				else:
					pot_chance += score_diff * 0.05
					base_miss -= score_diff * 0.02
				pot_chance = clamp(pot_chance, 0.10, 0.70)
				var miss_chance = clamp(base_miss, 0.05, 0.35)
				board_chance = 1.0 - pot_chance - miss_chance
				
			"EASY BOT", _:
				# Base: 8% Pot (max 2 pots), 52% Board, 40% Miss
				var base_miss := 0.40
				if bot_pots_count < 2:
					pot_chance = 0.08
					if score_diff > 0:
						pot_chance += score_diff * 0.04
						base_miss -= score_diff * 0.03
					pot_chance = clamp(pot_chance, 0.02, 0.25)
				else:
					pot_chance = 0.0
				var miss_chance = clamp(base_miss, 0.20, 0.60)
				board_chance = 1.0 - pot_chance - miss_chance
		
		var r = randf()
		if r < pot_chance:
			play_type = "POT"
		elif r < (pot_chance + board_chance):
			play_type = "BOARD"
		else:
			play_type = "MISS"
			
	# Apply offsets based on final decision
	var lateral_offset := 0.0
	var forward_offset := 0.0
	match play_type:
		"POT":
			# Highly accurate throw
			var precision = 0.02
			if difficulty == "HARD BOT":
				precision = 0.03
			elif difficulty == "EASY BOT":
				precision = 0.04
			lateral_offset = randf_range(-precision, precision)
			forward_offset = randf_range(-precision, precision)
			print("[VSBotMode AI] Throw Decision: POT (Precision: ", precision, ")")
		"BOARD":
			var offset = get_non_pot_board_offset()
			lateral_offset = offset.x
			forward_offset = offset.y
			print("[VSBotMode AI] Throw Decision: BOARD")
		"MISS", _:
			var offset = get_complete_miss_offset()
			lateral_offset = offset.x
			forward_offset = offset.y
			print("[VSBotMode AI] Throw Decision: MISS")

	# Apply a clearance offset to target slightly deeper and higher to clear the front lip of the hole
	var clearance_target := target_pos + (forward_dir * 0.13) + Vector3(0.0, 0.06, 0.0)

	# Apply difficulty error offset to the target position
	var final_target := clearance_target + (lateral_dir * lateral_offset) + (forward_dir * forward_offset)

	# Introduce subtle random variation in flight time to make the arc look organic and realistic
	var t := randf_range(0.92, 1.05)

	# Fetch physics details dynamically from the bag and project settings
	var launch_gravity_scale: float = float(bot_bag.get("throw_gravity_scale")) if "throw_gravity_scale" in bot_bag else bot_bag.gravity_scale
	var default_gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var default_gravity_vector: Vector3 = ProjectSettings.get_setting("physics/3d/default_gravity_vector", Vector3.DOWN)
	var gravity_vec := default_gravity_vector * default_gravity * launch_gravity_scale
	var damp := maxf(0.0, bot_bag.linear_damp)

	# Solve projectile equations with a discrete numerical solver that matches Godot's Semi-Implicit Euler integration exactly
	var dt := 1.0 / Engine.get_physics_ticks_per_second()
	
	# Initial analytical guess (using continuous formula)
	var v_guess := Vector3.ZERO
	if damp <= 0.0001:
		v_guess = (final_target - start_pos) / t - 0.5 * gravity_vec * (t + dt)
	else:
		var exp_factor := exp(-damp * t)
		var coeff := damp / (1.0 - exp_factor)
		var gravity_term := (gravity_vec / damp) * (t - (1.0 - exp_factor) / damp)
		v_guess = coeff * ((final_target - start_pos) - gravity_term) - 0.5 * gravity_vec * dt

	# If guess is zero-approx, use a default forward vector
	if v_guess.is_zero_approx():
		v_guess = Vector3.UP + forward_dir * 10.0

	# 1. Run simulation with zero initial velocity to isolate gravity/damp offset B
	var pos_b := start_pos
	var vel_b := Vector3.ZERO
	var N := int(round(t / dt))
	for i in range(N):
		var next_vel = vel_b + gravity_vec * dt
		if damp > 0.0:
			next_vel /= 1.0 + (damp * dt)
		pos_b = pos_b + next_vel * dt
		vel_b = next_vel
	var B := pos_b

	# 2. Run simulation with guess velocity to get P_sim
	var pos_sim := start_pos
	var vel_sim := v_guess
	for i in range(N):
		var next_vel = vel_sim + gravity_vec * dt
		if damp > 0.0:
			next_vel /= 1.0 + (damp * dt)
		pos_sim = pos_sim + next_vel * dt
		vel_sim = next_vel
	var P_sim := pos_sim

	# 3. Solve for exact v_0 using the linear relation: v_0 = v_guess * (target - B) / (P_sim - B)
	var v_0 := Vector3.ZERO
	var denom_x := P_sim.x - B.x
	var denom_y := P_sim.y - B.y
	var denom_z := P_sim.z - B.z

	v_0.x = v_guess.x * (final_target.x - B.x) / denom_x if abs(denom_x) > 0.0001 else v_guess.x
	v_0.y = v_guess.y * (final_target.y - B.y) / denom_y if abs(denom_y) > 0.0001 else v_guess.y
	v_0.z = v_guess.z * (final_target.z - B.z) / denom_z if abs(denom_z) > 0.0001 else v_guess.z

	# Convert velocity vector to normalized direction and strength (accounting for mass)
	var target_dir := v_0.normalized()
	var strength: float = v_0.length() * bot_bag.mass

	print("[VSBotMode] Bot Difficulty: ", difficulty)
	print("[VSBotMode] Target error offsets: lateral=", lateral_offset, " forward=", forward_offset)
	print("[VSBotMode] Throwing bag: force=", strength, " dir=", target_dir, " flight_time=", t)

	if bot_bag.has_method("_apply_throw"):
		bot_bag.call("_apply_throw", target_dir, strength)

func on_match_end() -> void:
	if GameSession.match_over and not results_saved:
		_save_results()
	_reset_round()
	AnalyticsManager.log_event("VS Bot mode end")

func _reset_round() -> void:
	p1_bags_thrown = 0
	p2_bags_thrown = 0
	bot_pots_count = 0
	results_saved = false
	_cached_hole_node = null

func _save_results() -> void:
	if results_saved:
		return

	# Save results to local Prefs
	Prefs.set_int("vsbot_last_score_p1", GameSession.score_p1)
	Prefs.set_int("vsbot_last_score_p2", GameSession.score_p2)

	var total_score_p1 := int(Prefs.get_int("vsbot_total_score_p1", 0))
	var total_score_p2 := int(Prefs.get_int("vsbot_total_score_p2", 0))
	Prefs.set_int("vsbot_total_score_p1", total_score_p1 + GameSession.score_p1)
	Prefs.set_int("vsbot_total_score_p2", total_score_p2 + GameSession.score_p2)

	if GameSession.score_p1 > GameSession.score_p2:
		var p1_wins := int(Prefs.get_int("vsbot_p1_wins", 0))
		Prefs.set_int("vsbot_p1_wins", p1_wins + 1)
	elif GameSession.score_p2 > GameSession.score_p1:
		var p2_wins := int(Prefs.get_int("vsbot_p2_wins", 0))
		Prefs.set_int("vsbot_p2_wins", p2_wins + 1)

	Prefs.save()
	results_saved = true

func _get_hole_node() -> CollisionShape3D:
	if is_instance_valid(_cached_hole_node):
		return _cached_hole_node
	var current_scene = get_tree().current_scene
	if current_scene == null:
		return null
	var board = current_scene.get_node_or_null("Board")
	if board == null:
		return null
	_cached_hole_node = board.get_node_or_null("Area3D/CollisionShape3D") as CollisionShape3D
	return _cached_hole_node

func get_non_pot_board_offset() -> Vector2:
	var offsets = []
	# 1. Left side of the hole (avoiding sliding range)
	offsets.append(Vector2(randf_range(0.14, 0.26), randf_range(-0.10, 0.25)))
	# 2. Right side of the hole (avoiding sliding range)
	offsets.append(Vector2(randf_range(-0.26, -0.14), randf_range(-0.10, 0.25)))
	# 3. Short of the hole (below the hole on the board, so it slides away from the hole)
	offsets.append(Vector2(randf_range(-0.12, 0.12), randf_range(-0.35, -0.15)))
	
	return offsets[randi() % offsets.size()]

func get_complete_miss_offset() -> Vector2:
	var offsets = []
	# Left miss
	offsets.append(Vector2(randf_range(0.45, 0.70), randf_range(-0.35, 0.35)))
	# Right miss
	offsets.append(Vector2(randf_range(-0.70, -0.45), randf_range(-0.35, 0.35)))
	# Short miss
	offsets.append(Vector2(randf_range(-0.30, 0.30), randf_range(-0.70, -0.50)))
	
	return offsets[randi() % offsets.size()]
