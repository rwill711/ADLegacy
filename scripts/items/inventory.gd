class_name Inventory extends Resource
## A unit's consumable item bag. Holds a list of ItemData (consumables only)
## that can be used during battle. Items are consumed on use (removed from
## the bag).
##
## DESIGN NOTES:
## - Inventory is separate from Equipment. Equipment = passive gear in slots.
##   Inventory = active consumables used as a battle action.
## - Max capacity is capped to prevent hoarding. Alpha default: 6 items.
## - Items are stored as an ordered Array. The UI renders them in order;
##   the battle system indexes by position or item name.
## - Duplicate item types are allowed (you can carry 3 Health Potions).


## --- Config -----------------------------------------------------------------
const DEFAULT_MAX_SIZE: int = 6

var max_size: int = DEFAULT_MAX_SIZE


## --- Storage ----------------------------------------------------------------
var _items: Array = []  # Array[ItemData]


# =============================================================================
# ADD / REMOVE
# =============================================================================

## Add a consumable to the inventory. Returns true on success, false if full
## or if the item is not a consumable.
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


## Remove and return the item at a specific index. Returns null if invalid.
func remove_at(index: int) -> ItemData:
	if index < 0 or index >= _items.size():
		return null
	var item: ItemData = _items[index]
	_items.remove_at(index)
	return item


## Remove the first item matching a name. Returns the removed item or null.
func remove_by_name(item_name: StringName) -> ItemData:
	for i in _items.size():
		if _items[i].item_name == item_name:
			return remove_at(i)
	return null


## Consume (remove) a specific item instance. Used by ItemResolver after
## successful use. Returns true if the item was found and removed.
func consume(item: ItemData) -> bool:
	var idx: int = _items.find(item)
	if idx == -1:
		return false
	_items.remove_at(idx)
	return true


## Clear all items.
func clear() -> void:
	_items.clear()


# =============================================================================
# QUERIES
# =============================================================================

## All items in the bag (read-only copy).
func get_all_items() -> Array:
	return _items.duplicate()


## Get item at index without removing it.
func get_item_at(index: int) -> ItemData:
	if index < 0 or index >= _items.size():
		return null
	return _items[index]


## Get first item matching a name without removing it.
func get_item_by_name(item_name: StringName) -> ItemData:
	for item in _items:
		if item.item_name == item_name:
			return item
	return null


## How many items are currently in the bag.
func get_count() -> int:
	return _items.size()


## How many of a specific item type are in the bag.
func count_by_name(item_name: StringName) -> int:
	var n: int = 0
	for item in _items:
		if item.item_name == item_name:
			n += 1
	return n


## Is the bag full?
func is_full() -> bool:
	return _items.size() >= max_size


## Is the bag empty?
func is_empty() -> bool:
	return _items.is_empty()


## Does the bag contain at least one item with this name?
func has_item(item_name: StringName) -> bool:
	return get_item_by_name(item_name) != null


## Get all unique item names and their counts. Useful for compact UI display.
## Returns Array of {item: ItemData, count: int} sorted by first occurrence.
func get_stacked_summary() -> Array:
	var seen: Dictionary = {}  # StringName → index in output array
	var out: Array = []
	for item in _items:
		if seen.has(item.item_name):
			out[seen[item.item_name]]["count"] += 1
		else:
			seen[item.item_name] = out.size()
			out.append({"item": item, "count": 1})
	return out


# =============================================================================
# DEBUG
# =============================================================================

func get_summary() -> String:
	if _items.is_empty():
		return "  (empty)"
	var lines: Array = []
	for entry in get_stacked_summary():
		var item: ItemData = entry["item"]
		var count: int = entry["count"]
		if count > 1:
			lines.append("  %s x%d" % [item.display_name, count])
		else:
			lines.append("  %s" % item.display_name)
	return "\n".join(lines)
