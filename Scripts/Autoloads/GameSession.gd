extends Node

const UI_SCENES = {
	"Single": preload("res://Scenes/UI/single_player_ui.tscn"),
	"PassPlay": preload("res://Scenes/UI/pass_play_ui.tscn"),
	"Local": preload("res://Scenes/UI/local_multiplayer_ui.tscn"),
	"VSBot": preload("res://Scenes/UI/user_vs_bot_ui.tscn"),
	"Multiplayer": preload("res://Scenes/UI/user_vs_bot_ui.tscn")
}

const SingleMode = preload("res://Scripts/Modes/SingleMode.gd")
const PassPlayMode = preload("res://Scripts/Modes/PassPlayMode.gd")
const LocalMode = preload("res://Scripts/Modes/LocalMode.gd")
const VSBotMode = preload("res://Scripts/Modes/VSBotMode.gd")
const MultiplayerMode = preload("res://Scripts/Modes/VSBotMode.gd")

signal pots_update
signal match_played
signal projectile_preview_changed(active: bool)
signal turns_exhausted
signal activate_wind
signal turn_changed(player: int)
signal bag_result_recorded(player: int, points: int)
signal bag_result_changed(player: int, index: int, points: int)

var game_paused:bool

var bags_thrown_this_turn: int = 0
var match_over: bool = false

var mode_logic: Node = null
var selected_map_path: String = ""
var selected_mode: String = ""
var required_ui: String = ""
var player_count: int = 1
var current_turn: int = 1
var score_p1: int = 0
var score_p2: int = 0
var bot_name: String = "Bot"
var bot_difficulty: String = "MEDIUM BOT"
var time_left: float = 20.0
var projectile_preview_until_msec: int = 0
var p1_bag_results: Array = []
var p2_bag_results: Array = []

func wind_control(value:int)->void:
	if 1== value:
		activate_wind.emit()
		print("chala ")


func is_network_mode() -> bool:
	return selected_mode == "Local" or selected_mode == "Multiplayer"


func start_match(mode: String, map_path: String, ui: String, time_limit: float) -> void:
	selected_mode = mode
	selected_map_path = map_path
	required_ui = ui
	time_left = time_limit

	match mode:
		"Single":
			player_count = 1
		"PassPlay", "Local", "VSBot", "Multiplayer":
			player_count = 2

	current_turn = 1
	score_p1 = 0
	score_p2 = 0
	bags_thrown_this_turn = 0
	match_over = false
	p1_bag_results.clear()
	p2_bag_results.clear()

	DataManager.match_played()
	match_played.emit()
	_set_mode_logic()


func _set_mode_logic() -> void:
	if mode_logic:
		if mode_logic.get_parent() == self:
			remove_child(mode_logic)
		mode_logic.queue_free()
		mode_logic = null

	match selected_mode:
		"Single":
			mode_logic = SingleMode.new()
		"PassPlay":
			mode_logic = PassPlayMode.new()
		"Local", "Multiplayer":
			mode_logic = LocalMode.new()
		"VSBot":
			mode_logic = VSBotMode.new()

	if mode_logic:
		mode_logic.name = "ModeLogic"
		add_child(mode_logic)


func get_ui_scene() -> PackedScene:
	if UI_SCENES.has(required_ui):
		return UI_SCENES[required_ui]
	if UI_SCENES.has(selected_mode):
		return UI_SCENES[selected_mode]
	return null


func add_score(player: int, amount: int) -> void:
	if player == 1:
		score_p1 += amount
	elif player == 2:
		score_p2 += amount


func activate_projectile_preview(duration_sec: float) -> void:
	projectile_preview_until_msec = Time.get_ticks_msec() + int(duration_sec * 1000.0)
	projectile_preview_changed.emit(true)


func is_projectile_preview_active() -> bool:
	return Time.get_ticks_msec() < projectile_preview_until_msec


func clear_projectile_preview() -> void:
	projectile_preview_until_msec = 0
	projectile_preview_changed.emit(false)


func next_turn() -> void:
	if player_count <= 1:
		return

	current_turn += 1
	if current_turn > player_count:
		current_turn = 1


func reset_match() -> void:
	if mode_logic:
		mode_logic.on_match_end()
		if mode_logic.get_parent() == self:
			remove_child(mode_logic)
		mode_logic.queue_free()

	mode_logic = null
	selected_mode = ""
	selected_map_path = ""
	required_ui = ""
	player_count = 1
	current_turn = 1
	score_p1 = 0
	score_p2 = 0
	bot_name = "Bot"
	bags_thrown_this_turn = 0
	match_over = false
	p1_bag_results.clear()
	p2_bag_results.clear()
	clear_projectile_preview()
	#var interad := int(Prefs.get_int("interstitial_ad_count", 1))
	#var should_show_interstitial := interad % 3 == 0
	#Prefs.set_int("interstitial_ad_count", interad + 1)
#
	## Avoid showing ads in the middle of scene teardown.
	#if should_show_interstitial and is_instance_valid(AdManager) and AdManager.is_inside_tree() and AdManager.is_interstitial_ready():
		#AdManager.show_interstitial()

func on_bag_thrown() -> void:
	bags_thrown_this_turn += 1
	if mode_logic and mode_logic.has_method("on_bag_thrown"):
		mode_logic.on_bag_thrown()


func record_bag_result(player: int, points: int) -> int:
	var index: int = 0
	if player == 1:
		p1_bag_results.append(points)
		index = p1_bag_results.size() - 1
	else:
		p2_bag_results.append(points)
		index = p2_bag_results.size() - 1

	bag_result_recorded.emit(player, points)
	bag_result_changed.emit(player, index, points)
	return index


func update_bag_result(player: int, index: int, points: int) -> void:
	if player == 1:
		if index < 0 or index >= p1_bag_results.size():
			return
		if p1_bag_results[index] == points:
			return
		p1_bag_results[index] = points
	else:
		if index < 0 or index >= p2_bag_results.size():
			return
		if p2_bag_results[index] == points:
			return
		p2_bag_results[index] = points

	bag_result_changed.emit(player, index, points)


func end_match() -> void:
	match_over = true
