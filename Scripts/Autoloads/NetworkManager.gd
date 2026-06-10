extends Node
 
# =========================
# CONSTANTS
# =========================
const PORT := 7777
const MAX_PLAYERS := 2
const MAX_REMOTE_CLIENTS := MAX_PLAYERS - 1
const DISCOVERY_PORT := 8888
 
const MAP_LIST := [
	"res://Scenes/Maps/street.tscn",
	"res://Scenes/Maps/stadium.tscn",
	"res://Scenes/Maps/backyard.tscn",
	"res://Scenes/Maps/metro.tscn",
	"res://Scenes/Maps/rooftop.tscn",
    "res://Scenes/Maps/lawn.tscn"
]
 
const HOST_DEFAULT_BAG_ID := "carmine"
const CLIENT_DEFAULT_BAG_ID := "cobalt"
const BAG_CONFIGS := {
	"arctic": preload("res://Resources/Bags/Arctic_bag.tres"),
	"camouflage": preload("res://Resources/Bags/Camouflage_bag.tres"),
	"cobalt": preload("res://Resources/Bags/Cobalt_bag.tres"),
	"neon": preload("res://Resources/Bags/Neon_bag.tres"),
	"peace": preload("res://Resources/Bags/Peace_bag.tres"),
	"picpunk": preload("res://Resources/Bags/PicPunk_bag.tres"),
	"rogue": preload("res://Resources/Bags/Rogue_bag.tres"),
	"shell": preload("res://Resources/Bags/Shell_bag.tres"),
	"shield": preload("res://Resources/Bags/Shield_bag.tres"),
	"shurican": preload("res://Resources/Bags/Shurican_bag.tres"),
	"skyline": preload("res://Resources/Bags/Skyline_bag.tres"),
	"splash": preload("res://Resources/Bags/Splash_bag.tres"),
	"stitches": preload("res://Resources/Bags/Stitches_bag.tres"),
	"target": preload("res://Resources/Bags/Target_bag.tres"),
	"urban": preload("res://Resources/Bags/Urban_bag.tres"),
	"carmine": preload("res://Resources/Bags/Carmine_bag.tres")
}
 
# id for bag config
const BAG_ID_TO_KEY := {
	"S1": "arctic",
	"S2": "camouflage",
	"S3": "cobalt",
	"S4": "neon",
	"S5": "peace",
	"S6": "picpunk",
	"S7": "rogue",
	"S8": "shell",
	"S9": "shield",
	"S10": "shurican",
	"S11": "skyline",
	"S12": "splash",
	"S13": "stitches",
	"S14": "target",
	"S15": "urban",
	"S16": "carmine"
}
 
const HOST_DEFAULT_BOARD_ID := "volt_strike"
const DEFAULT_BOARD_ID := "volt_strike"
 
const BOARD_CONFIGS := {
	"deadlock": preload("res://Resources/Boards/Deadlock.tres"),
	"horizon_shift": preload("res://Resources/Boards/Horizon_shift.tres"),
	"royal_sheild": preload("res://Resources/Boards/Royal_Shield.tres"),
	"sunburst": preload("res://Resources/Boards/Sunburst.tres"),
	"vanguard": preload("res://Resources/Boards/Vanguard.tres"),
	"volt_strike": preload("res://Resources/Boards/Volt_strike.tres")
}
 
# id for bag config
const BOARD_ID_TO_KEY := {
	"B1": "deadlock",
	"B2": "horizon_shift",
	"B3": "royal_sheild",
	"B4": "sunburst",
	"B5": "vanguard",
	"B6": "volt_strike"
}
 
# =========================
# STATE
# =========================
var is_host: bool = false
var my_id: int = 0
 
var players: Dictionary = {}
 
# WebRTC & Firebase Discovery
var rtc_pc: WebRTCPeerConnection
var _last_rtc_state: int = -1
var _rooms_listener_ref
var found_servers: Array = []
var rematch_in_progress: bool = false
var pending_rematch_requester_id: int = 0
var outgoing_rematch_target_id: int = 0
 
# =========================
# SIGNALS
# =========================
signal player_connected(id: int)
signal player_disconnected(id: int)
 
signal connection_failed
signal server_disconnected
 
signal game_ready
signal server_found(server: Dictionary)
 
