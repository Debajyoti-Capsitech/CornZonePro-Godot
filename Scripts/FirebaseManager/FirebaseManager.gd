extends Node

signal on_data_loaded # fired when all collections finish loading
signal on_load_failed # fired if cloud load fails entirely

var player_id: String = ""
var is_data_dirty: bool = false
var current_login_method: String = ""
var create_defaults_for_missing_docs: bool = false
var is_offline_mode: bool = false
var _update_session_timer := 0.0

var _players_col
var _stats_col
var _inventory_col
var _misc_col
var _session_col
var usernames_col

var _loaded_count: int = 0
var _cloud_loaded_any_data: bool = false
var data_loaded: bool = false
const COLLECTIONS_TO_LOAD = 3 # profile + stats + inventory 
const USE_LOCAL_CACHE_FIRST: bool = true
const SECTION_PROFILE = "profile"
const SECTION_STATS = "stats"
const SECTION_INVENTORY = "inventory"
const SECTION_MISC = "misc"
const SECTION_LEADERBOARD = "leaderboard"
var _session_check_timer := 0.0
const SESSION_CHECK_INTERVAL := 120.0
const SESSION_UPDATE_INTERVAL := 30.0
var _session_check_in_progress: bool = false
var _session_update_in_progress: bool = false

var _sync_pending: bool = false
var _sync_timer: float = 0.0
const SYNC_DELAY: float = 5.0 # seconds to wait before syncing
const INTERNET_CHECK_URL: String = "https://www.gstatic.com/generate_204"
const FIREBASE_IO_LOGGING: bool = true
var firebase_read_count: int = 0
var firebase_write_count: int = 0

# Auto-sync on internet connection
var _last_internet_status: bool = false
var _internet_check_timer: float = 0.0
var _internet_check_in_progress: bool = false
var _dirty_sections: Dictionary = {}
const INTERNET_CHECK_INTERVAL: float = 4.0 # Check periodically; writes also verify before syncing.
var _load_all_in_progress: bool = false


func print_firebase_read(collection_path: String, doc_id: String, data: Dictionary = {}, found: bool = true):
	firebase_read_count += 1
	if not FIREBASE_IO_LOGGING:
		return
	if found:
		print("[Firebase READ] %s -> %s" % [_firebase_doc_path(collection_path, doc_id), _format_firebase_payload(data)])
	else:
		print("[Firebase READ] %s -> <empty>" % _firebase_doc_path(collection_path, doc_id))
	print_firebase_totals()

func print_firebase_write(collection_path: String, doc_id: String, data: Dictionary = {}):
	firebase_write_count += 1
	if not FIREBASE_IO_LOGGING:
		return
	print("[Firebase WRITE] %s <- %s" % [_firebase_doc_path(collection_path, doc_id), _format_firebase_payload(data)])
	print_firebase_totals()

func print_firebase_query(collection_path: String, data: Array = []):
	firebase_read_count += data.size()
	if not FIREBASE_IO_LOGGING:
		return
	print("[Firebase QUERY READ] %s -> %d document(s)" % [collection_path, data.size()])
	for i in range(data.size()):
		print("  [%d] %s" % [i + 1, _format_firebase_payload(data[i])])
	print_firebase_totals()

func print_firebase_totals():
	if not FIREBASE_IO_LOGGING:
		return
	print("[Firebase TOTAL] Reads: %d | Writes: %d" % [firebase_read_count, firebase_write_count])

func reset_firebase_totals():
	firebase_read_count = 0
	firebase_write_count = 0
	if FIREBASE_IO_LOGGING:
		print("[Firebase TOTAL] Counts reset")

func _firebase_doc_path(collection_path: String, doc_id: String) -> String:
	if doc_id == "":
		return collection_path
	return collection_path.path_join(doc_id)

func _format_firebase_payload(data) -> String:
	var json = JSON.stringify(data)
	if json == "":
		return str(data)
	return json


