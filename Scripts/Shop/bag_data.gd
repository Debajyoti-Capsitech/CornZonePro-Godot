extends TextureRect
 
@onready var icon = $HBoxContainer/BagIcon
@onready var rarity_text = $HBoxContainer/Rarity
@onready var bag_button: Button = $BagBuyButton
@onready var price_text = $BagBuyButton/BagPrice
@onready var coin_icon = $BagBuyButton/TextureRect
# @onready var bag_name_text = $HBoxContainer/Name

const RARITY_NAMES = ["Standard", "Epic", "Rare", "Legendary"]
const MAX_SWIPE_DIST   = 50.0
const MAX_VERTICAL     = 4.0

const MAX_HORIZONTAL   = 1.5
const MAX_BAG_STRENGTH = 50.0
const PURCHASE_POPUP_SCENE = preload("res://Scenes/UI/purchase_popup.tscn")

@onready var clutch_spot_container = $HBoxContainer/TextureRect2/Powers/ClutchSpot/HBoxContainer
@onready var miss_clock_container = $HBoxContainer/TextureRect2/Powers/MissClock/HBoxContainer
@onready var air_control_container = $HBoxContainer/TextureRect2/Powers/AirControl/HBoxContainer
@onready var power_shot_container = $HBoxContainer/TextureRect2/Powers/PowerShot/HBoxContainer
@onready var buy_button: Button = $BagBuyButton

func setup(data: Dictionary, green: Texture2D, white: Texture2D) -> void:
	var item_id = data.get("itemId", "")
	data["bought"] = PlayerData.bags_owned.has(item_id)
	data["equipped"] = item_id == PlayerData.equipped_cornbag

	# Icon
	var icon_path: String = data.get("icon", "")
	if icon_path != "":
		var tex = load(icon_path)
		if tex:
			icon.texture = tex
			
	# #Name
	# var bag = data.get("bag_name","")
	# bag_name_text.text = bag

	# Price
	var price: int = data.get("price", 0)

	# Rarity
	var rarity_index: int = data.get("rarity", 0)
	rarity_text.text = RARITY_NAMES[clamp(rarity_index, 0, RARITY_NAMES.size() - 1)]
	if rarity_index == 0:
		$HBoxContainer.add_theme_constant_override("separation", 0)
		

	# Power bars
	update_signals(clutch_spot_container,  data.get("min_swipe_dist", 0.0),         MAX_SWIPE_DIST,   green, white)
	update_signals(miss_clock_container,   data.get("vertical_sensitivity", 0.0),   MAX_VERTICAL,     green, white)
	update_signals(air_control_container,  data.get("horizontal_sensitivity", 0.0), MAX_HORIZONTAL,   green, white)
	update_signals(power_shot_container,   data.get("max_bag_strength", 0.0),       MAX_BAG_STRENGTH, green, white)

	# Button state
	if data.get("bought", false):
		_set_button_label("Purchased")
		buy_button.disabled = true
	else:
		_set_button_label(str(price) + " Buy" if price > 0 else "FREE")
		buy_button.disabled = false
		buy_button.pressed.connect(_on_buy_pressed.bind(data))

func _set_button_label(label: String) -> void:
	price_text.text = label
	buy_button.text = ""
	coin_icon.visible = label.ends_with("Buy") or label == "FREE"

func _on_buy_pressed(data: Dictionary) -> void:
	var item_id = str(data.get("itemId", ""))
	if item_id == "":
		return
	var price: int = data.get("price", 0)
	if price > 0 and not await DataManager.spend_coins(price):
		#AnimateManager.show_notification($ShopScreen/Label, "Not enough coins", 1.5)
		AnimateManager.notify.emit()
		print("Nhi hai paise")
		return
	if not PlayerData.bags_owned.has(item_id):
		PlayerData.bags_owned.append(item_id)
	PlayerData.save_local()
	FirebaseManager.mark_dirty([FirebaseManager.SECTION_INVENTORY])
	get_parent().load_bag_data()
	
	# Show purchase confirmation popup
	var shop_screen = get_tree().current_scene.find_child("ShopScreen", true, false)
	if shop_screen:
		var popup = PURCHASE_POPUP_SCENE.instantiate()
		shop_screen.add_child(popup)
		popup.setup(data.get("icon", ""))
	
	# if PlayerData.needs_cloud_sync:
	# 	await FirebaseManager.push_to_firestore()
	

func update_signals(container: HBoxContainer, value: float, max_value: float, green: Texture2D, white: Texture2D):
	if not container: return
   
	var ratio = clamp(value / max_value, 0.0, 1.0)
	var green_count = int(ratio * 10)
   
	var signals = container.get_children()
	for i in range(signals.size()):
		if signals[i] is TextureRect:
			signals[i].texture = green if i < green_count else white
 

 
 
