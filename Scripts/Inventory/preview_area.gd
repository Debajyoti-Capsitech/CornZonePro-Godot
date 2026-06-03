extends Control

@onready var pivot = $InspectTexture/SubViewportContainer/SubViewport/ModelPivot
#@onready var model: GeometryInstance3D = $InspectTexture/SubViewportContainer/SubViewport/ModelPivot/Bag

@export var model: GeometryInstance3D

@export var rotation_speed := 0.5
@export var return_speed := 5.0
@export var max_vertical_angle := 180.0

var dragging := false

# Premium UI Effects variables
var default_scale: Vector3 = Vector3.ONE
var glow_bg: TextureRect
var sparkles: CPUParticles2D
var elapsed_time := 0.0
var active_tween: Tween

func _ready() -> void:
	# Cache default scale of the model
	if model:
		default_scale = model.scale
	
	# 1. Setup rotating glow background behind the 3D model viewport
	glow_bg = TextureRect.new()
	glow_bg.name = "GlowBackground"
	glow_bg.texture = load("res://gloweffect.png")
	glow_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glow_bg.layout_mode = 1
	glow_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow_bg.modulate = Color(1.0, 0.95, 0.7, 0.05) # Subtle golden tint, base opacity 0.05
	
	# Add and place it behind the model inspect texture
	add_child(glow_bg)
	move_child(glow_bg, 0)
	
	# Connect resized signal to ensure correct rotation pivot
	glow_bg.resized.connect(func(): glow_bg.pivot_offset = glow_bg.size / 2)
	glow_bg.pivot_offset = glow_bg.size / 2
	
	# Create continuous slow rotation for the glow background
	var rotate_tween = create_tween().set_loops()
	rotate_tween.tween_property(glow_bg, "rotation", 2.0 * PI, 15.0).as_relative()
	
	# 2. Setup sparkle particles (burst on bag select)
	sparkles = CPUParticles2D.new()
	sparkles.name = "SparkleParticles"
	sparkles.emitting = false
	sparkles.one_shot = true
	sparkles.explosiveness = 0.85
	sparkles.amount = 25
	sparkles.lifetime = 0.7
	sparkles.spread = 180.0 # Creates full 360 emission circle
	sparkles.gravity = Vector2.ZERO # Float outwards
	sparkles.initial_velocity_min = 70.0
	sparkles.initial_velocity_max = 150.0
	sparkles.damping_min = 40.0
	sparkles.damping_max = 60.0
	sparkles.scale_amount_min = 4.0
	sparkles.scale_amount_max = 7.0
	
	# Shrink particles to zero as they fade
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(0.7, 0.8))
	scale_curve.add_point(Vector2(1.0, 0.0))
	sparkles.scale_amount_curve = scale_curve
	
	# Soft golden to transparent white fade
	var grad = Gradient.new()
	grad.set_color(0, Color(1.0, 0.98, 0.85, 1.0)) # Bright golden-white core
	grad.set_color(1, Color(1.0, 0.75, 0.25, 0.0))  # Fade to amber transparent
	sparkles.color_ramp = grad
	
	# Center particles on the preview area
	sparkles.position = size / 2
	resized.connect(func(): sparkles.position = size / 2)
	
	# Render sparkles in front of InspectTexture for integrated juicy overlay
	add_child(sparkles)

func set_item_material(material):
	# Stop active selection tweens
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		
	# Apply new bag material
	model.material_override = load(material)
	model.position = Vector3.ZERO
	
	# Prepare for pop and spin-in animation
	model.scale = Vector3.ZERO
	pivot.rotation.x = 0.0
	pivot.rotation.z = 0.0
	pivot.rotation.y = deg_to_rad(-180.0) # Start rotated 180 degrees back
	
	# Trigger sparkle particles burst
	if sparkles:
		sparkles.restart()
		sparkles.emitting = true
		
	# Create animation tween
	active_tween = create_tween().set_parallel(true)
	
	# Spring/pop-up scale animation
	active_tween.tween_property(model, "scale", default_scale, 0.65)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
		
	# Fast spin-in animation
	active_tween.tween_property(pivot, "rotation:y", 0.0, 0.55)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
		
	# Premium glow flash
	if glow_bg:
		glow_bg.scale = Vector2(0.5, 0.5)
		glow_bg.modulate.a = 0.5 # High opacity flash
		active_tween.tween_property(glow_bg, "scale", Vector2.ONE, 0.5)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)
		active_tween.tween_property(glow_bg, "modulate:a", 0.15, 0.7)\
			.set_delay(0.15) # Slowly settle back to base idle glow of 0.15

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed

	if event is InputEventMouseMotion and dragging:
		_apply_rotation(event.relative)

	if event is InputEventScreenTouch:
		dragging = event.pressed

	if event is InputEventScreenDrag and dragging:
		_apply_rotation(event.relative)

func _notification(what):
	if what == NOTIFICATION_MOUSE_EXIT:
		dragging = false

func _apply_rotation(relative_movement: Vector2):
	pivot.rotate_y(deg_to_rad(relative_movement.x * rotation_speed))
	pivot.rotate_object_local(Vector3.RIGHT, deg_to_rad(relative_movement.y * rotation_speed))
	
	var current_rotation = pivot.rotation
	var max_rad = deg_to_rad(max_vertical_angle)
	current_rotation.x = clamp(current_rotation.x, -max_rad, max_rad)
	pivot.rotation = current_rotation

func _process(delta):
	elapsed_time += delta
	# Prevent precision overflow on extremely long sessions
	if elapsed_time > 10000.0:
		elapsed_time -= 10000.0
		
	if not dragging:
		# Return vertical angles to 0
		pivot.rotation.x = lerp_angle(pivot.rotation.x, 0.0, delta * return_speed)
		pivot.rotation.z = lerp_angle(pivot.rotation.z, 0.0, delta * return_speed)
		
		# Slowly spin around Y axis continuously in idle state
		# lerp_angle handles transition from dragging back to idle spin smoothly
		pivot.rotation.y = lerp_angle(pivot.rotation.y, elapsed_time * 0.35, delta * (return_speed * 0.4))
		
		# Elegant idle floating/bobbing up and down
		model.position.y = sin(elapsed_time * 1.6) * 0.015
		
		# Transition glow modulate back to normal idle opacity
		if glow_bg:
			glow_bg.modulate.a = lerp(glow_bg.modulate.a, 0.15, delta * 2.0)
	else:
		# If user is dragging/interacting, dim the background glow slightly so they focus on the model
		if glow_bg:
			glow_bg.modulate.a = lerp(glow_bg.modulate.a, 0.05, delta * 3.0)