func _ready():
	# Internet check timer
	var internet_timer := Timer.new()
	internet_timer.wait_time = INTERNET_CHECK_INTERVAL
	internet_timer.one_shot = false
	internet_timer.autostart = true
	add_child(internet_timer)

	internet_timer.timeout.connect(func():
		if not is_logged_in():
			return

		if _internet_check_in_progress:
			return

		_internet_check_in_progress = true
		await _check_internet_and_sync()
		_internet_check_in_progress = false
	)

	# Session update timer
	var session_update_timer := Timer.new()
	session_update_timer.wait_time = SESSION_UPDATE_INTERVAL
	session_update_timer.one_shot = false
	session_update_timer.autostart = true
	add_child(session_update_timer)

	session_update_timer.timeout.connect(func():
		if not is_logged_in():
			return

		if _session_update_in_progress:
			return

		_session_update_in_progress = true

		if await internet_available():
			await _update_session()

		_session_update_in_progress = false
	)

	# Session validation timer
	var session_check_timer := Timer.new()
	session_check_timer.wait_time = SESSION_CHECK_INTERVAL
	session_check_timer.one_shot = false
	session_check_timer.autostart = true
	add_child(session_check_timer)

	session_check_timer.timeout.connect(func():
		if not is_logged_in():
			return

		if _session_check_in_progress:
			return

		_session_check_in_progress = true

		if await internet_available():
			await _check_session_valid()

		_session_check_in_progress = false
	)


# func _process(delta):

# 	if not is_logged_in():
# 		return

# 	# Prevent multiple internet checks at same time
# 	if not _internet_check_in_progress:
# 		_internet_check_timer += delta

# 		if _internet_check_timer >= INTERNET_CHECK_INTERVAL:
# 			_internet_check_timer = 0.0
# 			_internet_check_in_progress = true
# 			await _check_internet_and_sync()
# 			_internet_check_in_progress = false

# 	# Handle pending syncs
# 	# if _sync_pending:
# 	# 	_sync_timer += delta

# 	# 	if _sync_timer >= SYNC_DELAY:
# 	# 		_sync_pending = false
# 	# 		_sync_timer = 0.0
# 	# 		await _push_to_firestore()

# 	# Update session
# 	_update_session_timer += delta

# 	if _update_session_timer >= SESSION_UPDATE_INTERVAL and not _session_update_in_progress:
# 		_update_session_timer = 0
# 		_session_update_in_progress = true

# 		if await _internet_available():
# 			await _update_session()
# 		_session_update_in_progress = false

# 	# Validate session
# 	_session_check_timer += delta

# 	if _session_check_timer >= SESSION_CHECK_INTERVAL and not _session_check_in_progress:
# 		_session_check_timer = 0
# 		_session_check_in_progress = true

# 		if await _internet_available():
# 			await _check_session_valid()
# 		_session_check_in_progress = false

		
func _check_internet_and_sync():
	var currently_online = await internet_available()
   
	# If we just connected to internet, auto-sync
	if currently_online and not _last_internet_status:
		print("Internet connection detected! Auto-syncing with Firebase...")
		_last_internet_status = true
		is_offline_mode = false

		await sync_from_cloud_if_newer()
		
		if PlayerData.needs_cloud_sync:
			_mark_all_sections_dirty()
		await push_to_firestore()
	elif not currently_online and _last_internet_status:

		print("Internet lost!")

		_last_internet_status = false
		is_offline_mode = true



func mark_dirty(sections: Array = []):
	# Call this whenever data changes
	PlayerData.needs_cloud_sync = true
	PlayerData.save_local() # instant local save
	if sections.is_empty():
		sections = [SECTION_PROFILE, SECTION_STATS, SECTION_INVENTORY, SECTION_LEADERBOARD]
	for section in sections:
		_dirty_sections[str(section)] = true
	# _sync_pending = true
	# _sync_timer = 0.0 # reset timer on each change
	
	
func push_to_firestore():
	if player_id == "":
		return
	if not await internet_available():
		print("No internet connection detected. Skipping Firestore sync.")
		PlayerData.save_local()
		is_data_dirty = true
		return
	if _dirty_sections.is_empty() and PlayerData.needs_cloud_sync:
		_mark_all_sections_dirty()
	if _dirty_sections.is_empty():
		return
	print("Syncing to Firestore...")
	await _save_dirty_sections()
	PlayerData.needs_cloud_sync = false
	PlayerData.save_local()
	is_data_dirty = false
	print("Sync complete")
	
