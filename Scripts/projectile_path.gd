extends Node3D

@onready var bag := get_parent() as RigidBody3D
@onready var swipe_controller := $"../SwipeInputController" as SwipeInputController

var path_mesh := ImmediateMesh.new()
var path_mesh_instance := MeshInstance3D.new()
var path_material := StandardMaterial3D.new()

var endpoint_marker := MeshInstance3D.new()
var endpoint_mesh := CylinderMesh.new()
var endpoint_material := StandardMaterial3D.new()

const POINT_COUNT := 60
const TIME_STEP := 0.0166667
const PATH_WIDTH := 0.1
const ENDPOINT_RADIUS := 0.35
const ENDPOINT_HEIGHT := 0.02

func _ready() -> void:
	path_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	path_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	path_material.albedo_color = Color(0.18, 0.95, 0.35, 0.85)
	path_material.emission_enabled = true
	path_material.emission = Color(0.18, 0.95, 0.35, 1.0)
	path_material.no_depth_test = true
	path_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	path_mesh_instance.mesh = path_mesh
	path_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	path_mesh_instance.material_override = path_material
	add_child(path_mesh_instance)

	endpoint_mesh.top_radius = ENDPOINT_RADIUS
	endpoint_mesh.bottom_radius = ENDPOINT_RADIUS
	endpoint_mesh.height = ENDPOINT_HEIGHT
	endpoint_mesh.radial_segments = 24

	endpoint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	endpoint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	endpoint_material.albedo_color = Color(0.95, 0.95, 0.95, 0.75)
	endpoint_material.emission_enabled = true
	endpoint_material.emission = Color(0.18, 0.95, 0.35, 0.7)
	endpoint_material.no_depth_test = true

	endpoint_marker.mesh = endpoint_mesh
	endpoint_marker.material_override = endpoint_material
	endpoint_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	endpoint_marker.visible = false
	add_child(endpoint_marker)

	if swipe_controller:
		swipe_controller.swipe_updated.connect(_on_swipe_updated)
		swipe_controller.swipe_completed.connect(_on_swipe_completed)
	GameSession.projectile_preview_changed.connect(_on_projectile_preview_changed)



func _on_swipe_updated(direction: Vector3, strength: float) -> void:
	if bag == null:
		return
	var bag_thrown: Variant = bag.get("thrown")
	if bag_thrown is bool and bag_thrown:
		clear_path()
		return
	if not GameSession.is_projectile_preview_active():
		clear_path()
		return
	show_projectile_path(direction, strength)

func _on_swipe_completed(_direction: Vector3, _strength: float) -> void:
	clear_path()

func _on_projectile_preview_changed(active: bool) -> void:
	if not active:
		clear_path()

func show_projectile_path(direction: Vector3, strength: float) -> void:
	if bag == null:
		return

	clear_path()

	var velocity: Vector3 = direction * strength / bag.mass
	var pos: Vector3 = bag.global_position
	var launch_gravity_scale: Variant = bag.get("throw_gravity_scale")
	if launch_gravity_scale is int or launch_gravity_scale is float:
		launch_gravity_scale = float(launch_gravity_scale)
	else:
		launch_gravity_scale = bag.gravity_scale

	var default_gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) as float
	var default_gravity_vector: Vector3 = ProjectSettings.get_setting(
		"physics/3d/default_gravity_vector",
		Vector3.DOWN
	) as Vector3
	var gravity: Vector3 = default_gravity_vector * default_gravity * float(launch_gravity_scale)
	var linear_damp: float = bag.linear_damp
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	var world_points: Array[Vector3] = [pos]
	var hit_position := Vector3.ZERO
	var hit_normal := Vector3.UP
	var has_hit := false

	for _i in range(POINT_COUNT):
		var next_velocity: Vector3 = velocity + gravity * TIME_STEP
		if linear_damp > 0.0:
			next_velocity /= 1.0 + (linear_damp * TIME_STEP)

		var next_pos: Vector3 = pos + next_velocity * TIME_STEP
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(pos, next_pos)
		query.exclude = [bag.get_rid()]
		var hit: Dictionary = space_state.intersect_ray(query)
		if not hit.is_empty():
			hit_position = hit.position
			hit_normal = hit.normal
			has_hit = true
			world_points.append(hit_position)
			break

		world_points.append(next_pos)
		pos = next_pos
		velocity = next_velocity

	_draw_path(world_points)

	if has_hit:
		_show_endpoint_marker(hit_position, hit_normal)

func _draw_path(world_points: Array[Vector3]) -> void:
	if world_points.size() < 2:
		return

	var camera: Camera3D = get_viewport().get_camera_3d()
	path_mesh.clear_surfaces()
	path_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, path_material)

	for i in range(world_points.size()):
		var point: Vector3 = world_points[i]
		var prev_point: Vector3 = world_points[max(i - 1, 0)]
		var next_point: Vector3 = world_points[min(i + 1, world_points.size() - 1)]
		var tangent: Vector3 = (next_point - prev_point).normalized()
		if tangent.is_zero_approx():
			tangent = Vector3.FORWARD

		var view_dir: Vector3 = Vector3.UP
		if camera:
			view_dir = (camera.global_position - point).normalized()

		var side: Vector3 = tangent.cross(view_dir).normalized()
		if side.is_zero_approx():
			side = tangent.cross(Vector3.UP).normalized()
		if side.is_zero_approx():
			side = tangent.cross(Vector3.RIGHT).normalized()

		var half_width: Vector3 = side * (PATH_WIDTH * 0.5)
		path_mesh.surface_add_vertex(to_local(point - half_width))
		path_mesh.surface_add_vertex(to_local(point + half_width))

	path_mesh.surface_end()

func _show_endpoint_marker(world_position: Vector3, world_normal: Vector3) -> void:
	var normal: Vector3 = world_normal.normalized()
	if normal.is_zero_approx():
		normal = Vector3.UP

	var helper: Vector3 = Vector3.UP if abs(normal.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var tangent: Vector3 = helper.cross(normal).normalized()
	var bitangent: Vector3 = normal.cross(tangent).normalized()

	endpoint_marker.global_basis = Basis(tangent, normal, bitangent)
	endpoint_marker.global_position = world_position + normal * 0.01
	endpoint_marker.visible = true

func clear_path() -> void:
	path_mesh.clear_surfaces()
	endpoint_marker.visible = false
