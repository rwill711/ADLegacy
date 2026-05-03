class_name StructureManager extends Node
## Tracks all structures placed on the current map.
## Answers: "is this unit at an approach tile?" so main.gd can show Enter.


## Placed entry: {data: StructureData, origin: Vector2i, looted: bool}
var _placed: Array = []


func clear() -> void:
	_placed.clear()


func register(data: StructureData, origin: Vector2i) -> void:
	_placed.append({"data": data, "origin": origin, "looted": false})


## Returns the placed entry whose approach coord matches `coord`, or {}.
func entry_at_approach(coord: Vector2i) -> Dictionary:
	for entry in _placed:
		var data: StructureData = entry["data"]
		if data.entrance_coord(entry["origin"]) == coord:
			return entry
	return {}


## Mark a structure as looted so Enter no longer offers loot.
func mark_looted(entry: Dictionary) -> void:
	entry["looted"] = true


func get_all() -> Array:
	return _placed.duplicate()
