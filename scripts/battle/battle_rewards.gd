class_name BattleRewards extends Node
## Accumulates loot collected during a battle (enemy drops + chest opens).
## Attach as a child of the battle scene root; main.gd clears it on _ready.


var _drops: Array = []   # Array[{tag, source}]  source="chest"|unit_id


func clear() -> void:
	_drops.clear()


func add_drop(tag: String, source: String) -> void:
	_drops.append({"tag": tag, "source": source})
	print("[loot] +%s from %s" % [tag, source])


func get_all_drops() -> Array:
	return _drops.duplicate()


## Summarise drops as {tag → count} for display.
func get_summary() -> Dictionary:
	var out: Dictionary = {}
	for d in _drops:
		var tag: String = d["tag"]
		out[tag] = out.get(tag, 0) + 1
	return out


func is_empty() -> bool:
	return _drops.is_empty()
