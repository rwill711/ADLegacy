class_name LootTable extends Resource
## Weighted drop table. Each entry: { "tag": String, "weight": int }.
## LootResolver.roll() samples this to produce a list of item tags.


## Entries: Array[Dictionary] where each dict has "tag" and "weight".
@export var entries: Array = []

## How many independent rolls to make. Each roll independently hits or misses.
@export var rolls: int = 1

## 0–100. Chance (%) each roll actually produces a drop. 100 = always drops.
@export var drop_chance: int = 100


static func create(p_entries: Array, p_rolls: int = 1, p_chance: int = 100) -> LootTable:
	var t := LootTable.new()
	t.entries     = p_entries
	t.rolls       = p_rolls
	t.drop_chance = p_chance
	return t
