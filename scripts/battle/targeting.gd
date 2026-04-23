class_name Targeting
## Which grid coords are legal anchors for `skill` cast from `caster`?
##
## Static and stateless so the UI (highlights valid tiles) and the AI (picks
## among valid tiles) read from the same source of truth. Does NOT expand
## AOE; that's the resolver's job. This just answers "can the skill legally
## land here?"


## Return a list of Vector2i coords this skill can be anchored to from the
## caster's current position. Honors:
##   - manhattan range [min_range, max_range]
##   - target_type rules (ENEMY/ALLY/SELF/ALLY_OR_SELF/TILE/ANY)
##   - team hostility via SkillData.can_target()
## Does NOT check line-of-sight (not modeled in Alpha) or MP cost (caller's
## job — AbilityBar already filters to castable skills).
static func valid_anchors(
	grid: GridMap,
	caster: Unit,
	skill: SkillData,
	all_units: Array
) -> Array:
	var valid: Array = []
	if grid == null or caster == null or skill == null:
		return valid

	# In-range tile set is a cheap manhattan filter; refine below.
	var candidate_tiles := grid.tiles_in_range(caster.coord, skill.max_range)
	for tile in candidate_tiles:
		var dist: int = GridMap.manhattan(caster.coord, tile.coord)
		if dist < skill.min_range or dist > skill.max_range:
			continue

		var is_self: bool = (tile.coord == caster.coord)
		var target: Unit = _unit_at_coord(all_units, tile.occupant_id)

		match skill.target_type:
			SkillEnums.TargetType.SELF:
				if is_self:
					valid.append(tile.coord)
			SkillEnums.TargetType.TILE:
				# Any in-range tile; typically used for ground-target AoE.
				valid.append(tile.coord)
			SkillEnums.TargetType.ENEMY, \
			SkillEnums.TargetType.ALLY, \
			SkillEnums.TargetType.ALLY_OR_SELF, \
			SkillEnums.TargetType.ANY:
				if target == null or not target.is_alive():
					continue
				if skill.can_target(caster.team, target.team, is_self):
					valid.append(tile.coord)
	return valid


## Expand an AoE anchor into every coord the skill hits. Used by the resolver
## and by the targeting preview hover.
static func expand_area(
	skill: SkillData,
	anchor: Vector2i,
	grid: GridMap
) -> Array:
	var result: Array = [anchor]
	match skill.area_shape:
		SkillEnums.AreaShape.SINGLE:
			pass
		SkillEnums.AreaShape.CROSS:
			for offset in GridMap.NEIGHBOR_OFFSETS:
				var c: Vector2i = anchor + offset
				if grid.is_in_bounds(c):
					result.append(c)
		SkillEnums.AreaShape.SQUARE:
			for dy in range(-skill.area_size, skill.area_size + 1):
				for dx in range(-skill.area_size, skill.area_size + 1):
					if dx == 0 and dy == 0:
						continue
					var c: Vector2i = anchor + Vector2i(dx, dy)
					if grid.is_in_bounds(c):
						result.append(c)
		SkillEnums.AreaShape.RADIUS:
			for tile in grid.tiles_in_range(anchor, skill.area_size):
				if tile.coord != anchor:
					result.append(tile.coord)
		SkillEnums.AreaShape.LINE:
			# Not used by any Alpha skill; stub for when directional skills land.
			pass
	return result


# =============================================================================
# HELPERS
# =============================================================================

static func _unit_at_coord(all_units: Array, occupant_id: StringName) -> Unit:
	if occupant_id == &"":
		return null
	for unit in all_units:
		if unit != null and unit.unit_id == occupant_id:
			return unit
	return null
