extends Control

@onready var overlay: ColorRect = $Overlay
@onready var glow: TextureRect = $Glow
@onready var bag_icon: TextureRect = $BagIcon
@onready var ok_button: Button = $OkButton

var is_closing: bool = false

func _ready() -> void:
	# Ensure correct pivot offsets for scaling/rotation
	glow.pivot_offset = glow.size / 2
	bag_icon.pivot_offset = bag_icon.size / 2
	ok_button.pivot_offset = ok_button.size / 2
	
	# Initial entry animations
	overlay.color.a = 0.0
	var overlay_tween = create_tween()
	overlay_tween.tween_property(overlay, "color:a", 0.65, 0.3)
	
	AnimateManager.pop_animation(bag_icon)
	AnimateManager.pop_animation(ok_button)
	
	ok_button.pressed.connect(_on_ok_pressed)
	
	# Looping C++ tween for rotation to avoid GDScript _process overhead
	var rotate_tween = create_tween().set_loops()
	rotate_tween.tween_property(glow, "rotation", 2.0 * PI, 8.0).as_relative()

func setup(icon_path: String) -> void:
	if icon_path != "":
		var tex = load(icon_path)
		if tex:
			$BagIcon.texture = tex

func _on_ok_pressed() -> void:
	if is_closing:
		return
	is_closing = true
	
	SoundManager.play_button_clicks()
	
	# Exit animation
	var exit_tween = create_tween().set_parallel(true)
	exit_tween.tween_property(overlay, "color:a", 0.0, 0.2)
	exit_tween.tween_property(bag_icon, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	exit_tween.tween_property(ok_button, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	exit_tween.tween_property(glow, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	await exit_tween.finished
	queue_free()
