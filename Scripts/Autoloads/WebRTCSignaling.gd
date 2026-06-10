extends Node

signal room_created(room_id: String)
signal room_joined(room_id: String)
signal client_joined(client_data: Dictionary)
signal host_joined(host_data: Dictionary)
signal offer_received(sdp: String)
signal answer_received(sdp: String)
signal ice_candidate_received(media: String, index: int, name: String)

var _room_ref = null
var _room_id: String = ""
var is_host: bool = false

var _processed_host_candidates = {}
var _processed_client_candidates = {}
var _has_received_offer = false
var _has_received_answer = false

func _update_db(path: String, data: Dictionary) -> void:
	print("PATH =", path)
	print("DATA =", data)
	if _room_ref:
		_room_ref.update(path, data)

func create_room(room_id: String, room_name: String, host_data: Dictionary) -> void:
	print("[Signaling] Room Creation Check: creating room ", room_id)
	_room_id = room_id
	is_host = true
	_processed_host_candidates.clear()
	_processed_client_candidates.clear()
	_has_received_offer = false
	_has_received_answer = false
	
	_room_ref = Firebase.Database.get_database_reference("webrtc_rooms/" + _room_id)
	if not _room_ref.new_data_update.is_connected(_on_room_update):
		_room_ref.new_data_update.connect(_on_room_update)
	if not _room_ref.patch_data_update.is_connected(_on_room_update):
		_room_ref.patch_data_update.connect(_on_room_update)
	
	var data = {
		"name": room_name,
		"host_id": host_data.get("id", 1),
		"state": "waiting",
		"players": { "p1": host_data }
	}
	_update_db("", data)
	room_created.emit(room_id)

func join_room(room_id: String, client_data: Dictionary) -> void:
	print("JOIN ROOM CALLED")
	print(room_id)
	_room_id = room_id
	is_host = false
	_processed_host_candidates.clear()
	_processed_client_candidates.clear()
	_has_received_offer = false
	_has_received_answer = false
	
	_room_ref = Firebase.Database.get_database_reference("webrtc_rooms/" + _room_id)
	if not _room_ref.new_data_update.is_connected(_on_room_update):
		_room_ref.new_data_update.connect(_on_room_update)
	if not _room_ref.patch_data_update.is_connected(_on_room_update):
		_room_ref.patch_data_update.connect(_on_room_update)
	
	var join_data = {
		"players/p2": client_data,
		"state": "playing"
	}
	_update_db("", join_data)
	room_joined.emit(room_id)

func send_offer(sdp: String) -> void:
	_update_db("sdp", { "offer": sdp })
	print("OFFER SENT")

func send_answer(sdp: String) -> void:
	_update_db("sdp", { "answer": sdp })
	print("ANSWER SENT")

func send_ice_candidate(media: String, index: int, name: String) -> void:
	if not _room_ref:
		return
		
	var side = "host" if is_host else "client"
	var timestamp = str(int(Time.get_unix_time_from_system() * 1000))
	var rand_suffix = str(randi() % 10000)
	var key = timestamp + "_" + rand_suffix
	var candidate_data = {
		"media": media,
		"index": index,
		"name": name
	}
	_update_db("candidates/" + side + "/" + key, candidate_data)

func _on_room_update(resource) -> void:
	var path = str(resource.key)
	var data = resource.data
	
	print("ROOM UPDATE")
	print(resource.key)
	print(resource.data)
	
	if path == "" or path == "/":
		_process_full_data(data)
	else:
		# If it's a sub-path update, we can also process it if we want.
		# Often patch updates send pieces.
		if path.begins_with("/players/p2") or path.begins_with("players/p2"):
			print("CLIENT JOINED")
			client_joined.emit(data if typeof(data) == TYPE_DICTIONARY else {})
		elif path.begins_with("/players/p1") or path.begins_with("players/p1"):
			print("HOST JOINED")
			host_joined.emit(data if typeof(data) == TYPE_DICTIONARY else {})
		elif path == "/players" or path == "players":
			if typeof(data) == TYPE_DICTIONARY:
				if data.has("p2"):
					print("CLIENT JOINED")
					client_joined.emit(data["p2"])
				if data.has("p1"):
					print("HOST JOINED")
					host_joined.emit(data["p1"])
		elif path.begins_with("/sdp") or path.begins_with("sdp"):
			if typeof(data) == TYPE_DICTIONARY:
				if data.has("offer") and not is_host and not _has_received_offer:
					_has_received_offer = true
					offer_received.emit(data["offer"])
				if data.has("answer") and is_host and not _has_received_answer:
					_has_received_answer = true
					answer_received.emit(data["answer"])
			elif path.ends_with("offer") and not is_host and not _has_received_offer:
				_has_received_offer = true
				offer_received.emit(str(data))
			elif path.ends_with("answer") and is_host and not _has_received_answer:
				_has_received_answer = true
				answer_received.emit(str(data))
		elif path.begins_with("/candidates") or path.begins_with("candidates"):
			if is_host:
				_process_candidates(data, "client")
			else:
				_process_candidates(data, "host")

func _process_full_data(data: Dictionary) -> void:
	if is_host:
		if data.has("players") and data["players"].has("p2"):
			print("CLIENT JOINED")
			client_joined.emit(data["players"]["p2"])
		elif data.has("players/p2"):
			print("CLIENT JOINED")
			client_joined.emit(data["players/p2"])
	else:
		if data.has("players") and data["players"].has("p1"):
			print("HOST JOINED")
			host_joined.emit(data["players"]["p1"])
		elif data.has("players/p1"):
			print("HOST JOINED")
			host_joined.emit(data["players/p1"])
		
	if data.has("sdp"):
		var sdp = data["sdp"]
		if not is_host and sdp.has("offer") and not _has_received_offer:
			_has_received_offer = true
			offer_received.emit(sdp["offer"])
		if is_host and sdp.has("answer") and not _has_received_answer:
			_has_received_answer = true
			answer_received.emit(sdp["answer"])
			
	if data.has("candidates"):
		if is_host and data["candidates"].has("client"):
			_process_candidates_list(data["candidates"]["client"], "client")
		if not is_host and data["candidates"].has("host"):
			_process_candidates_list(data["candidates"]["host"], "host")

func _process_candidates(data, expected_side: String) -> void:
	if typeof(data) == TYPE_DICTIONARY:
		# If it's a list of candidates:
		if data.has("media") and data.has("index"):
			# It's a single candidate
			var processed_list = _processed_host_candidates if expected_side == "host" else _processed_client_candidates
			var key = str(data)
			if not processed_list.has(key):
				processed_list[key] = true
				ice_candidate_received.emit(data.get("media", ""), data.get("index", 0), data.get("name", ""))
		else:
			# It might be a list of candidates
			_process_candidates_list(data, expected_side)

func _process_candidates_list(candidates_dict: Dictionary, side: String) -> void:
	var processed_list = _processed_host_candidates if side == "host" else _processed_client_candidates
	for key in candidates_dict:
		if not processed_list.has(key):
			processed_list[key] = true
			var c = candidates_dict[key]
			ice_candidate_received.emit(c.get("media", ""), c.get("index", 0), c.get("name", ""))

func leave_room() -> void:
	if _room_ref:
		if _room_ref.new_data_update.is_connected(_on_room_update):
			_room_ref.new_data_update.disconnect(_on_room_update)
		if _room_ref.patch_data_update.is_connected(_on_room_update):
			_room_ref.patch_data_update.disconnect(_on_room_update)
		# Delete room if host
		if is_host:
			_room_ref.delete("")
		_room_ref = null
	_room_id = ""
