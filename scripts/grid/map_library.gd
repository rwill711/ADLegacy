class_name MapLibrary
## Catalog of named MapTemplates available for battle setup.
## Add new templates here as more map types are developed.


## Returns all templates in display order.
static func all_templates() -> Array:  # Array[MapTemplate]
	return [
		open_field(),
		forest(),
		highland(),
		wetlands(),
		ruins(),
	]


## Look up a template by name. Returns open_field() if not found.
static func get_template(name: String) -> MapTemplate:
	for t in all_templates():
		if t.template_name == name:
			return t
	push_warning("MapLibrary: unknown template '%s', using Open Field" % name)
	return open_field()


# =============================================================================
# TEMPLATE DEFINITIONS
# =============================================================================

static func open_field() -> MapTemplate:
	return MapTemplate.create(
		"Open Field",
		"Sparse terrain — ideal for straightforward skirmishes.",
		3,   # trees
		2,   # rocks
		6,   # water
		3,   # hill_size
		0.70, 0.25
	)


static func forest() -> MapTemplate:
	return MapTemplate.create(
		"Forest",
		"Dense tree cover limits sightlines and mobility.",
		10,  # trees
		2,   # rocks
		5,   # water
		0,   # no stone hill — trees dominate
		0.60, 0.30
	)


static func highland() -> MapTemplate:
	return MapTemplate.create(
		"Highland",
		"Rocky, elevated terrain rewards high-ground positioning.",
		3,   # trees
		8,   # rocks
		4,   # water
		3,   # hill_size
		0.40, 0.40  # more elevated tiles overall
	)


static func wetlands() -> MapTemplate:
	return MapTemplate.create(
		"Wetlands",
		"Extensive water hazards slow movement and split the field.",
		4,   # trees
		2,   # rocks
		16,  # water — large connected marsh
		0,   # no hill
		0.75, 0.20
	)


static func ruins() -> MapTemplate:
	return MapTemplate.create(
		"Ruins",
		"Crumbling stone structures — heavy rock cover, uneven ground.",
		2,   # trees
		10,  # rocks
		3,   # water
		3,   # hill_size
		0.50, 0.35
	)