signal match_forfeit(reason: String)
signal room_join_failed(message: String)
 
signal rematch_requested
signal rematch_declined(message: String)
 
var hosted_room_name: String = ""
var hosted_room_id: String = ""
 
 
# =========================
# INIT
# # =========================
# func _ready() -> void:
 
#   multiplayer.peer_connected.connect(_on_peer_connected)
#   multiplayer.peer_disconnected.connect(_on_peer_disconnected)
 
#   multiplayer.connected_to_server.connect(_on_connected_to_server)
#   multiplayer.connection_failed.connect(_on_connection_failed)
#   multiplayer.server_disconnected.connect(_on_server_disconnected)
 
 
func _ready() -> void:
	_connect_multiplayer_signals()

func _process(delta: float) -> void:
	if rtc_pc:
		rtc_pc.poll()
		var current_state = rtc_pc.get_connection_state()
		if current_state != _last_rtc_state:
			_last_rtc_state = current_state
			_on_rtc_state_changed(current_state)

# =========================
# HOST
# =========================
func host_game(room_name: String = "") -> void:
	if multiplayer.multiplayer_peer != null:
		await get_tree().process_frame
		disconnect_game()
		await get_tree().process_frame
 
 
	# PlayerData load hone ka wait karo
	if not PlayerData.has_loaded_data:
		print("[HOST] Waiting for PlayerData...")
		await PlayerData.local_data_loaded
 
 
	is_host = true
	var normalized_room_name := room_name.strip_edges()
	if normalized_room_name.is_empty():
		normalized_room_name = hosted_room_name.strip_edges()
	if normalized_room_name.is_empty():
		normalized_room_name = "%s's Room" % (PlayerData.player_name if PlayerData.player_name != "" else "Host")
 
	hosted_room_name = normalized_room_name
	
	# Generate a random 4-digit code if hosted_room_id is not already numeric
	var normalized_id := _normalize_room_id(hosted_room_id)
	if normalized_id.is_empty() or not normalized_id.is_valid_int():
		hosted_room_id = str(randi_range(1000, 9999))
	else:
		hosted_room_id = normalized_id
 
	var peer = WebRTCMultiplayerPeer.new()
	var error = peer.create_server()
 
	if error != OK:
		is_host = false
		hosted_room_name = ""
		hosted_room_id = ""
		push_error("Failed to create server")
		room_join_failed.emit("Failed to create room")
		return
 
	multiplayer.multiplayer_peer = peer
 
	my_id = multiplayer.get_unique_id()
 
	var bag_id = get_local_bag_id()
	var board_id = get_local_board_id()
	print("[HOST] bag_id: ", bag_id, " board_id: ", board_id)
 
	var my_data = {
		"id": my_id,
		"name": PlayerData.player_name,
		"profile_index": Prefs.get_int("profile_index", 0),
		"bag_id": get_local_bag_id(),
		"board_id": get_local_board_id(),
		"boards_owned": PlayerData.boards_owned.duplicate(),
		"matches_played": PlayerData.matches_played,
		"total_pots": PlayerData.total_pots
	}
 
	players[my_id] = my_data
 
	if not WebRTCSignaling.client_joined.is_connected(_on_webrtc_client_joined):
		WebRTCSignaling.client_joined.connect(_on_webrtc_client_joined)
		WebRTCSignaling.answer_received.connect(_on_webrtc_answer_received)
		WebRTCSignaling.ice_candidate_received.connect(_on_webrtc_ice_candidate)
 
	print("ROOM ID =", hosted_room_id)
	print("ROOM NAME =", hosted_room_name)
	
	WebRTCSignaling.create_room(hosted_room_id, hosted_room_name, my_data)
 
 
