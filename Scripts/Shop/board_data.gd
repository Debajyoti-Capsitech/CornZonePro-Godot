extends TextureRect

@onready var icon = $HBoxContainer/BoardIcon
@onready var rarity_text = $HBoxContainer/VBoxContainer/Rarity
@onready var price_text = $HBoxContainer/VBoxContainer/BagBuyButton/BoardPrice
@onready var coin_icon = $HBoxContainer/VBoxContainer/BagBuyButton/TextureRect
@onready var buy_button = $HBoxContainer/VBoxContainer/BagBuyButton

const RARITY_NAMES = ["Standard", "Rare", "Epic", "Legendary"]
const PURCHASE_POPUP_SCENE = preload("res://Scenes/UI/purchase_popup.tscn")



func setup(data: Dictionary, green: Texture2D, white: Texture2D) -> void:
	var item_id = data.get("itemId", "")
	data["bought"] = PlayerData.boards_owned.has(item_id)
	data["equipped"] = item_id == PlayerData.equipped_board

	# Icon
	var icon_path: String = data.get("icon", "")
	if icon_path != "":
		var tex = load(icon_path)
		if tex:
			icon.texture = tex
			

	# Price
	var price: int = data.get("price", 0)

	# Rarity
	var rarity_index: int = data.get("rarity", 0)
	rarity_text.text = RARITY_NAMES[clamp(rarity_index, 0, RARITY_NAMES.size() - 1)]
	if rarity_index == 0:
		$HBoxContainer.add_theme_constant_override("separation", 0)
		
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
	if price > 0 and not await  DataManager.spend_coins(price):
		AnimateManager.notify.emit()
		return
	if not PlayerData.boards_owned.has(item_id):
		PlayerData.boards_owned.append(item_id)
	PlayerData.save_local()
	FirebaseManager.mark_dirty([FirebaseManager.SECTION_INVENTORY])
	get_parent().load_board_data()
	
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
