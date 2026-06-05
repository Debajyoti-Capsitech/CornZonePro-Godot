extends Node

func _ready() -> void:
	UIManager.single_setup(
		$"InGame UI",
		$PauseMenu,
		$GameOver
	)
	UIManager.enable_canvas($"InGame UI")