# ─────────────────────────────────────────────────────────────────
func init(uid: String, login_method: String = "", create_defaults: bool = false, user_name: String = ""):
	PlayerData.reset_defaults()
	data_loaded = false
	player_id = uid
	current_login_method = login_method
	create_defaults_for_missing_docs = create_defaults
	PlayerData.player_id = uid
	PlayerData.login_method = login_method

	# if create_defaults_for_missing_docs:
	# 	var clean_name = user_name.strip_edges()
	# 	# User entered custom username
	# 	if clean_name != "":
	# 		PlayerData.player_name = clean_name
	# 		await register_username(clean_name)
	# 		# Guest account → auto generate username
	# 	else:
	# 		var generated_name := ""
	# 		while true:
	# 			generated_name = generate_random_names() + uid.right(4)
	# 			var available = await is_username_available(generated_name)
	# 			if available:
	# 				break
	# 		PlayerData.player_name = generated_name
	# 		# Register inside usernames collection
	# 		await register_username(generated_name)
	_players_col = Firebase.Firestore.collection("players/" + uid + "/Profile")
	_stats_col = Firebase.Firestore.collection("players/" + uid + "/Stats")
	_inventory_col = Firebase.Firestore.collection("players/" + uid + "/Inventory")
	# _misc_col = Firebase.Firestore.collection("players/" + uid + "/Miscellaneous")
	_session_col = Firebase.Firestore.collection("players/" + player_id + "/Session")
	usernames_col = Firebase.Firestore.collection("usernames")


func generate_random_names() -> String:
 
	var words = [
		"Neo", "Dark", "Ghost", "Turbo",
		"Blaze", "Venom", "Pixel", "Hyper",
		"Nova", "Rex", "Ace", "Bolt",
		"Axel", "Zion", "Fury", "Drift",
		"Vibe", "Glitch", "Frost", "Flare",
		"Storm", "Spike", "Flint", "Shadow",
		"Rogue", "Skye", "Wolf", "Jinx",
		"Dash", "Crash", "Blitz", "Venix",
		"Zoro", "Kairo", "Maver", "Onyx",
		"Pyro", "Quark", "Raven", "Steel",
		"Knight", "Orbit", "Cipher", "Sonic",
		"Rift", "Echo", "Havoc", "Nitro",
		"Zero", "Lynx", "Fang", "Talon",
		"Hex", "Rune", "Volt", "Drako",
		"Orbit", "Zade", "Astra", "Infer",
		"Vex", "Nyx"
	]
 
	var word = words[randi() % words.size()]
 
	## Random 3-digit number
	#var number = str(randi_range(100, 999))
 
	var final_name = word + "_"
 
	# Ensure max 12 chars
	if final_name.length() > 12:
		final_name = final_name.substr(0, 12)
 
	return final_name

# ── LOAD ALL ──────────────────────────────────────────────────────
func load_all(allow_cloud: bool = true):
	if _load_all_in_progress:
		return false
	_load_all_in_progress = true
	_loaded_count = 0
	_cloud_loaded_any_data = false
	data_loaded = false
	if player_id == "" or _players_col == null or _stats_col == null or _inventory_col == null:
		var fallback_loaded_missing_refs = _try_fallback()
		_load_all_in_progress = false
		return fallback_loaded_missing_refs

	if not allow_cloud:
		is_offline_mode = true
		var fallback_loaded_no_cloud = _try_fallback()
		_load_all_in_progress = false
		return fallback_loaded_no_cloud

	is_offline_mode = false
	
	# Check internet first
	var online = await internet_available()

	if not online:
		# Offline: just use local, mark for sync later
		is_offline_mode = true
		var loaded = PlayerData.load_local()
		if loaded:
			data_loaded = true
			PlayerData.has_loaded_data = true
			if PlayerData.needs_cloud_sync:
				print("Offline: pending sync flagged for later.")
			emit_signal("on_data_loaded")
			_load_all_in_progress = false
			return true
		var fallback_loaded_offline = _try_fallback()
		_load_all_in_progress = false
		return fallback_loaded_offline

	_last_internet_status = true

	# Online: load local first just to get its timestamp
	var local_ts: int = 0
	if PlayerData.load_local():
		local_ts = PlayerData.last_saved_timestamp
		if PlayerData.needs_cloud_sync:
			# Local has unsynced changes — push immediately, skip cloud fetch
			print("Unsynced local data found. Pushing to cloud...")
			await push_to_firestore()
			emit_signal("on_data_loaded")
			_load_all_in_progress = false
			return true

	# 1. Top-level player doc
	var profile_doc = await _players_col.get_doc("Profile")
	_log_firestore_read("players/" + player_id + "/Profile", "Profile", profile_doc)
	await _on_profile_loaded(profile_doc)

	# 2. Stats
	var stats_doc = await _stats_col.get_doc("stats")
	_log_firestore_read("players/" + player_id + "/Stats", "stats", stats_doc)
	await _on_stats_loaded(stats_doc)

	# 3. Inventory
	var inventory_doc = await _inventory_col.get_doc("inventory")
	_log_firestore_read("players/" + player_id + "/Inventory", "inventory", inventory_doc)
	await _on_inventory_loaded(inventory_doc)

	# 4. Miscellaneous
	# var misc_doc = await _misc_col.get_doc("misc")
	# _log_firestore_read("players/" + player_id + "/Miscellaneous", "misc", misc_doc)
	# await _on_misc_loaded(misc_doc)

	if not _cloud_loaded_any_data and not create_defaults_for_missing_docs:
		var fallback_loaded_empty_cloud = _try_fallback()
		_load_all_in_progress = false
		return fallback_loaded_empty_cloud
	data_loaded = true
	PlayerData.has_loaded_data = true
	_load_all_in_progress = false
	return true

