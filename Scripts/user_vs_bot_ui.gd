extends Node

@onready var game_mode_selection_ui: CanvasLayer = $GameModeSelectionUI
@onready var multiplayer_ui: CanvasLayer = $MultiplayerUI
@onready var waiting_for_players_ui: CanvasLayer = $WaitingForPlayersUI
@onready var in_game_ui: CanvasLayer = $"InGame UI"
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var game_over: CanvasLayer = $GameOver

func _ready() -> void:
	UIManager.single_setup(
		in_game_ui,
		pause_menu,
		game_over
	)
	
	# Show the game mode selection UI at start
	in_game_ui.visible = false
	pause_menu.visible = false
	game_over.visible = false
	multiplayer_ui.visible = false
	waiting_for_players_ui.visible = false
	
	if GameSession.selected_mode == "Multiplayer":
		game_mode_selection_ui.visible = false
		in_game_ui.visible = true
		in_game_ui.start_vs_bot_match()
	else:
		game_mode_selection_ui.visible = true

func start_bot_mode() -> void:
	game_mode_selection_ui.visible = false
	in_game_ui.visible = true
	in_game_ui.start_vs_bot_match()

func show_multiplayer_ui() -> void:
	game_mode_selection_ui.visible = false
	multiplayer_ui.visible = true

func show_mode_selection_ui() -> void:
	multiplayer_ui.visible = false
	game_mode_selection_ui.visible = true

func show_waiting_screen(code: String) -> void:
	multiplayer_ui.visible = false
	waiting_for_players_ui.visible = true
	waiting_for_players_ui.setup_lobby(code)

func hide_waiting_screen() -> void:
	waiting_for_players_ui.visible = false
	multiplayer_ui.visible = true

