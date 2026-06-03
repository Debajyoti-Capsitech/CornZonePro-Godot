extends Node

signal coins_changed
signal reward_checker

func _ready():
	if not FirebaseManager.on_data_loaded.is_connected(get_coins):
		FirebaseManager.on_data_loaded.connect(get_coins)
 
	if FirebaseManager.data_loaded or PlayerData.has_loaded_data:
		await get_coins()
	else:
		pass

func add_coins(earned_coins: int) -> void:
	var current_coins: int = PlayerData.coins
	current_coins += earned_coins
	PlayerData.coins = current_coins
	PlayerData.save_local()
	FirebaseManager.mark_dirty([
		FirebaseManager.SECTION_STATS
	])  # queues sync
	coins_changed.emit()
	print(" Total: ", current_coins)

func get_coins()->int:
	return 999999

func spend_coins(amount:int)->bool:
	var current: int = get_coins()
	if current<amount:
		#AnimateManager.show_notification($ShopScreen/Label, "Not enough coins")
		print("Not enough coins")
		return false
	PlayerData.coins = current - amount
	PlayerData.save_local()
	FirebaseManager.mark_dirty([
		FirebaseManager.SECTION_STATS
	])  # queues sync
	# Prefs.set_int("coins",current-amount)
	print("Spent: ", amount, " | Remaining: ", get_coins())
	coins_changed.emit()
	# if PlayerData.needs_cloud_sync:
	# 	await FirebaseManager.push_to_firestore()
	return true
	

func match_played()->void:
	var matches:int=PlayerData.matches_played
	matches += 1
	PlayerData.matches_played = matches
	PlayerData.save_local()
	FirebaseManager.mark_dirty([
		FirebaseManager.SECTION_STATS
	])  # queues sync
	# Prefs.set_int("matches_played",matches)
	# Prefs.save()
	

# Daily Reward Tracking

func get_current_day() -> int:
	return Prefs.get_int("reward_day", 1)
	# if PlayerData.reward_day == null or PlayerData.reward_day <=0:
	# 	PlayerData.reward_day = 1
	# 	PlayerData.save_local()
	# 	return 1
	# return PlayerData.reward_day

func get_last_claim_time() -> float:
	return Prefs.get_float("last_claim_time", 0.0)
	# print("the new last time is " , float(PlayerData.last_claim_time))
	# return float(PlayerData.last_claim_time)
	
func can_claim() -> bool:
	var current_time = float(Time.get_unix_time_from_system())
	var seconds_passed = float(current_time - get_last_claim_time())
	return seconds_passed >= 86400.0 or get_last_claim_time() == 0

func check_streak_status():
	print("check status is called")
	var last_time_claim = get_last_claim_time()
	# print("last time " , last_time_claim)
	if last_time_claim == 0: 
		return
	
	var current_time = Time.get_unix_time_from_system()
	var seconds_passed = current_time - last_time_claim
	print("total secpnd is " , seconds_passed)
	
	if seconds_passed >= 172800:
		PlayerData.reward_day = 1
		PlayerData.save_local()
		# Prefs.set_int("reward_day", 1)
		# Prefs.save()
		print("Streak broken, Reset to day 1")
	
func save_claim_success():
	PlayerData.last_claim_time = Time.get_unix_time_from_system()
	Prefs.set_float("last_claim_time", Time.get_unix_time_from_system())
	Prefs.save()
	print("the last time reward claimed is :" , Time.get_unix_time_from_system())
	# Prefs.set_float("last_claim_time", Time.get_unix_time_from_system())
	var next_day = get_current_day() + 1
	if next_day > 7: next_day = 1
	# PlayerData.reward_day = next_day
	# PlayerData.save_local()
	# reward_checker.emit()
	Prefs.set_int("reward_day", next_day)
	
	Prefs.save()


# func rewardchecker():
# 	check_streak_status()
# 	var can_claim_reward:bool = can_claim()
# 	if can_claim_reward == true:
# 		reward_checker.emit()
# 	else:
# 		return