# =========================
# JOIN
# =========================
func join_game(room_id: String) -> void:
	if multiplayer.multiplayer_peer != null:
		await get_tree().process_frame
		disconnect_game()
		await get_tree().process_frame
 
	is_host = false
	hosted_room_id = room_id
 
	var peer = WebRTCMultiplayerPeer.new()
	var error = peer.create_client(2)
 
	if error != OK:
		connection_failed.emit()
		return
 
	multiplayer.multiplayer_peer = peer
	my_id = 2
	print("[Network] Connecting to room:", room_id)
	
	if not WebRTCSignaling.offer_received.is_connected(_on_webrtc_offer_received):
		WebRTCSignaling.offer_received.connect(_on_webrtc_offer_received)
		WebRTCSignaling.ice_candidate_received.connect(_on_webrtc_ice_candidate)
		WebRTCSignaling.host_joined.connect(_on_webrtc_host_joined)
		
	var my_data = {
		"id": my_id,
		"name": PlayerData.player_name if PlayerData.player_name != "" else "Player",
		"profile_index": Prefs.get_int("profile_index", 0),
		"bag_id": get_local_bag_id(),
		"board_id": get_local_board_id(),
		"boards_owned": PlayerData.boards_owned.duplicate(),
		"matches_played": PlayerData.matches_played,
		"total_pots": PlayerData.total_pots
	}
	WebRTCSignaling.join_room(room_id, my_data)
	_init_webrtc_pc(1)
 
 
# =========================
# MATCH START
# =========================
func get_random_map() -> String:
	return MAP_LIST[randi() % MAP_LIST.size()]
 
 
@rpc("any_peer", "reliable")
func test_rpc(msg: String) -> void:
	print(msg)

@rpc("any_peer", "reliable")
func register_player(data: Dictionary):
	var sender_id = multiplayer.get_remote_sender_id()
	if is_host and not players.has(sender_id) and players.size() >= MAX_PLAYERS:
		print("[Network] Disconnecting peer in register_player due to full room. sender_id:", sender_id)
		room_full_rpc.rpc_id(sender_id, "Room already full")
		_disconnect_peer(sender_id)
		return
 
	players[sender_id] = data
 
	print("[Network] Player registered:", sender_id)
	player_connected.emit(sender_id)
 
	if is_host and players.size() == MAX_PLAYERS:
		print("[Network] Game Ready - Waiting for Host to start")

func host_start_game_manually() -> void:
	if not is_host or players.size() < MAX_PLAYERS:
		return
	print("[Network] Host starting match manually...")
	var map = GameSession.selected_map_path
	if map == "":
		map = get_random_map()
	_sync_and_start_match(map)
 
 
func _sync_and_start_match(map: String) -> void:
	# Host apna data sabko bhejo taaki client ke paas host ka data ho
	sync_player_data_rpc.rpc(players)
 
	# Host ke paas khud bhi call karo
	sync_player_data_rpc(players)
 
	# Thoda wait karo — data propagate hone do
	await get_tree().create_timer(0.3).timeout
 
	# Ab match start karo
	start_match_rpc.rpc(map)
	if multiplayer.is_server():
		start_match_rpc(map)
 
	game_ready.emit()
 
 
@rpc("authority", "reliable")
func sync_player_data_rpc(all_players: Dictionary) -> void:
	# Client ke paas ab saare players ka data hoga
	for id in all_players:
		players[int(id)] = all_players[id]
	print("[Network] Players synced — count:", players.size())
	for id in players:
		print("  Player ", id, " bag:", players[id].get("bag_id", "?"))
 
 
# @rpc("any_peer", "reliable")
# func start_match_rpc(map_path: String):
#   print("[RPC RECEIVED] Loading:", map_path)
#   rematch_in_progress = false
#   _clear_rematch_request_state()
 
#   GameSession.start_match("Local", map_path, "Local", 20.0)
 
#   SceneManager.preload_async(map_path)
 
#   await SceneManager.wait_until_loaded(map_path)
 
#   SceneManager.goto(map_path)
 
 
@rpc("any_peer", "reliable")
func start_match_rpc(map_path: String):
	print("[RPC RECEIVED] Loading:", map_path)
	rematch_in_progress = false
	_clear_rematch_request_state()
 
	var match_ui = get_tree().current_scene.get_node_or_null("MatchUI")
	if match_ui and match_ui.has_node("WaitingForPlayersUI"):
		match_ui.get_node("WaitingForPlayersUI").visible = false
		if match_ui.has_node("InGame UI"):
			match_ui.get_node("InGame UI").visible = true
			
	GameSession.start_match("Multiplayer", map_path, "Multiplayer", 20.0)
 
	SceneManager.preload_async(map_path)
 
	await SceneManager.wait_until_loaded(map_path)
 
	SceneManager.goto(map_path)
 
 
 
 
