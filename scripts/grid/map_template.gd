class_name MapTemplate extends Resource
## Describes the parameters for procedural battlefield generation.
## MapBuilder consumes this to produce a BattleGrid.


@export var template_name: String = "Open Field"
@export var description: String = ""

## Grid dimensions.
@export var width: int = 12
@export var height: int = 12

## --- Terrain counts ---------------------------------------------------------
@export var tree_count: int = 5    ## FOREST tiles scattered randomly.
@export var rock_count: int = 4    ## MOUNTAIN tiles scattered randomly.
@export var water_count: int = 9   ## WATER tiles placed as a connected cluster.

## --- Hill config ------------------------------------------------------------
## Set hill_size = 0 to disable the fixed stone hill entirely.
@export var hill_origin: Vector2i = Vector2i(5, 5)
@export var hill_size: int = 3    ## NxN block of STONE at hill_elevation.
@export var hill_elevation: int = 1

## --- Elevation randomization ------------------------------------------------
## Probability thresholds (cumulative) for height 0, 1, 2 on non-reserved tiles.
## Must sum ≤ 1.0; remainder is treated as height 2.
@export var elev_flat_chance: float = 0.65   ## P(height == 0)
@export var elev_mid_chance: float  = 0.30   ## P(height == 1)
## P(height == 2) = 1 - flat - mid


static func create(
	p_name: String,
	p_desc: String,
	p_trees: int,
	p_rocks: int,
	p_water: int,
	p_hill_size: int = 3,
	p_elev_flat: float = 0.65,
	p_elev_mid: float = 0.30
) -> MapTemplate:
	var t := MapTemplate.new()
	t.template_name  = p_name
	t.description    = p_desc
	t.tree_count     = p_trees
	t.rock_count     = p_rocks
	t.water_count    = p_water
	t.hill_size      = p_hill_size
	t.elev_flat_chance = p_elev_flat
	t.elev_mid_chance  = p_elev_mid
	return t
