# =========================
# corn_bag.gd
# =========================
extends RigidBody3D

const AWARDED_POINTS_META := "awarded_points"
const POINTER_SCORED_META := "pointer_scored"
const TOUCHED_BOARD_META := "touched_board"

@onready var swipe_controller: SwipeInputController = $SwipeInputController
@onready var bag_visual: GeometryInstance3D = $sandbag_geo1

var thrown: bool = false
var throw_requested: bool = false
var throw_ribbon: MeshInstance3D
var throw_ribbon_mesh: ImmediateMesh
var throw_trail_points: Array = []
var throw_trail_point_ages: Array = []
var throw_trail_active: bool = false

@export var throw_gravity_scale: float = 4.0

@export_group("Throw Trail")
@export var throw_trail_enabled: bool = true
@export var throw_trail_color: Color = Color(0.1, 0.45, 0.85, 0.95)
@export var throw_trail_lifetime: float = 0.35
@export var throw_trail_speed_threshold: float = 0.5
@export var throw_ribbon_width: float = 0.22
@export var throw_ribbon_min_point_distance: float = 0.18
@export var throw_ribbon_max_points: int = 10

var micro_interaction_img = "res://Texture Or Sprites/MicroInteractions/oops.png"

func _ready() -> void:
	add_to_group("active_bag")

	print("NODE PATH:", get_path(), " AUTH:", get_multiplayer_authority())

	thrown = false
	throw_requested = false

	freeze = true
	sleeping = false

	contact_monitor = true
	max_contacts_reported = 8

	if not swipe_controller.swipe_completed.is_connected(_on_swipe_completed):
		swipe_controller.swipe_completed.connect(_on_swipe_completed)

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	_apply_bag_visual()
	_setup_throw_trail()
	set_process(false)

func _process(delta: float) -> void:
	if not throw_trail_enabled:
		set_process(false)
		return

	if not throw_trail_active and throw_trail_points.is_empty():
		set_process(false)
		return

	var speed: float = linear_velocity.length()
	var trail_should_emit := throw_trail_active and speed > throw_trail_speed_threshold

	_update_throw_ribbon(delta, trail_should_emit)

func is_waiting_for_throw() -> bool:
	return not thrown and not throw_requested


func _mark_as_thrown() -> void:
	thrown = true
	throw_requested = false
	if is_in_group("active_bag"):
		remove_from_group("active_bag")


func _apply_bag_visual() -> void:
	if bag_visual == null:
		return

	var throw_player := int(get_meta("throw_player", 1))
	var material: Material = null
	var bag_name: String = ""
	var bag_config: BagConfig = null

	if (
		GameSession.selected_mode == "Local"
		or GameSession.selected_mode == "PassPlay"
	):
		bag_config = NetworkManager.get_bag_config_for_player(throw_player)
	else:
		bag_config = NetworkManager.get_bag_config_by_id(NetworkManager.get_local_bag_id())

	if bag_config:
		material = bag_config.material_override
		bag_name = bag_config.bag_name
		# Only Epic or Rare bags have trails. Standard bags do not.
		if bag_config.rarity == BagConfig.Rarity.Epic or bag_config.rarity == BagConfig.Rarity.Rare:
			throw_trail_enabled = true
		else:
			throw_trail_enabled = false
	else:
		# Fallback if config is not found (default to no trail for standard/unconfigured bags)
		throw_trail_enabled = false

	if material != null:
		bag_visual.material_override = material

	_update_trail_color_for_bag(bag_config)


func _update_trail_color_for_bag(bag_config: BagConfig = null) -> void:
	if bag_config:
		throw_trail_color = bag_config.trail_color
	else:
		throw_trail_color = Color(0.3, 0.6, 0.9, 0.8) # Default fallback color

func _setup_throw_trail() -> void:
	if not throw_trail_enabled:
		return

	throw_ribbon_mesh = ImmediateMesh.new()
	throw_ribbon = MeshInstance3D.new()
	throw_ribbon.name = "ThrowRibbon"
	throw_ribbon.mesh = throw_ribbon_mesh
	throw_ribbon.top_level = true
	throw_ribbon.global_transform = Transform3D.IDENTITY
	throw_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	throw_ribbon.material_override = _create_throw_ribbon_material()
	add_child(throw_ribbon)


