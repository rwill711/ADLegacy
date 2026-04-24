class_name MainMenu extends Control
## Opening screen. Simple New Game / Exit entry point.


func _ready() -> void:
	$VBox/NewGameBtn.pressed.connect(_on_new_game)
	$VBox/ExitBtn.pressed.connect(_on_exit)


func _on_new_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_exit() -> void:
	get_tree().quit()