# =========================
# REMATCH
# =========================
func send_rematch_request() -> void:
	if rematch_in_progress:
		return
 
	for id in players.keys():
		if id != multiplayer.get_unique_id():
			outgoing_rematch_target_id = int(id)
			receive_rematch_request.rpc_id(id)
 
 
@rpc("any_peer", "reliable")
func receive_rematch_request() -> void:
	if rematch_in_progress:
		return
 
	pending_rematch_requester_id = multiplayer.get_remote_sender_id()
	rematch_requested.emit()
 
 
@rpc("any_peer", "reliable")
func accept_rematch() -> void:
	if rematch_in_progress:
		return
 
	if multiplayer.is_server():
		var mode := GameSession.selected_mode
		var map_path := GameSession.selected_map_path
		var ui := GameSession.required_ui
		var time_limit := GameSession.time_left
 
		_begin_rematch(mode, map_path, ui, time_limit)
 
 
func reject_rematch() -> void:
	if not multiplayer or multiplayer.multiplayer_peer == null:
		return
 
	if multiplayer.is_server():
		if pending_rematch_requester_id > 0:
			rematch_declined_rpc.rpc_id(
				pending_rematch_requester_id,
                "Opponent declined rematch"
			)
		_clear_rematch_request_state()
	else:
		decline_rematch.rpc_id(1)
		_clear_rematch_request_state()
 
 
@rpc("any_peer", "reliable")
func decline_rematch() -> void:
	if not multiplayer.is_server():
		return
 
	rematch_declined.emit("Opponent declined rematch")
	_clear_rematch_request_state()
 
 
@rpc("authority", "reliable")
func rematch_declined_rpc(message: String) -> void:
	rematch_declined.emit(message)
	_clear_rematch_request_state()
 
 
@rpc("authority", "reliable")
func start_rematch(
	mode: String,
	map_path: String,
	ui: String,
	time_limit: float
) -> void:
	rematch_in_progress = true
	UIManager.restart(mode, map_path, ui, time_limit)
 
 
func _begin_rematch(
	mode: String,
	map_path: String,
	ui: String,
	time_limit: float
) -> void:
	if mode.is_empty() or map_path.is_empty():
		push_warning("[Network] Cannot rematch without an active match")
		return
 
	rematch_in_progress = true
	start_rematch.rpc(mode, map_path, ui, time_limit)
	start_rematch(mode, map_path, ui, time_limit)
	_clear_rematch_request_state()
 
 
# =========================
# THROW RPC
# =========================
@rpc("any_peer", "reliable")
func request_throw(direction: Vector3, strength: float) -> void:
	if not multiplayer.is_server():
		return
 
	var bag: Node = null
	var latest_spawn_index := -1
 
	for node in get_tree().get_nodes_in_group("active_bag"):
		if not is_instance_valid(node):
			continue
		if not node.has_method("is_waiting_for_throw"):
			continue
		if not bool(node.call("is_waiting_for_throw")):
			continue
 
		var spawn_index := int(node.get_meta("bag_spawn_index", -1))
		if spawn_index > latest_spawn_index:
			latest_spawn_index = spawn_index
			bag = node
 
	if bag == null:
		print("NO ACTIVE BAG")
		return
 
	var sender_id := multiplayer.get_remote_sender_id()
 
	var sender_player := 1 if sender_id == 1 else 2
 
	if sender_player != GameSession.current_turn:
		print("WRONG TURN")
		return
 
	bag.call("server_apply_throw", direction, strength)
 
 
# =========================
# CALLBACKS
# =========================
func _on_peer_connected(id: int) -> void:
	print("[Network] Player connected:", id)
	print("DATA CHANNEL OPEN")
	if is_host and players.size() >= MAX_PLAYERS and not players.has(id):
		print("[Network] Disconnecting peer in _on_peer_connected due to full room. id:", id)
		room_full_rpc.rpc_id(id, "Room already full")
		_disconnect_peer(id)
		return
 
	player_connected.emit(id)
 
	if is_host:
		register_player.rpc_id(id, players[my_id])
 
 
func _on_peer_disconnected(id: int) -> void:
	print("[Network] Player disconnected:", id)
 
	players.erase(id)
 
	player_disconnected.emit(id)
 
	if not GameSession.match_over:
		if is_host:
			match_forfeit.emit("client left")
 
 
