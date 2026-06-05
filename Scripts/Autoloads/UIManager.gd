extends Node


#------Scenes----------------------------
const DEFAULT_MAP_SCENE_PATH := "res://Scenes/Maps/street.tscn"
const DEFAULT_MAP_CONFIG := preload("res://Resources/Maps/street.tres")

# signal home_comeing(value:int)


var canvas_layers: Array[CanvasLayer] = []
var loading_screen: CanvasLayer
var home_screen: CanvasLayer
var login_screen: CanvasLayer
var setting_screen: CanvasLayer
var map_select_screen: CanvasLayer
var profile_screen:CanvasLayer
var info_screen:CanvasLayer
var daily_rewards_screen:CanvasLayer
var reward_screen:CanvasLayer
var local_multiplayer_screen:CanvasLayer
var leaderboard_screen: CanvasLayer
var shop_screen: CanvasLayer
var inventory_screen: CanvasLayer

var ingame_screen:CanvasLayer
var pause_screen:CanvasLayer
var result_screen:CanvasLayer

var warning_screen:CanvasLayer
var rematch_popup:CanvasLayer
var login_loading_screen:CanvasLayer
var no_internet_screen:CanvasLayer

signal UI_required

var ad_showing := false
# func _ready() -> void:
# 	NetworkManager.game_ready.connect(local_multiplayer)



func _notification(what: int) -> void:
	if ad_showing:
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_set_home_coming_state(0)
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_set_home_coming_state(1)

func _set_home_coming_state(value: int) -> void:
	if Prefs.get_int("home_comeing", -1) == value:
		return

	Prefs.set_int("home_comeing", value)
	Prefs.save()

func home_setup(loading, home, login, setting, map, profile, info, rewards_list, reward, local_multilplayer, leaderboard, shop, inventory,login_loading,no_internet):
	loading_screen = loading
	home_screen = home
	login_screen = login
	setting_screen = setting
	map_select_screen = map
	profile_screen=profile
	info_screen=info
	daily_rewards_screen=rewards_list
	reward_screen=reward
	local_multiplayer_screen=local_multilplayer
	leaderboard_screen = leaderboard
	shop_screen = shop
	inventory_screen = inventory
	login_loading_screen = login_loading
	no_internet_screen = no_internet
	canvas_layers = [loading, home, login, setting, map, profile, info, rewards_list, reward, local_multilplayer, leaderboard, shop, inventory,login_loading,no_internet]

func single_setup(ingame, pause, result):
	#loading_screen = loading
	ingame_screen = ingame
	pause_screen = pause
	result_screen = result
	canvas_layers = [ingame, pause, result]
	
func multiplayer_setup(ingame, pause, result,warning,rematch):
	ingame_screen = ingame
	pause_screen = pause
	result_screen = result
	warning_screen=warning
	rematch_popup=rematch
	canvas_layers = [ingame, pause, result,warning,rematch]

func disable_all_canvaslayers():
	for item in canvas_layers:
		if is_instance_valid(item):
			item.visible = false

func enable_canvas(layer: CanvasLayer):
	disable_all_canvaslayers()
	layer.visible = true

func enable_canvas_with_transition(layer: CanvasLayer):
	await TransitionLayer.fade_out()
	disable_all_canvaslayers()
	layer.visible = true
	await TransitionLayer.fade_in()
	
func toggle_canvas(layer: CanvasLayer):
	layer.visible = !layer.visible

func toggle_canvas_with_transition(canvas: CanvasLayer) -> void:
	await TransitionLayer.fade_out()
	toggle_canvas(canvas)
	await TransitionLayer.fade_in()

func _begin_match(mode: String, map_path: String, ui: String, time_limit: float) -> void:
	GameSession.start_match(mode, map_path, ui, time_limit)
	SceneManager.preload_async(GameSession.selected_map_path)
	_goto_match()

func _start_match(mode: String) -> void:
	_begin_match(
		mode,
		DEFAULT_MAP_SCENE_PATH,
		mode,
		DEFAULT_MAP_CONFIG.time_limit
	)

func _goto_match()->void:
	await SceneManager.wait_until_loaded(GameSession.selected_map_path)
	SceneManager.goto(GameSession.selected_map_path)

