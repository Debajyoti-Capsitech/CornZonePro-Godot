extends CanvasLayer
@onready var coin_text: Label = $Panel/TopPanel/Coin/CoinText
@onready var profile_icon = $"Panel/Profile/Profile Icon/TextureRect"
@onready var profile_name = $Panel/Profile/Label
@onready var profile_edit: Button = $"../ProfileScreen/Panel/ProfileBg/ProfilePic/EditButton"
 
@export var icons: Array[Texture2D]
 
func _ready() -> void:
	#AdManager.show_banner()
	#coin_text.text = str(Prefs.get_int("coins",0))
	profile_icon.texture = icons[Prefs.get_int("profile_index",0)]
	if not FirebaseManager.on_data_loaded.is_connected(_on_data_ready):
		FirebaseManager.on_data_loaded.connect(_on_data_ready)
	if FirebaseManager.data_loaded or PlayerData.has_loaded_data:
		await _on_data_ready()
	else:
		pass
		#rank_label.text = "Loading..."
#
	if not RemoteConfiguration.config_loaded.is_connected(_apply_config):
		RemoteConfiguration.config_loaded.connect(_apply_config)
	if RemoteConfiguration.is_loaded:
		_apply_config()
	#input_player_name.editable = false
	#is_editing = false
	#player_name_submit.pressed.connect(_on_edit_pressed);
	#input_player_name.text_submitted.connect(_on_name_submitted)
	PlayerData.detect_device_type()

func _on_setting_button_pressed() -> void:
	SoundManager.play_button_clicks()
	UIManager.toggle_canvas($"../SettingScreen")
	AnimateManager.pop_animation($"../SettingScreen/Panel")

func _on_timer_button_pressed() -> void:
	SoundManager.play_button_clicks()
	UIManager.single_player()
	UIManager.toggle_canvas($"../MapSelectScreen")

func _on_profile_icon_pressed() -> void:
	SoundManager.play_button_clicks()
	UIManager.toggle_canvas($"../ProfileScreen")
	AnimateManager.pop_animation($"../ProfileScreen/Panel")
	AnimateManager.set_animation([$"../ProfileScreen/Panel/ProfileBg/ProfilePic",
	$"../ProfileScreen/Panel/ProfileBg/UserNameBG",
	$"../ProfileScreen/Panel/ProfileBg/PlayerCard/GamePlaySection",
	$"../ProfileScreen/Panel/ProfileBg/PlayerCard/Achievement",
	$"../ProfileScreen/Panel/ProfileBg/PlayerCard/Total Pots"])

func _on_info_button_pressed() -> void:
	SoundManager.play_button_clicks()
	UIManager.toggle_canvas($"../InfoScreen")
	AnimateManager.pop_animation($"../InfoScreen/Panel")
	AnimateManager.set_animation([$"../InfoScreen/Panel/PanelBg/PanelText",
	$"../InfoScreen/Panel/PanelBg/ScrollContainer/VBoxContainer/Label1",
	$"../InfoScreen/Panel/PanelBg/ScrollContainer/VBoxContainer/Label2",
	$"../InfoScreen/Panel/PanelBg/ScrollContainer/VBoxContainer/Label3",
	$"../InfoScreen/Panel/PanelBg/ScrollContainer/VBoxContainer/Label4",
	$"../InfoScreen/Panel/PanelBg/ScrollContainer/VBoxContainer/Label5"])

func _on_daily_reward_button_pressed() -> void:
	SoundManager.play_button_clicks()
	UIManager.toggle_canvas($"../DailyRewardScreen")
	AnimateManager.set_animation([$"../DailyRewardScreen/Panel/GridContainer/Day1",
	$"../DailyRewardScreen/Panel/GridContainer/Day2",
	$"../DailyRewardScreen/Panel/GridContainer/Day3",
	$"../DailyRewardScreen/Panel/GridContainer/Day4",
	$"../DailyRewardScreen/Panel/GridContainer/Day5",
	$"../DailyRewardScreen/Panel/GridContainer/Day6",
	$"../DailyRewardScreen/Panel/Day7"])

func _on_pass_n_play_button_pressed() -> void:
	SoundManager.play_button_clicks()
	UIManager.pass_play()
	UIManager.toggle_canvas($"../MapSelectScreen")

func _on_lan_button_pressed() -> void:
	SoundManager.play_button_clicks()
	var multiplayer_screen := $"../MultiplayerScreen"
	UIManager.toggle_canvas(multiplayer_screen)
	AnimateManager.pop_animation($"../MultiplayerScreen/Panel")
	if multiplayer_screen.visible and multiplayer_screen.has_method("on_menu_opened"):
		multiplayer_screen.on_menu_opened()


func _on_leaderboard_button_pressed() -> void:
	SoundManager.play_button_clicks()
	UIManager.toggle_canvas($"../LeaderBoardScreen")
	AnimateManager.pop_animation($"../LeaderBoardScreen/Panel")

func _on_shop_button_pressed() -> void:
	SoundManager.play_button_clicks()
	UIManager.toggle_canvas_with_transition($"../ShopScreen")


func _on_inventory_button_pressed() -> void:
	SoundManager.play_button_clicks()
	var inventory_screen := $"../InventoryScreen"
	if inventory_screen.has_method("refresh_from_local"):
		inventory_screen.refresh_from_local()
	UIManager.toggle_canvas_with_transition(inventory_screen)
 
func _on_data_ready():
	_update_ui()
func _apply_config():
	var daily_bonus = RemoteConfiguration.config.get("daily_bonus",false)
	var halloween_event = RemoteConfiguration.config.get("halloween_event",false)
	if daily_bonus == true:
		pass
	else:
		pass
 
func _update_ui():
	profile_name.text = str(PlayerData.player_name)
	coin_text.text = str(PlayerData.coins)


func _on_bot_button_pressed() -> void:
	SoundManager.play_button_clicks()
	UIManager.vs_bot()
	UIManager.toggle_canvas($"../MapSelectScreen")


func _on_locked_icon_1_pressed() -> void:
	AnimateManager.show_notification($Notification, "New Features will coming soon", 1.5)


func _on_locked_icon_2_pressed() -> void:
	AnimateManager.show_notification($Notification, "New Features will coming soon", 1.5)