func _on_connected_to_server() -> void:
	my_id = multiplayer.get_unique_id()
 
	if not PlayerData.has_loaded_data:
		print("[CLIENT] Waiting for PlayerData...")
		await PlayerData.local_data_loaded
	   
	var my_data = {
		"id": my_id,
		"name": PlayerData.player_name if PlayerData.player_name != "" else "Player",
		"profile_index": Prefs.get_int("profile_index", 0),
		"bag_id": get_local_bag_id(),
		"board_id": get_local_board_id(),
		"boards_owned": PlayerData.boards_owned.duplicate(),
		"matches_played": PlayerData.matches_played,
		"total_pots": PlayerData.total_pots
	}
 
	register_player.rpc_id(1, my_data)
 
	print("[Network] Connected ID:", my_id)
	print("DATA CHANNEL OPEN")
 
 
func _on_connection_failed() -> void:
	print("[Network] Connection failed")
 
	multiplayer.multiplayer_peer = null
 
	connection_failed.emit()
 
 
func _on_server_disconnected() -> void:
	print("[Network] Server disconnected")
 
	disconnect_game()
 
	if not GameSession.match_over:
		match_forfeit.emit("host left")
 
	server_disconnected.emit()
 
 
# =========================
# DISCONNECT
# =========================
func disconnect_game() -> void:
	print("[Network] disconnect_game() called from:")
	print_stack()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
 
	multiplayer.multiplayer_peer = null

	if rtc_pc:
		rtc_pc.close()
		rtc_pc = null
	_last_rtc_state = -1

	players.clear()
	hosted_room_name = ""
	hosted_room_id = ""
	rematch_in_progress = false
	_clear_rematch_request_state()
 
	is_host = false
	my_id = 0
	_webrtc_started = false
 
	stop_search()
	
	# GameSession.selected_mode = "VSBot" # Reset back to VSBot when leaving multiplayer

	WebRTCSignaling.leave_room()
	if WebRTCSignaling.client_joined.is_connected(_on_webrtc_client_joined):
		WebRTCSignaling.client_joined.disconnect(_on_webrtc_client_joined)
	if WebRTCSignaling.host_joined.is_connected(_on_webrtc_host_joined):
		WebRTCSignaling.host_joined.disconnect(_on_webrtc_host_joined)
	if WebRTCSignaling.answer_received.is_connected(_on_webrtc_answer_received):
		WebRTCSignaling.answer_received.disconnect(_on_webrtc_answer_received)
		WebRTCSignaling.ice_candidate_received.disconnect(_on_webrtc_ice_candidate)
	if WebRTCSignaling.offer_received.is_connected(_on_webrtc_offer_received):
		WebRTCSignaling.offer_received.disconnect(_on_webrtc_offer_received)
		WebRTCSignaling.ice_candidate_received.disconnect(_on_webrtc_ice_candidate)

	print("[Network] Fully Disconnected")
 
# =========================
# WEBRTC PEER CONNECTION
# =========================
func _init_webrtc_pc(peer_id: int):
	rtc_pc = WebRTCPeerConnection.new()
	rtc_pc.initialize({
		"iceServers": [{"urls": ["stun:stun.l.google.com:19302"]}]
	})
	rtc_pc.session_description_created.connect(_on_pc_sdp_created)
	rtc_pc.ice_candidate_created.connect(_on_pc_ice_candidate_created)
	(multiplayer.multiplayer_peer as WebRTCMultiplayerPeer).add_peer(rtc_pc, peer_id)

func _on_rtc_state_changed(state: int) -> void:
	var state_str = "new"
	match state:
		WebRTCPeerConnection.STATE_NEW: state_str = "new"
		WebRTCPeerConnection.STATE_CONNECTING: state_str = "connecting"
		WebRTCPeerConnection.STATE_CONNECTED: state_str = "connected"
		WebRTCPeerConnection.STATE_DISCONNECTED: state_str = "disconnected"
		WebRTCPeerConnection.STATE_FAILED: state_str = "failed"
		WebRTCPeerConnection.STATE_CLOSED: state_str = "closed"
	print("WEBRTC STATE = ", state_str.to_upper())
	if state == WebRTCPeerConnection.STATE_CONNECTED:
		print("WEBRTC CONNECTED")
		print("GAME READY")
		await get_tree().create_timer(0.5).timeout
		if is_host:
			test_rpc.rpc("HELLO")