func _create_throw_ribbon_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _update_throw_ribbon(delta: float, trail_should_emit: bool) -> void:
	for index in range(throw_trail_point_ages.size()):
		throw_trail_point_ages[index] = float(throw_trail_point_ages[index]) + delta

	# Since points are appended sequentially, the oldest is always at index 0.
	# We can remove expired points from the front.
	while not throw_trail_point_ages.is_empty() and float(throw_trail_point_ages[0]) > throw_trail_lifetime:
		throw_trail_point_ages.remove_at(0)
		throw_trail_points.remove_at(0)

	if trail_should_emit:
		var current_position := global_position
		var min_dist_sq := throw_ribbon_min_point_distance * throw_ribbon_min_point_distance
		if throw_trail_points.is_empty() or current_position.distance_squared_to(throw_trail_points[-1]) >= min_dist_sq:
			throw_trail_points.append(current_position)
			throw_trail_point_ages.append(0.0)

		while throw_trail_points.size() > throw_ribbon_max_points:
			throw_trail_points.remove_at(0)
			throw_trail_point_ages.remove_at(0)

	_rebuild_throw_ribbon()


func _rebuild_throw_ribbon() -> void:
	if throw_ribbon_mesh == null:
		return

	throw_ribbon_mesh.clear_surfaces()

	var points_count := throw_trail_points.size()
	if points_count < 2:
		return

	# Pre-calculate fades and colors to avoid redundant function calls in the loop
	var fades := PackedFloat32Array()
	fades.resize(points_count)
	var colors := []
	colors.resize(points_count)

	for i in range(points_count):
		var age := float(throw_trail_point_ages[i])
		var fade := clampf(1.0 - (age / throw_trail_lifetime), 0.0, 1.0)
		fades[i] = fade

		var color := throw_trail_color.lerp(Color(1.0, 1.0, 1.0, throw_trail_color.a), fade * 0.08)
		color.a = throw_trail_color.a * fade * fade
		colors[i] = color

	var camera := get_viewport().get_camera_3d()
	throw_ribbon_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)

	for index in range(1, points_count):
		var previous_position: Vector3 = throw_trail_points[index - 1]
		var current_position: Vector3 = throw_trail_points[index]
		var segment_direction := current_position - previous_position
		if segment_direction.length_squared() <= 0.0001:
			continue

		segment_direction = segment_direction.normalized()
		var mid_position := (previous_position + current_position) * 0.5
		var view_direction := Vector3.UP
		if camera:
			view_direction = (camera.global_position - mid_position).normalized()

		var side := segment_direction.cross(view_direction)
		if side.length_squared() <= 0.0001:
			side = segment_direction.cross(Vector3.UP)
		if side.length_squared() <= 0.0001:
			side = Vector3.RIGHT
		side = side.normalized()

		var previous_fade := fades[index - 1]
		var current_fade := fades[index]
		var previous_width := throw_ribbon_width * previous_fade
		var current_width := throw_ribbon_width * current_fade

		var p_left := previous_position - side * previous_width
		var p_right := previous_position + side * previous_width
		var c_left := current_position - side * current_width
		var c_right := current_position + side * current_width

		var previous_color: Color = colors[index - 1]
		var current_color: Color = colors[index]

		_add_throw_ribbon_triangle(p_left, p_right, c_right, previous_color, previous_color, current_color)
		_add_throw_ribbon_triangle(p_left, c_right, c_left, previous_color, current_color, current_color)

	throw_ribbon_mesh.surface_end()


func _add_throw_ribbon_triangle(
	a: Vector3,
	b: Vector3,
	c: Vector3,
	a_color: Color,
	b_color: Color,
	c_color: Color
) -> void:
	throw_ribbon_mesh.surface_set_color(a_color)
	throw_ribbon_mesh.surface_add_vertex(a)
	throw_ribbon_mesh.surface_set_color(b_color)
	throw_ribbon_mesh.surface_add_vertex(b)
	throw_ribbon_mesh.surface_set_color(c_color)
	throw_ribbon_mesh.surface_add_vertex(c)


func _start_throw_trail() -> void:
	if not throw_trail_enabled:
		return

	throw_trail_active = true
	throw_trail_points.clear()
	throw_trail_point_ages.clear()
	set_process(true)

func _stop_throw_trail() -> void:
	if not throw_trail_enabled:
		return

	throw_trail_active = false

	await get_tree().create_timer(throw_trail_lifetime).timeout

	throw_trail_points.clear()
	throw_trail_point_ages.clear()
	_rebuild_throw_ribbon()
	set_process(false)

func _start_throw_physics(direction: Vector3, strength: float) -> void:
	freeze = false
	sleeping = false
	gravity_scale = throw_gravity_scale
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	set_meta(AWARDED_POINTS_META, 0)
	set_meta(POINTER_SCORED_META, false)
	set_meta(TOUCHED_BOARD_META, false)
	apply_central_impulse(direction * strength)
	_mark_as_thrown()
	_start_throw_trail()


func _on_swipe_completed(direction: Vector3, strength: float) -> void:
	if thrown or throw_requested:
		return

	# Offline
	if GameSession.selected_mode != "Local":
		_apply_throw(direction, strength)
		return

	# Multiplayer missing
	if not multiplayer or multiplayer.multiplayer_peer == null:
		return

	# Turn check
	if not _is_my_turn():
		print("Blocked: Not your turn")
		return

	# Host throws directly
	if multiplayer.is_server():
		_apply_throw(direction, strength)
	else:
		print("CLIENT sending RPC throw")
		throw_requested = true

		# Tell host
		NetworkManager.request_throw.rpc_id(1, direction, strength)