func _on_profile_loaded(doc):
	var data = _get_doc_data(doc)
	if not data.is_empty():
		_cloud_loaded_any_data = true
		PlayerData.apply_dict(data)
	else:
		if create_defaults_for_missing_docs:
			await _save_profile()
	await _increment_loaded()

func _on_stats_loaded(doc):
	var data = _get_doc_data(doc)
	if not data.is_empty():
		_cloud_loaded_any_data = true
		PlayerData.apply_dict(data)
	else:
		if create_defaults_for_missing_docs:
			await _save_stats()
	await _increment_loaded()

func _on_inventory_loaded(doc):
	var data = _get_doc_data(doc)
	if not data.is_empty():
		_cloud_loaded_any_data = true
		PlayerData.apply_dict(data)
	else:
		if create_defaults_for_missing_docs:
			await save_inventory()
	await _increment_loaded()

# func _on_misc_loaded(doc):
# 	var data = _get_doc_data(doc)
# 	if not data.is_empty():
# 		_cloud_loaded_any_data = true
# 		PlayerData.apply_dict(data)
# 		if current_login_method != "" and str(data.get("LoginMethod", "")) != current_login_method:
# 			PlayerData.login_method = current_login_method
# 			await save_misc()
# 	else:
# 		if create_defaults_for_missing_docs:
# 			await save_misc()
# 	await _increment_loaded()

func _get_doc_data(doc) -> Dictionary:
	if doc == null:
		return {}
	if doc.has_method("get_unsafe_document"):
		return doc.get_unsafe_document()
	return {}

func _log_firestore_read(collection_path: String, doc_id: String, doc):
	var data = _get_doc_data(doc)
	print_firebase_read(collection_path, doc_id, data, doc != null and not data.is_empty())

func _apply_firestore_doc(doc) -> bool:
	var data = _get_doc_data(doc)
	if data.is_empty():
		return false
	PlayerData.apply_dict(data)
	return true

		
func _increment_loaded():
	_loaded_count += 1
	if _loaded_count == COLLECTIONS_TO_LOAD:
		var cloud_ts: int = PlayerData.last_saved_timestamp  # just applied from cloud
		var local_ts: int = 0
		
		# Peek at local timestamp without overwriting current (cloud) data
		var local_data = PlayerData.peek_local_timestamp()  # see below
		if local_data > 0:
			local_ts = local_data
		
		if local_ts - cloud_ts > 10:
			# Local is newer → restore local data and push it up to Firestore
			print("Local data is newer (local: %d, cloud: %d). Using local and syncing up." % [local_ts, cloud_ts])
			PlayerData.load_local()
			PlayerData.needs_cloud_sync = true
			_mark_all_sections_dirty()
			await push_to_firestore()
		else:
			# Cloud is newer (or equal) → already applied, just save locally
			print("Cloud data is newest (cloud: %d, local: %d). Saving to local cache." % [cloud_ts, local_ts])
			PlayerData.save_local()
		
		data_loaded = true
		PlayerData.has_loaded_data = true
		emit_signal("on_data_loaded")

func _try_fallback():
	var loaded = PlayerData.load_local()
	if loaded:
		PlayerData.player_id = player_id
		PlayerData.login_method = current_login_method
		data_loaded = true
		PlayerData.has_loaded_data = true
	else:
		data_loaded = false
		PlayerData.has_loaded_data = false
		print("No local player data found for offline startup.")
	emit_signal("on_load_failed")
	if loaded:
		emit_signal("on_data_loaded")
	return loaded

# ── SAVE ALL ──────────────────────────────────────────────────────
func save_all():
	if not await internet_available():
		print("No internet connection detected. Skipping Firestore save_all.")
		PlayerData.save_local()
		is_data_dirty = true
		return
	await flush_dirty(true)

