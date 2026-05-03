class_name MainMenu extends Control
## Opening screen. Launches the single available battle for now.
## Phase 9 will replace New Game with a character select flow.
## Phase 10 will add a level select map between here and the battle.


func _ready() -> void:
	$VBox/NewGameBtn.pressed.connect(_on_new_game)
	$VBox/EndlessModeBtn.pressed.connect(_on_endless_mode)
	$VBox/ExitBtn.pressed.connect(_on_exit)


func _on_new_game() -> void:
	SceneManager.set_pending_mode("single")
	get_tree().change_scene_to_file("res://scenes/main_menu/character_select.tscn")


func _on_endless_mode() -> void:
	SceneManager.set_pending_mode("endless")
	get_tree().change_scene_to_file("res://scenes/main_menu/character_select.tscn")


func _on_exit() -> void:
	get_tree().quit()
