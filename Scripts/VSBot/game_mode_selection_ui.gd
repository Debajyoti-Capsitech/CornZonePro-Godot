extends CanvasLayer

func _ready() -> void:
	# Find select buttons and back button to connect pressed signals
	var vs_bot_btn = get_node_or_null("Control/VBoxContainer/VSBotCard/MarginContainer/HBoxContainer/RightSection/SelectButton")
	if vs_bot_btn:
		vs_bot_btn.pressed.connect(_on_vs_bot_pressed)
		
	var multiplayer_btn = get_node_or_null("Control/VBoxContainer/MultiplayerCard/MarginContainer/HBoxContainer/RightSection/SelectButton")
	if multiplayer_btn:
		multiplayer_btn.pressed.connect(_on_multiplayer_pressed)
		
	var back_btn = get_node_or_null("Control/BackButton")
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)

func _on_vs_bot_pressed() -> void:
	SoundManager.play_button_clicks()
	if get_parent().has_method("start_bot_mode"):
		get_parent().start_bot_mode()

func _on_multiplayer_pressed() -> void:
	SoundManager.play_button_clicks()
	if get_parent().has_method("show_multiplayer_ui"):
		get_parent().show_multiplayer_ui()

func _on_back_pressed() -> void:
	SoundManager.play_button_clicks()
	UIManager.home()