func flush_dirty(force_all: bool = false):
	if player_id == "":
		return
	if force_all:
		_mark_all_sections_dirty()
	if _dirty_sections.is_empty():
		return
	if not await internet_available():
		print("No internet connection detected. Skipping Firestore sync.")
		PlayerData.needs_cloud_sync = true
		PlayerData.save_local()
		is_data_dirty = true
		return
	await _save_dirty_sections()
	PlayerData.needs_cloud_sync = false
	PlayerData.save_local()
	is_data_dirty = false

func _mark_all_sections_dirty():
	for section in [SECTION_PROFILE, SECTION_STATS, SECTION_INVENTORY, SECTION_LEADERBOARD]:
		_dirty_sections[section] = true

func _save_dirty_sections():
	if _dirty_sections.is_empty():
		return
	if _dirty_sections.get(SECTION_PROFILE, false):
		await _save_profile()
	if _dirty_sections.get(SECTION_STATS, false):
		await _save_stats()
	if _dirty_sections.get(SECTION_INVENTORY, false):
		await save_inventory()
	# if _dirty_sections.get(SECTION_MISC, false):
	# 	await save_misc()
	if _dirty_sections.get(SECTION_LEADERBOARD, false):
		await LeaderboardManager.update_entry()
	_dirty_sections.clear()

	
func internet_available() -> bool:
	var http = HTTPRequest.new()
	http.timeout = 5.0
	add_child(http)
	var request_error = http.request(INTERNET_CHECK_URL)
	if request_error != OK:
		http.queue_free()
		return false
	var result = await http.request_completed
	http.queue_free()
	if result.size() >= 2:
		var response_code = result[1]
		return response_code >= 200 and response_code < 300
	return false

func _save_profile():
	var data := {
		"player_name": PlayerData.player_name,
		"status": PlayerData.status,
		"leaderboard_score": PlayerData.coins,
		"last_saved_timestamp": int(Time.get_unix_time_from_system()),
		"Device_type": PlayerData.device_type,
		"LoginMethod": PlayerData.login_method
	}
	print_firebase_write("players/" + player_id + "/Profile", "Profile", data)
	await _players_col.set_doc("Profile", data)

func _save_stats():
	var data := {
		"Coins": PlayerData.coins,
		"ELO": PlayerData.elo,
		"MatchesWon": PlayerData.matches_won,
		"MatchesLost": PlayerData.matches_lost,
		"MatchesPlayed": PlayerData.matches_played,
		"kd": PlayerData.kd,
		"TotalPots": PlayerData.total_pots,
		"Rank": PlayerData.rank,
		"RankPoints": PlayerData.rank_points,
		"last_saved_timestamp": int(Time.get_unix_time_from_system())
	}
	print_firebase_write("players/" + player_id + "/Stats", "stats", data)
	await _stats_col.set_doc("stats", data)

func save_inventory():
	var data := {
		"BagEquipped": PlayerData.equipped_cornbag,
		"BoardEquipped": PlayerData.equipped_board,
		"BagsOwned": PlayerData.bags_owned,
		"BoardsOwned": PlayerData.boards_owned
	}
	print_firebase_write("players/" + player_id + "/Inventory", "inventory", data)
	await _inventory_col.set_doc("inventory", data)

# func save_misc():
# 	# PlayerData.get_or_create_device_id()

# 	var data := {
# 		"Achievements": PlayerData.achievements,
# 		"DailyRewardsTaken": PlayerData.daily_rewards_taken,
# 		"LoginMethod": PlayerData.login_method,
# 		"device_id": PlayerData.device_id,
# 		"In-App-Purchase": PlayerData.IAP,
# 		"DisplayAds": !PlayerData.IAP
# 	}
# 	print_firebase_write("players/" + player_id + "/Miscellaneous", "misc", data)
# 	await _misc_col.set_doc("misc", data)
	
func _update_session():
	if player_id == "" or not PlayerData.session_active:
		return

	var data := {
		"session_id": PlayerData.session_id,
		"last_active": int(Time.get_unix_time_from_system()),
		"device": PlayerData.device_type,
		"device_id":   PlayerData.device_id
	}
	print_firebase_write("players/" + player_id + "/Session", "active", data)
	await _session_col.set_doc("active", data)