var _webrtc_started: bool = false

func _on_webrtc_client_joined(client_data: Dictionary) -> void:
	if _webrtc_started: return
	_webrtc_started = true
	
	print("CLIENT JOINED")
	if typeof(client_data) == TYPE_DICTIONARY and client_data.has("id"):
		var cid = int(client_data["id"])
		players[cid] = client_data
		player_connected.emit(cid)
		
	# Host WebRTC PC initialize karega aur Offer banayega
	_init_webrtc_pc(2)
	print("[WebRTC] Client joined. Creating offer...")
	rtc_pc.create_offer()

func _on_webrtc_host_joined(host_data: Dictionary) -> void:
	print("HOST JOINED")
	if typeof(host_data) == TYPE_DICTIONARY and host_data.has("id"):
		var hid = int(host_data["id"])
		players[hid] = host_data
		player_connected.emit(hid)

func _on_pc_sdp_created(type: String, sdp: String):
	print("[WebRTC] SDP created: ", type)
	rtc_pc.set_local_description(type, sdp)
	if type == "offer":
		WebRTCSignaling.send_offer(sdp)
	elif type == "answer":
		WebRTCSignaling.send_answer(sdp)

func _on_pc_ice_candidate_created(media: String, index: int, name: String):
	# print("[WebRTC] ICE Candidate created") # Too spammy
	WebRTCSignaling.send_ice_candidate(media, index, name)

func _on_webrtc_offer_received(sdp: String):
	print("OFFER RECEIVED")
	rtc_pc.set_remote_description("offer", sdp)
	print("REMOTE DESCRIPTION SET")
	rtc_pc.create_offer()
	print("ANSWER CREATED")

func _on_webrtc_answer_received(sdp: String):
	print("ANSWER RECEIVED")
	rtc_pc.set_remote_description("answer", sdp)

func _on_webrtc_ice_candidate(media: String, index: int, name: String):
	print("ICE RECEIVED")
	rtc_pc.add_ice_candidate(media, index, name)
	print("ICE EXCHANGED")

# =========================
# SEARCH (Firebase)
# =========================
func start_search() -> bool:
	found_servers.clear()
	if _rooms_listener_ref:
		_rooms_listener_ref.new_data_update.disconnect(_on_room_found)
	_rooms_listener_ref = Firebase.Database.get_database_reference("webrtc_rooms")
	_rooms_listener_ref.new_data_update.connect(_on_room_found)
	return true
 
 
func stop_search() -> void:
	if _rooms_listener_ref:
		_rooms_listener_ref.new_data_update.disconnect(_on_room_found)
		_rooms_listener_ref = null
 
 
func _on_room_found(resource) -> void:
	var data = resource.data
	var path = resource.key
	if typeof(data) != TYPE_DICTIONARY:
		return
		
	if path == "" or path == "/":
		for room_id in data.keys():
			if typeof(data[room_id]) == TYPE_DICTIONARY:
				_add_found_room(room_id, data[room_id])
	else:
		var room_id = path.replace("/", "")
		_add_found_room(room_id, data)

func _add_found_room(room_id: String, r: Dictionary):
	if r.get("state") == "waiting":
		var server = {
			"name": r.get("name", "Unknown"),
			"room_id": room_id,
			"ip": room_id, # store room_id in ip to avoid breaking UI that uses ip for join_game
			"player_count": 1,
			"max_players": 2,
			"port": 0
		}
		for s in found_servers:
			if s.ip == server.ip:
				return
		found_servers.append(server)
		server_found.emit(server)
 
 
# =========================
# UTILS
# =========================
func join_found_server(index: int) -> void:
	if index >= 0 and index < found_servers.size():
		join_game(found_servers[index].ip)
 
 
func get_local_ip() -> String:
	var addresses = IP.get_local_addresses()
 
	for address in addresses:
		if (
			address.begins_with("192.168")
			or address.begins_with("10.")
			or address.begins_with("172.")
		):
			return address
 
	return "127.0.0.1"
 
 
func is_connected_to_network() -> bool:
	return multiplayer.multiplayer_peer != null
 
 
