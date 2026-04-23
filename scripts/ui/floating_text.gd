class_name FloatingText extends Node3D
## A world-space damage/heal/buff number that tweens upward above a target
## and fades out, then queue_frees itself.
##
## Uses a Label3D so the number billboards toward the camera regardless of
## camera rotation — stays readable after Q/E camera spins.


@export var lifetime_seconds: float = 1.0
@export var rise_height: float = 1.2


var _label: Label3D = null


func _ready() -> void:
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 64
	_label.outline_size = 16
	_label.outline_modulate = Color(0, 0, 0, 0.85)
	_label.no_depth_test = true
	add_child(_label)


## Show `text` in `color` at world position `start_pos`. Self-destructs when done.
func show_text(text: String, color: Color, start_pos: Vector3) -> void:
	global_position = start_pos
	if _label == null:
		# _ready hasn't fired yet — set on next frame.
		await get_tree().process_frame
	_label.text = text
	_label.modulate = color

	var end_pos: Vector3 = start_pos + Vector3(0, rise_height, 0)

	var t := create_tween()
	t.set_parallel(true)
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self, "global_position", end_pos, lifetime_seconds)
	t.tween_property(_label, "modulate:a", 0.0, lifetime_seconds) \
		.set_delay(lifetime_seconds * 0.4)

	await t.finished
	queue_free()


# =============================================================================
# FACTORY — called by the action controller / AI
# =============================================================================

## Spawn a floating-text node in `parent`, show the text, fire-and-forget.
static func spawn(
	parent: Node,
	text: String,
	color: Color,
	world_position: Vector3
) -> FloatingText:
	var ft := FloatingText.new()
	parent.add_child(ft)
	ft.show_text(text, color, world_position)
	return ft