func single_player()->void:
	GameSession.selected_mode="Single"
	GameSession.required_ui="Single"
	map_select_data()
	# toggle_canvas($MapSelectScreen)
	# _start_match("Single")

func vs_bot()->void:
	GameSession.selected_mode="VSBot"
	GameSession.required_ui="VSBot"
	map_select_data()

func map_select_data()->void:
	if is_instance_valid(map_select_screen) and map_select_screen.has_method("refresh_map_locks"):
		map_select_screen.refresh_map_locks()


func home() -> void:
	if GameSession.is_network_mode():
		NetworkManager.disconnect_game()

	_go_home_local()

	#var scene = load("res://Scenes/home.tscn") as PackedScene
	#get_tree().change_scene_to_packed(scene)
	#ResourceLoader.load_threaded_request("res://Scenes/home.tscn")
	#var status = ResourceLoader.load_threaded_get_status("res://Scenes/home.tscn")
	#if status == ResourceLoader.THREAD_LOAD_LOADED:
		#var new_scene = ResourceLoader.load_threaded_get("res://Scenes/home.tscn")
		#get_tree().change_scene_to_packed(new_scene)

@rpc("authority","reliable")
func _go_home_rpc():
	_go_home_local()

func _go_home_local():
	var interad := int(Prefs.get_int("interstitial_ad_count", 1))
	var should_show_interstitial := interad % 3 == 0
	Prefs.set_int("interstitial_ad_count", interad + 1)
	if should_show_interstitial and AdManager.is_interstitial_ready():
		AdManager.show_interstitial(Callable(self,"_finish_go_home"))
	else:
		_finish_go_home()
	
func _finish_go_home():
	Prefs.set_int("home_comeing",1)
	GameSession.reset_match()
	SceneManager.free_all()
	NetworkManager.rematch_in_progress = false
	SceneManager.goto("res://Scenes/home.tscn")
	

func restart(
	mode_override: String = "",
	map_path_override: String = "",
	ui_override: String = "",
	time_limit_override: float = -1.0
) -> void:
	UI_required.emit()

	var mode := mode_override if not mode_override.is_empty() else GameSession.selected_mode
	var map_path := (
		map_path_override
		if not map_path_override.is_empty()
		else GameSession.selected_map_path
	)
	var ui := ui_override if not ui_override.is_empty() else GameSession.required_ui
	var time_limit := (
		time_limit_override
		if time_limit_override >= 0.0
		else GameSession.time_left
	)

	if mode.is_empty() or map_path.is_empty():
		push_warning("[UIManager] No active match to restart")
		return

	# RESET GAME SESSION
	GameSession.reset_match()

	# DESTROY OLD SCENE
	SceneManager.free_all()

	# wait one frame so old RPC nodes die
	await get_tree().process_frame

	# START FRESH MATCH
	GameSession.start_match(mode, map_path, ui, time_limit)

	SceneManager.preload_async(map_path)

	await SceneManager.wait_until_loaded(map_path)

	SceneManager.goto(map_path)
	NetworkManager.rematch_in_progress = false

# func restart() -> void:
# 	UI_required.emit()

# 	if GameSession.selected_mode.is_empty() or GameSession.selected_map_path.is_empty():
# 		push_warning("[UIManager] No active match to restart")
# 		return

# 	var mode := GameSession.selected_mode
# 	var map_path := GameSession.selected_map_path
# 	var ui := GameSession.required_ui
# 	var time_limit := GameSession.time_left

# 	GameSession.reset_match()

# 	await get_tree().process_frame

# 	_begin_match(mode, map_path, ui, time_limit)


#func _notification(what: int) -> void:
	#match what:
		#NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			#_set_home_coming_state(0)
		#NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			#_set_home_coming_state(1)
 #
#func _set_home_coming_state(value: int) -> void:
	#if Prefs.get_int("home_comeing", -1) == value:
		#return
	#Prefs.set_int("home_comeing", value)
	#Prefs.save()

func pass_play()->void:
	GameSession.selected_mode="PassPlay"
	GameSession.required_ui="PassPlay"
	map_select_data()
	# _start_match("PassPlay")

func local_multiplayer()->void:
	pass
