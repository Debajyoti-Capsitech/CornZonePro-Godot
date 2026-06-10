extends StaticBody3D

const AWARDED_POINTS_META := "awarded_points"
const TOUCHED_BOARD_META := "touched_board"
 
@onready var board_visual: GeometryInstance3D = $throwingStand_grp/stand_geo
@onready var board_visual_sec: GeometryInstance3D = $throwingStand_grp/planring_geo_002
 
# Board.gd or Game.gd
func _ready() -> void:
	UIManager.UI_required.connect(load_ui)
	_apply_board_visual()
	load_ui()
 
 
func _apply_board_visual() -> void:
	if board_visual == null:
		return
 
	var board_config = NetworkManager.get_match_board_config()
	var board_material = board_config.material_override
	#print("Board material  is ", board_material)
	
	
	
	if board_material != null:
		board_visual.material_override = board_material
		board_visual_sec.material_override = board_material
 
func load_ui() -> void:
	var existing_ui: Node = get_node_or_null("MatchUI")
	if existing_ui:
		existing_ui.queue_free()

	print("Mode is: '", GameSession.selected_mode, "'")
	print("Available keys: ", GameSession.UI_SCENES.keys())
	var ui_scene: PackedScene = GameSession.get_ui_scene()
	if ui_scene == null:
		push_error("[Board] No UI scene configured for mode '%s' (required_ui='%s')" % [
			GameSession.selected_mode,
			GameSession.required_ui
		])
		return
	var ui_instance: Node = ui_scene.instantiate()
	ui_instance.name = "MatchUI"
	add_child(ui_instance)

func on_bag_landed(body: Node3D) -> void:
	if not (body is RigidBody3D):
		return

	if GameSession.selected_mode == "Local" or GameSession.selected_mode == "Multiplayer":
		if not multiplayer or multiplayer.multiplayer_peer == null or not multiplayer.is_server():
			return

	body.set_meta(TOUCHED_BOARD_META, true)

	var awarded_points: int = int(body.get_meta(AWARDED_POINTS_META, 0))
	if awarded_points >= 1:
		return

	var scoring_player: int = int(body.get_meta("throw_player", GameSession.current_turn))
	body.set_meta(AWARDED_POINTS_META, 1)
	GameSession.add_score(scoring_player, 1)

	var uses_bag_result_slots: bool = GameSession.selected_mode == "PassPlay" or GameSession.selected_mode == "Local" or GameSession.selected_mode == "Multiplayer"
	if uses_bag_result_slots and body.has_meta("bag_result_index"):
		GameSession.update_bag_result(scoring_player, int(body.get_meta("bag_result_index")), 1)

	GameSession.pots_update.emit()

	if (GameSession.selected_mode == "Local" or GameSession.selected_mode == "Multiplayer") and GameSession.mode_logic and GameSession.mode_logic.has_method("sync_match_state"):
		GameSession.mode_logic.sync_match_state()
