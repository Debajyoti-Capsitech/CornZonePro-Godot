extends Resource
class_name MapConfig

@export_group("Basic")
@export var map_name: String = ""

@export_group("Gameplay")
@export var time_limit: float = 20.0
@export var wind_strength: float = 0.0
@export var coin_reward: int = 10

@export_group("Modes")
@export var supports_single_player: bool = false
@export var supports_pass_and_play: bool = false

@export_group("Unlock")
@export var single_player_unlocked: bool = false
@export var pass_and_play_unlocked: bool = false

@export_group("Price")
@export var single_player_cost: int
@export var pass_and_play_cost: int


func get_unlock_pref_key(mode: String) -> String:
	var safe_map_name := map_name.to_lower().replace(" ", "_")

	match mode:
		"Single", "VSBot":
			return "map_unlock_single_%s" % safe_map_name
		"PassPlay":
			return "map_unlock_passplay_%s" % safe_map_name
		_:
			return ""


func _get_resource_unlock_value(mode: String) -> bool:
	match mode:
		"Single", "VSBot":
			return single_player_unlocked
		"PassPlay":
			return pass_and_play_unlocked
		_:
			return true


func _set_resource_unlock_value(mode: String, unlocked: bool) -> void:
	match mode:
		"Single", "VSBot":
			single_player_unlocked = unlocked
		"PassPlay":
			pass_and_play_unlocked = unlocked


func supports_mode(mode: String) -> bool:
	match mode:
		"Single", "VSBot":
			return supports_single_player
		"PassPlay":
			return supports_pass_and_play
		_:
			return true


func is_unlocked_for_mode(mode: String) -> bool:
	var pref_key := get_unlock_pref_key(mode)
	if not pref_key.is_empty():
		var default_value := int(_get_resource_unlock_value(mode))
		return bool(Prefs.get_int(pref_key, default_value))

	return _get_resource_unlock_value(mode)


func set_unlocked_for_mode(mode: String, unlocked: bool) -> void:
	var pref_key := get_unlock_pref_key(mode)
	_set_resource_unlock_value(mode, unlocked)
	emit_changed()

	var resource_save_succeeded := false
	if not resource_path.is_empty():
		var save_error := ResourceSaver.save(self, resource_path)
		resource_save_succeeded = save_error == OK
		if not resource_save_succeeded:
			push_warning("[MapConfig] Failed to save %s (%s). Falling back to Prefs." % [resource_path, error_string(save_error)])

	if pref_key.is_empty():
		return

	if resource_save_succeeded:
		if Prefs.has_key(pref_key):
			Prefs.delete_key(pref_key)
			Prefs.save()
		return

	Prefs.set_int(pref_key, int(unlocked))
	Prefs.save()


func get_price_for_mode(mode: String) -> int:
	match mode:
		"Single", "VSBot":
			return single_player_cost
		"PassPlay":
			return pass_and_play_cost
		_:
			return 0


func is_available_for_mode(mode: String) -> bool:
	return supports_mode(mode) and is_unlocked_for_mode(mode)


func get_unavailable_reason(mode: String) -> String:
	var safe_map_name := map_name if not map_name.is_empty() else "This map"

	match mode:
		"Single":
			if not supports_single_player:
				return "%s is not available in Single mode." % safe_map_name
			if not is_unlocked_for_mode(mode):
				return "%s is locked for Single mode." % safe_map_name
		"VSBot":
			if not supports_single_player:
				return "%s is not available in VS Bot mode." % safe_map_name
			if not is_unlocked_for_mode(mode):
				return "%s is locked for VS Bot mode." % safe_map_name
		"PassPlay":
			if not supports_pass_and_play:
				return "%s is not available in Pass & Play." % safe_map_name
			if not is_unlocked_for_mode(mode):
				return "%s is locked for Pass & Play." % safe_map_name
		_:
			if mode.is_empty():
				return "Select a game mode first."
			return "%s is not available for %s." % [safe_map_name, mode]

	return ""