# func get_saved_equipped_bag_id(pref_key: String = "equipped_bag_id") -> String:
#   var bag_id := str(PlayerData.equipped_cornbag)
#   print("the bag id is " , bag_id)
#   if BAG_CONFIGS.has(bag_id):
#       print("The new eqipped bag id is ",bag_id)
#       return bag_id
 
#   return ""
 
# new function which acess id from bag id then config from bag config
func get_saved_equipped_bag_id(pref_key: String = "equipped_bag_id") -> String:
	var item_id := str(PlayerData.equipped_cornbag).strip_edges()
 
	#print("Saved Item ID: ", item_id)
 
	# Convert S10 -> shurican
	if BAG_ID_TO_KEY.has(item_id):
		var bag_key = BAG_ID_TO_KEY[item_id]
		if BAG_CONFIGS.has(bag_key):
			return bag_key
 
	#print("Bag config not found")
	return ""
 
func get_saved_equipped_board_id(pref_key: String = "equipped_board_id") -> String:
	var item_id := str(PlayerData.equipped_board).strip_edges()
 
	print("Saved Item ID: ", item_id)
 
	# Convert S10 -> shurican
	if BOARD_ID_TO_KEY.has(item_id):
		var board_key = BOARD_ID_TO_KEY[item_id]
		if BOARD_CONFIGS.has(board_key):
			return board_key
 
	#print("Board config not found")
	return ""
 
 
func save_equipped_bag_id(bag_id: String, pref_key: String = "equipped_bag_id") -> bool:
	var normalized_bag_id := bag_id.to_lower()
	if not BAG_CONFIGS.has(normalized_bag_id):
		return false
 
	Prefs.set_string(pref_key, normalized_bag_id)
	Prefs.save()
	return true
func save_equipped_board_id(board_id: String, pref_key: String = "equipped_board_id") -> bool:
	var normalized_board_id := board_id.to_lower()
	if not BOARD_CONFIGS.has(normalized_board_id):
		return false
	Prefs.set_string(pref_key, normalized_board_id)
	Prefs.save()
	return true
 
func get_local_bag_id() -> String:
	var bag_id := get_saved_equipped_bag_id()
	if not bag_id.is_empty():
		return bag_id
 
	return HOST_DEFAULT_BAG_ID if is_host else CLIENT_DEFAULT_BAG_ID
 
func get_local_board_id() -> String:
	var board_id := get_saved_equipped_board_id()
	if not board_id.is_empty():
		return board_id
 
	return HOST_DEFAULT_BOARD_ID
 
func get_bag_config_for_player(player_index: int) -> BagConfig:
	var bag_id := get_bag_id_for_player(player_index)
	return get_bag_config_by_id(bag_id)
func get_board_config_for_player(player_index: int) -> BoardConfig:
	var board_id := get_board_id_for_player(player_index)
	return get_board_config_by_id(board_id)
 
func get_match_board_config() -> BoardConfig:
	return get_board_config_by_id(get_match_board_id())
 
func get_bag_config_by_id(bag_id: String) -> BagConfig:
	var normalized_bag_id := bag_id.to_lower()
	if BAG_CONFIGS.has(normalized_bag_id):
		return BAG_CONFIGS[normalized_bag_id] as BagConfig
 
	return BAG_CONFIGS[HOST_DEFAULT_BAG_ID] as BagConfig
func get_board_config_by_id(board_id: String) -> BoardConfig:
	var normalized_board_id := board_id.to_lower()
	if BOARD_CONFIGS.has(normalized_board_id):
		return BOARD_CONFIGS[normalized_board_id] as BoardConfig
 
	return BOARD_CONFIGS[DEFAULT_BOARD_ID] as BoardConfig
 
func get_bag_id_for_player(player_index: int) -> String:
	if GameSession.selected_mode == "Local" or GameSession.selected_mode == "Multiplayer":
		return _get_local_multiplayer_bag_id_for_player(player_index)
	if GameSession.selected_mode == "PassPlay":
		return _get_pass_play_bag_id_for_player(player_index)
 
	if player_index == 2:
		return get_alternate_bag_id(get_local_bag_id())
 
	return get_local_bag_id()
func get_board_id_for_player(player_index: int) -> String:
	return get_match_board_id()
 