func _check_session_valid():
	if player_id == "" or PlayerData.session_id == "":
		return

	var doc = await _session_col.get_doc("active")
	_log_firestore_read("players/" + player_id + "/Session", "active", doc)

	if doc == null:
		return

	var data = doc.get_unsafe_document()
	var server_session = str(data.get("session_id", ""))

	if server_session != PlayerData.session_id:
		print("Logged out: session taken by another device")

		PlayerData.clear_login_session()
		get_tree().change_scene_to_file("res://Authentication.tscn")


func _notification(what):
	if what == NOTIFICATION_APPLICATION_PAUSED:

		print("App minimized. Saving progress...")

		PlayerData.save_local()

		if PlayerData.needs_cloud_sync:
			await push_to_firestore()

	elif what == NOTIFICATION_WM_CLOSE_REQUEST:

		print("App closing. Saving progress...")

		PlayerData.save_local()

		if PlayerData.needs_cloud_sync:
			await push_to_firestore()

		await _clear_session()


func is_logged_in() -> bool:
	return PlayerData.check_logged_in and player_id != ""

func _clear_session():
	if player_id == "":
		return

	print_firebase_write("players/" + player_id + "/Session", "active", {})
	await _session_col.set_doc("active", {})


# check newer data and sync
func sync_from_cloud_if_newer():

	if not await internet_available():
		print("No internet. Cannot compare cloud/local data.")
		return false

	# Load local timestamp
	var local_ts: int = PlayerData.peek_local_timestamp()

	# Fetch cloud profile doc
	var profile_doc = await _players_col.get_doc("Profile")
	_log_firestore_read("players/" + player_id + "/Profile", "Profile", profile_doc)

	if profile_doc == null:
		print("No cloud profile found.")
		return false
	
	var cloud_data : Dictionary= profile_doc.get_unsafe_document()

	if cloud_data.is_empty():
		print("Cloud profile empty.")
		return false

	var cloud_ts: int = int(cloud_data.get("last_saved_timestamp", 0))

	print("☁ Cloud TS:", cloud_ts)
	print("📱 Local TS:", local_ts)

	# Cloud newer → download everything
	if cloud_ts > local_ts:

		print("⬇ Cloud data is newer. Syncing to mobile...")

		# Profile
		_apply_firestore_doc(profile_doc)

		# Stats
		var stats_doc = await _stats_col.get_doc("stats")
		_log_firestore_read("players/" + player_id + "/Stats", "stats", stats_doc)
		_apply_firestore_doc(stats_doc)

		# Inventory
		var inventory_doc = await _inventory_col.get_doc("inventory")
		_log_firestore_read("players/" + player_id + "/Inventory", "inventory", inventory_doc)
		_apply_firestore_doc(inventory_doc)

		# Misc
		# var misc_doc = await _misc_col.get_doc("misc")
		# _log_firestore_read("players/" + player_id + "/Miscellaneous", "misc", misc_doc)
		# _apply_firestore_doc(misc_doc)

		# Save latest cloud data locally
		data_loaded = true
		PlayerData.has_loaded_data = true
		PlayerData.save_local()

		print("Mobile updated from Firebase")
		return true

	print("📱 Local data already latest")
	return false



func is_username_available(username: String) -> bool:

	username = username.strip_edges().to_lower()

	if username == "":
		return false

	usernames_col = Firebase.Firestore.collection("usernames")
	var doc = await usernames_col.get_doc(username)

	if doc == null:
		return true

	var data = doc.get_unsafe_document()

	if data.is_empty():
		return true

	# FIX: agar same uid ka username hai toh available maano
	if str(data.get("uid", "")) == player_id:
		return true

	return false


func register_username(username: String) -> bool:

	username = username.strip_edges().to_lower()

	if username == "":
		return false

	usernames_col = Firebase.Firestore.collection("usernames")
	# double check
	var available = await is_username_available(username)

	if not available:
		return false

	var data = {
		"uid": player_id,
		"created_at": Time.get_unix_time_from_system()
	}

	print_firebase_write("usernames", username, data)

	await usernames_col.set_doc(username, data)

	return true


func is_username_mine(username: String, uid: String) -> bool:
	username = username.strip_edges().to_lower()
	if username == "":
		return false

	usernames_col = Firebase.Firestore.collection("usernames")
	var doc = await usernames_col.get_doc(username)
	if doc == null:
		return false

	var data = doc.get_unsafe_document()
	if data.is_empty():
		return false

	# Agar username ka uid match karta hai — ye mera username hai
	return str(data.get("uid", "")) == uid

	