func server_apply_throw(direction: Vector3, strength: float) -> void:
	_apply_throw(direction, strength)


func _apply_throw(direction: Vector3, strength: float) -> void:
	if thrown:
		return
	SoundManager.play_bag_throw()
	set_meta("throw_player", GameSession.current_turn)
	_start_throw_physics(direction, strength)
	if has_node("/root/AnimateManager"):
		AnimateManager.start_bag_tracking(self)
	AnimateManager.show_once = true

	# Sync to clients
	if (
		GameSession.selected_mode == "Local"
		and multiplayer
		and multiplayer.is_server()
	):
		sync_throw.rpc(direction, strength)

	# Offline modes still need to advance the turn and spawn the next bag.
	var should_schedule_next_bag := GameSession.selected_mode != "Local"
	if (
		GameSession.selected_mode == "Local"
		and multiplayer
		and multiplayer.is_server()
	):
		should_schedule_next_bag = true

	if should_schedule_next_bag:
		await get_tree().create_timer(1.5).timeout
		call_deferred("request_next_bag")


@rpc("authority", "reliable")
func sync_throw(direction: Vector3, strength: float) -> void:
	if multiplayer.is_server():
		return

	_start_throw_physics(direction, strength)


func request_next_bag() -> void:
	if has_node("/root/AnimateManager"):
		AnimateManager.start_camera_return()
	var scoring_player: int = GameSession.current_turn

	if has_meta("throw_player"):
		scoring_player = int(get_meta("throw_player"))

	var bag_score: int = int(get_meta("awarded_points", 0))

	var uses_bag_result_slots := (
		GameSession.selected_mode == "PassPlay"
		or GameSession.selected_mode == "Local"
	)

	if uses_bag_result_slots:
		var bag_result_index := GameSession.record_bag_result(
			scoring_player,
			bag_score
		)

		set_meta("bag_result_index", bag_result_index)
		set_meta("awarded_points", bag_score)
	GameSession.on_bag_thrown()
	var next_throw_player := GameSession.current_turn

	if GameSession.match_over:
		return

	if GameSession.selected_mode == "Local":
		if multiplayer and multiplayer.is_server():
			var spawn_point := get_parent()
			if is_instance_valid(spawn_point):
				spawn_point.call_deferred("spawn_bag", next_throw_player)
				spawn_point.rpc("spawn_bag_rpc", next_throw_player)
	else:
		get_parent().call_deferred("spawn_bag", next_throw_player)


func _is_my_turn() -> bool:
	if not multiplayer or multiplayer.multiplayer_peer == null:
		return true

	var my_id := 1 if multiplayer.is_server() else 2

	print("TURN:", GameSession.current_turn, " MY ID:", my_id)

	return GameSession.current_turn == my_id


func _on_body_entered(body: Node) -> void:
	_stop_throw_trail()
	SoundManager.play_bag_drop()
	if body.has_method("on_bag_landed"):
		body.on_bag_landed(self)
		return

	if _is_ground_body(body):
		await get_tree().create_timer(0.1).timeout  # wait for body_exited to fire
		
		print("GROUND PE GIR GAYA")
		
		if not AnimateManager.is_pot:
			AnimateManager.successive_pots = 0
			if AnimateManager.show_once:
				AnimateManager.micro_interaction_signal.emit(micro_interaction_img)
		
		AnimateManager.is_pot = false
		AnimateManager.show_once = false
		print("BAG ON GROUND")
		_handle_ground_after_board()


func _is_ground_body(body: Node) -> bool:
	return body is StaticBody3D and body.name == "Ground"


func _handle_ground_after_board() -> void:
	if GameSession.selected_mode == "Local":
		if not multiplayer or multiplayer.multiplayer_peer == null or not multiplayer.is_server():
			return

	if bool(get_meta(POINTER_SCORED_META, false)):
		return
	if not bool(get_meta(TOUCHED_BOARD_META, false)):
		return

	var awarded_points := int(get_meta(AWARDED_POINTS_META, 0))
	if awarded_points <= 0:
		return

	var scoring_player: int = int(get_meta("throw_player", GameSession.current_turn))
	set_meta(AWARDED_POINTS_META, 0)
	GameSession.add_score(scoring_player, -awarded_points)
	GameSession.pots_update.emit()

	if has_meta("bag_result_index"):
		GameSession.update_bag_result(scoring_player, int(get_meta("bag_result_index")), 0)

	if GameSession.selected_mode == "Local" and GameSession.mode_logic and GameSession.mode_logic.has_method("sync_match_state"):
		GameSession.mode_logic.sync_match_state()
