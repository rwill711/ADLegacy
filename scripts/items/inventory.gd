class_name Inventory extends Resource
## A unit's consumable item bag. Holds ItemData consumables used during battle.
## Items are consumed on use (removed from the bag). Max capacity: 6 items.


const DEFAULT_MAX_SIZE: int = 6

var max_size: int = DEFAULT_MAX_SIZE
var _items: Array = []


# =============================================================================
# ADD / REMOVE
# =============================================================================

func add_item(item: ItemData) -> bool:
	if item == null:
		push_error("Inventory.add_item: null item")
		return false
	if not item.is_consumable():
		push_error("Inventory.add_item: '%s' is not a consumable" % item.item_name)
		return false
	if _items.size() >= max_size:
		push_warning("Inventory.add_item: bag full (%d/%d)" % [_items.size(), max_size])
		return false
	_items.append(item)
	return true


func remove_at(index: int) -> ItemData:
	if index < 0 or index >= _items.size():
		return null
	var item: ItemData = _items[index]
	_items.remove_at(index)
	return item


func remove_by_name(item_name: StringName) -> ItemData:
	for i in _items.size():
		if _items[i].item_name == item_name:
			return remove_at(i)
	return null


func consume(item: ItemData) -> bool:
	var idx: int = _items.find(item)
	if idx == -1:
		return false
	_items.remove_at(idx)
	return true


func clear() -> void:
	_items.clear()


# =============================================================================
# QUERIES
# =============================================================================

func get_all_items() -> Array:
	return _items.duplicate()


func get_item_at(index: int) -> ItemData:
	if index < 0 or index >= _items.size():
		return null
	return _items[index]


func get_item_by_name(item_name: StringName) -> ItemData:
	for item in _items:
		if item.item_name == item_name:
			return item
	return null


func get_count() -> int:
	return _items.size()


func count_by_name(item_name: StringName) -> int:
	var n: int = 0
	for item in _items:
		if item.item_name == item_name:
			n += 1
	return n


func is_full() -> bool:
	return _items.size() >= max_size


func is_empty() -> bool:
	return _items.is_empty()


func has_item(item_name: StringName) -> bool:
	return get_item_by_name(item_name) != null


func get_stacked_summary() -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for item in _items:
		if seen.has(item.item_name):
			out[seen[item.item_name]]["count"] += 1
		else:
			seen[item.item_name] = out.size()
			out.append({"item": item, "count": 1})
	return out
