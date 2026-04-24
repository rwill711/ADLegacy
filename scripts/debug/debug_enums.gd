class_name DebugEnums
## Shared constants for the debug system.
## LogCategory values are strings so user systems can invent new ones without
## touching enum wiring — the debug log accepts any category tag.


## --- Canonical category tags used by built-in systems. ----------------------
## External/future systems can register new ones just by using new strings.
const CATEGORY_SYSTEM: String   = "system"
const CATEGORY_COMBAT: String   = "combat"
const CATEGORY_MOVEMENT: String = "movement"
const CATEGORY_TURN: String     = "turn"
const CATEGORY_FOIL: String     = "foil"
const CATEGORY_AI: String       = "ai"
const CATEGORY_CONSOLE: String  = "console"

## Colors for console / log panel rendering. Keyed by category tag.
const CATEGORY_COLORS: Dictionary = {
	CATEGORY_SYSTEM:   Color(0.85, 0.85, 0.85),
	CATEGORY_COMBAT:   Color(1.0, 0.55, 0.55),
	CATEGORY_MOVEMENT: Color(0.55, 0.85, 1.0),
	CATEGORY_TURN:     Color(0.95, 0.9, 0.5),
	CATEGORY_FOIL:     Color(0.7, 1.0, 0.55),
	CATEGORY_AI:       Color(1.0, 0.65, 1.0),
	CATEGORY_CONSOLE:  Color(1.0, 1.0, 1.0),
}

const DEFAULT_CATEGORY_COLOR: Color = Color(0.85, 0.85, 0.85)


static func category_color(category: String) -> Color:
	return CATEGORY_COLORS.get(category, DEFAULT_CATEGORY_COLOR)
