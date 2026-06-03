extends Node

signal notify
signal micro_interaction_signal(img_path: String)
signal party_popper_signal
signal pot_scored_cinematic(is_perfect: bool)

# Camera States
enum CamState { IDLE, TRACKING_FLIGHT, CINEMATIC_POT, RETURNING }
var current_state: CamState = CamState.IDLE

# Camera Properties
var camera_ref: Camera3D = null
var original_cam_transform: Transform3D
var original_cam_fov: float
var tracking_bag: Node3D = null
var cinematic_target_transform: Transform3D
var cinematic_timer: float = 0.0
var shake_intensity: float = 0.0
var shake_offset: Vector3 = Vector3.ZERO
var camera_tween: Tween = null

# Preserved Autoload Properties
var power_up: bool = false
var show_once: bool = true
var is_pot: bool = false
var successive_pots: int = 0
var early_cinematic_triggered: bool = false

# Constants
const CAMERA_PRESETS: Array[Vector3] = [
	Vector3(0.0, 7.0, 6.2),     # Straight-on front view (elevated, further back)
	Vector3(1.6, 7.0, 6.0),     # Straight-ish front-right view (elevated, further back)
	Vector3(-1.6, 4.6, 5.8)     # Straight-ish front-left view (elevated, further back)
]

func _process(delta: float) -> void:
	# Optimization: If camera is idle and shake has finished decaying, skip frame processing
	if current_state == CamState.IDLE and shake_intensity <= 0.001:
		if shake_intensity > 0.0:
			shake_intensity = 0.0
			shake_offset = Vector3.ZERO
		return

	# Calculate unscaled_delta to keep motion smooth during slow-motion
	var unscaled_delta: float = delta / max(0.0001, Engine.time_scale)

	# Exponential Camera Shake Decay
	if shake_intensity > 0.001:
		var random_dir := Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		)
		if random_dir.is_zero_approx():
			random_dir = Vector3.UP
		else:
			random_dir = random_dir.normalized()
		shake_offset = random_dir * shake_intensity
		shake_intensity *= exp(-6.0 * unscaled_delta)
	else:
		shake_intensity = 0.0
		shake_offset = Vector3.ZERO

	# State Behavior
	match current_state:
		CamState.TRACKING_FLIGHT:
			if is_instance_valid(tracking_bag):
				if is_instance_valid(camera_ref):
					camera_ref.look_at(tracking_bag.global_position)
				
				# Get velocity and position to detect early cinematic window
				var bag := tracking_bag as RigidBody3D
				if bag:
					var velocity := bag.linear_velocity
					var pos := bag.global_position
					
					# Target window: Z [35.4, 39.0], |X| <= 0.6, Y >= 1.0, moving forward (velocity.z < -1.0)
					# Only trigger if trajectory power_up is active
					if power_up and velocity.z < -1.0 and pos.z >= 35.4 and pos.z <= 39.0 and abs(pos.x) <= 0.6 and pos.y >= 1.0:
						trigger_pot_cinematic_early(tracking_bag)
			else:
				start_camera_return()

		CamState.CINEMATIC_POT:
			if is_instance_valid(camera_ref):
				var target_pos := cinematic_target_transform.origin + shake_offset
				var target_basis := cinematic_target_transform.basis
				var lerp_weight: float = clamp(12.0 * unscaled_delta, 0.0, 1.0)
				
				# Lerp position
				camera_ref.global_position = camera_ref.global_position.lerp(target_pos, lerp_weight)
				
				# Slerp basis using quaternions
				var current_quat := camera_ref.global_transform.basis.get_rotation_quaternion()
				var target_quat := target_basis.get_rotation_quaternion()
				var next_quat := current_quat.slerp(target_quat, lerp_weight)
				camera_ref.global_transform.basis = Basis(next_quat)
				
				# Lerp FOV towards 56.0
				camera_ref.fov = lerp(camera_ref.fov, 56.0, clamp(8.0 * unscaled_delta, 0.0, 1.0))
			
			# Decay cinematic timer
			cinematic_timer -= unscaled_delta
			if cinematic_timer <= 0.0:
				start_camera_return()

		CamState.RETURNING:
			pass

func start_bag_tracking(bag_node: Node3D) -> void:
	if current_state != CamState.IDLE:
		reset_camera()
	
	camera_ref = get_viewport().get_camera_3d()
	if is_instance_valid(camera_ref):
		original_cam_transform = camera_ref.global_transform
		original_cam_fov = camera_ref.fov
	
	tracking_bag = bag_node
	current_state = CamState.TRACKING_FLIGHT
	early_cinematic_triggered = false

func trigger_pot_cinematic_early(bag_node: Node3D) -> void:
	if current_state == CamState.CINEMATIC_POT:
		return
	
	current_state = CamState.CINEMATIC_POT
	early_cinematic_triggered = true
	
	# Determine if this is a perfect shot (has not touched the board)
	var is_perfect: bool = not bag_node.get_meta("touched_board", false)
	Engine.time_scale = 0.15 if is_perfect else 0.22
	
	# Picks a random close-up angle offset from the hole from presets
	var selected_preset := CAMERA_PRESETS[randi() % CAMERA_PRESETS.size()]
	
	# Find the global position of the hole Area3D if it exists in the scene
	var hole_pos := Vector3(0.0, 1.15, 36.0) # default fallback
	var board := get_tree().current_scene.find_child("Board", true, false)
	if board:
		var area := board.get_node_or_null("Area3D") as Area3D
		if area:
			hole_pos = area.global_position
			
	var target_pos := hole_pos + selected_preset
	
	# Point target camera towards the hole
	var target_trans := Transform3D()
	target_trans.origin = target_pos
	cinematic_target_transform = target_trans.looking_at(hole_pos, Vector3.UP)
	
	cinematic_timer = 2.2
	shake_intensity = 0.08

