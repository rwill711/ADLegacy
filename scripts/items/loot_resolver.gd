class_name LootResolver
## Rolls a LootTable and returns an Array of item tag strings that dropped.


static func roll(table: LootTable, rng: RandomNumberGenerator = null) -> Array:
	if table == null or table.entries.is_empty():
		return []
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var drops: Array = []
	for _r in table.rolls:
		if rng.randi_range(1, 100) > table.drop_chance:
			continue
		var tag: String = _weighted_pick(table.entries, rng)
		if tag != "":
			drops.append(tag)
	return drops


static func _weighted_pick(entries: Array, rng: RandomNumberGenerator) -> String:
	var total: int = 0
	for e in entries:
		total += int(e.get("weight", 1))
	if total <= 0:
		return ""
	var roll: int = rng.randi_range(1, total)
	var running: int = 0
	for e in entries:
		running += int(e.get("weight", 1))
		if roll <= running:
			return String(e.get("tag", ""))
	return ""