func get_match_board_id() -> String:
	if GameSession.selected_mode == "Local" or GameSession.selected_mode == "Multiplayer":
		return _get_local_multiplayer_board_id()
 
	return get_local_board_id()
 
func get_alternate_bag_id(bag_id: String) -> String:
	var normalized_bag_id := bag_id.to_lower()
	if normalized_bag_id == HOST_DEFAULT_BAG_ID:
		return CLIENT_DEFAULT_BAG_ID
	if normalized_bag_id == CLIENT_DEFAULT_BAG_ID:
		return HOST_DEFAULT_BAG_ID
 
	return CLIENT_DEFAULT_BAG_ID
 
 
func _get_local_multiplayer_bag_id_for_player(player_index: int) -> String:
	var player_data := get_player_data_for_index(player_index)
	var bag_id := str(player_data.get("bag_id", "")).to_lower()
	var fallback_bag_id := HOST_DEFAULT_BAG_ID if player_index == 1 else CLIENT_DEFAULT_BAG_ID
	if not BAG_CONFIGS.has(bag_id):
		return fallback_bag_id
 
	var other_player_index := 2 if player_index == 1 else 1
	var other_player_data := get_player_data_for_index(other_player_index)
	var other_bag_id := str(other_player_data.get("bag_id", "")).to_lower()
 
	if BAG_CONFIGS.has(other_bag_id) and other_bag_id == bag_id:
		return fallback_bag_id
 
	return bag_id
func _get_local_multiplayer_board_id() -> String:
	var host_data := get_player_data_for_index(1)
	var host_board_id := str(host_data.get("board_id", "")).to_lower()
	if host_board_id.is_empty() and is_host:
		host_board_id = get_local_board_id()
	if not BOARD_CONFIGS.has(host_board_id):
		return DEFAULT_BOARD_ID
 
	var host_board_item_id := get_board_item_id_from_key(host_board_id)
	if host_board_item_id.is_empty():
		return DEFAULT_BOARD_ID
 
	var player_two_boards_owned := _get_player_two_boards_owned()
	if player_two_boards_owned.has(host_board_item_id):
		return host_board_id
 
	return DEFAULT_BOARD_ID
 
func _get_pass_play_bag_id_for_player(player_index: int) -> String:
	var player_one_bag_id := get_saved_equipped_bag_id()
	if player_one_bag_id.is_empty():
		player_one_bag_id = HOST_DEFAULT_BAG_ID
 
	if player_index == 1:
		return player_one_bag_id
 
	var player_two_bag_id := get_saved_equipped_bag_id("equipped_bag_id_p2")
	if player_two_bag_id.is_empty() or player_two_bag_id == player_one_bag_id:
		player_two_bag_id = get_alternate_bag_id(player_one_bag_id)
 
	return player_two_bag_id
func get_board_item_id_from_key(board_key: String) -> String:
	var normalized_board_key := board_key.to_lower()
	for item_id in BOARD_ID_TO_KEY.keys():
		if str(BOARD_ID_TO_KEY[item_id]).to_lower() == normalized_board_key:
			print("ITEM BOARD Id FOUND::::::::::::",item_id)
			return str(item_id)
 
	return ""
 
 
func _get_player_two_boards_owned() -> Array:
	if multiplayer and multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return PlayerData.boards_owned
 
	var player_two_data := get_player_data_for_index(2)
	var owned = player_two_data.get("boards_owned", [])
	if owned is Array:
		return owned
 
	return []
 
 
func get_player_data_for_index(player_index: int) -> Dictionary:
	if player_index == 1:
		return players.get(1, {})
 
	for peer_id in players.keys():
		if int(peer_id) != 1:
			return players.get(peer_id, {})
 
	return {}
 
 
func _clear_rematch_request_state() -> void:
	pending_rematch_requester_id = 0
	outgoing_rematch_target_id = 0
 
 
@rpc("authority", "reliable")
func room_full_rpc(message: String) -> void:
	room_join_failed.emit(message)
	disconnect_game()
 
 
func _connect_multiplayer_signals() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
 
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
 
 
func _normalize_room_id(value: String) -> String:
	return value.strip_edges().to_upper()
 
 
func _disconnect_peer(peer_id: int) -> void:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null:
		return
 
	peer.disconnect_peer(peer_id, true)
 