func trigger_pot_cinematic(bag_node: Node3D, hole_node: Node3D) -> void:
	if not power_up:
		return
		
	var is_perfect: bool = not bag_node.get_meta("touched_board", false)
	
	if current_state == CamState.CINEMATIC_POT or early_cinematic_triggered:
		# Intensify shake and slow time scale further for dramatic landing impact
		shake_intensity = 0.15 if is_perfect else 0.09
		Engine.time_scale = 0.12 if is_perfect else 0.18
		cinematic_timer = 0.5
		current_state = CamState.CINEMATIC_POT
	else:
		# Trigger if not already in early cinematic
		if current_state == CamState.IDLE:
			start_bag_tracking(bag_node)
			
		current_state = CamState.CINEMATIC_POT
		Engine.time_scale = 0.12 if is_perfect else 0.18
		
		var selected_preset := CAMERA_PRESETS[randi() % CAMERA_PRESETS.size()]
		var hole_pos := hole_node.global_position
		var target_pos := hole_pos + selected_preset
		
		var target_trans := Transform3D()
		target_trans.origin = target_pos
		cinematic_target_transform = target_trans.looking_at(hole_pos, Vector3.UP)
		
		cinematic_timer = 0.5
		shake_intensity = 0.15 if is_perfect else 0.09
		
	pot_scored_cinematic.emit(is_perfect)

func start_camera_return() -> void:
	Engine.time_scale = 1.0
	power_up = false
	
	if current_state == CamState.RETURNING:
		return
		
	current_state = CamState.RETURNING
	
	if camera_tween and camera_tween.is_valid():
		camera_tween.kill()
		
	if not is_instance_valid(camera_ref):
		camera_ref = get_viewport().get_camera_3d()
		
	if is_instance_valid(camera_ref):
		if original_cam_fov == 0.0 or original_cam_transform == Transform3D():
			original_cam_transform = camera_ref.global_transform
			original_cam_fov = camera_ref.fov
			
		var start_transform := camera_ref.global_transform
		
		# Define callable lambdas as local variables to avoid inline indentation parser issues
		var lerp_cam := func(t: float) -> void:
			if is_instance_valid(camera_ref):
				camera_ref.global_transform = start_transform.interpolate_with(original_cam_transform, t)
				
		var on_finished := func() -> void:
			if is_instance_valid(camera_ref):
				camera_ref.global_transform = original_cam_transform
				camera_ref.fov = original_cam_fov
			current_state = CamState.IDLE
			tracking_bag = null
		
		# Create a smooth Tween to return the camera to its original place
		camera_tween = create_tween().set_parallel(true)
		camera_tween.set_trans(Tween.TRANS_CUBIC)
		camera_tween.set_ease(Tween.EASE_OUT)
		
		camera_tween.tween_method(lerp_cam, 0.0, 1.0, 0.8)
		camera_tween.tween_property(camera_ref, "fov", original_cam_fov, 0.8)
		
		camera_tween.finished.connect(on_finished)
	else:
		current_state = CamState.IDLE
		tracking_bag = null

func reset_camera() -> void:
	Engine.time_scale = 1.0
	if camera_tween and camera_tween.is_valid():
		camera_tween.kill()
	if is_instance_valid(camera_ref) and current_state != CamState.IDLE:
		camera_ref.global_transform = original_cam_transform
		camera_ref.fov = original_cam_fov
	current_state = CamState.IDLE
	tracking_bag = null
	shake_intensity = 0.0
	shake_offset = Vector3.ZERO
	early_cinematic_triggered = false
	power_up = false


# Preserved Autoload Methods

func show_notification(label_node: Label, message: String, display_time: float = 2.0) -> void:
	if not is_instance_valid(label_node) or not label_node.is_inside_tree():
		return
	
	label_node.text = message
	label_node.modulate.a = 1.0
	label_node.show()
	
	pop_animation(label_node)
	
	await get_tree().create_timer(display_time + 0.5).timeout
	if not is_instance_valid(label_node) or not label_node.is_inside_tree():
		return
	
	var fade_tween := create_tween()
	fade_tween.tween_property(label_node, "modulate:a", 0.0, 0.35)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
	await fade_tween.finished
		
	if is_instance_valid(label_node):
		label_node.hide()


func show_fade_item(node: Control, delay: float) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	node.modulate.a = 0.0
	node.show()
	await get_tree().create_timer(delay).timeout
 
	var tween := create_tween()
	tween.tween_property(
		node,
		"modulate:a",
		1.0,
		0.35
	).set_trans(Tween.TRANS_SINE)\
	.set_ease(Tween.EASE_OUT)


func set_animation(nodes: Array[Node]) -> void:
	var val := 0.0
	var inc := 0.05
	for node in nodes:
		val += inc
		var ctrl := node as Control
		if ctrl:
			show_fade_item(ctrl, val)

func pop_animation(node: Control) -> void:
	node.scale = Vector2.ZERO
	node.pivot_offset = node.size / 2
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2(1.15, 1.15), 0.35)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, 0.15)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
