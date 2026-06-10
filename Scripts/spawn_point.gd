extends Node3D

@export var bag: PackedScene

var bag_counter := 0


func _ready() -> void:
	bag_counter = 0
	_clear_spawned_bags()

	if (GameSession.selected_mode == "Local" or GameSession.selected_mode == "Multiplayer") and multiplayer and multiplayer.multiplayer_peer != null:
		if multiplayer.is_server():
			$"../StartTimer".start()
		else:
			$"../StartTimer".stop()
	elif GameSession.selected_mode == "VSBot":
		$"../StartTimer".stop()
	else:
		$"../StartTimer".start()


func _clear_spawned_bags() -> void:
	for child in get_children():
		child.queue_free()


func _get_waiting_bag() -> Node:
	for child in get_children():
		if not is_instance_valid(child):
			continue
		if not child.has_method("is_waiting_for_throw"):
			continue
		if bool(child.call("is_waiting_for_throw")):
			return child
	return null


func spawn_bag(player_index: int = GameSession.current_turn):
	if has_node("/root/AnimateManager"):
		AnimateManager.start_camera_return()

	var waiting_bag := _get_waiting_bag()
	if waiting_bag != null:
		return waiting_bag

	var obj = bag.instantiate()

	obj.name = "CornBag_%d" % bag_counter
	obj.set_meta("bag_spawn_index", bag_counter)

	bag_counter += 1

	obj.rotation_degrees = Vector3(-87.8, 0, 90)

	obj.set_meta("throw_player", player_index)

	add_child(obj)

	print("SPAWNED:", obj.get_path())

	return obj


@rpc("authority", "reliable")
func spawn_bag_rpc(player_index: int) -> void:
	if multiplayer and multiplayer.is_server():
		return

	spawn_bag(player_index)


func _on_timer_timeout() -> void:
	$"../StartTimer".stop()

	if (GameSession.selected_mode == "Local" or GameSession.selected_mode == "Multiplayer") and multiplayer and multiplayer.multiplayer_peer != null:
		if multiplayer.is_server():
			var player_index := GameSession.current_turn
			spawn_bag(player_index)
			spawn_bag_rpc.rpc(player_index)
		return

	spawn_bag()
