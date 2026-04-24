## Global enumerations for ADLegacy.

enum JobClass {
	NONE,
	WARRIOR,
	MAGE,
	ARCHER,
	CLERIC,
	THIEF,
}

enum UnitFaction {
	PLAYER,
	ENEMY,
	NEUTRAL,
}

enum TileType {
	FLAT,
	ELEVATED,
	WALL,
	WATER,
	VOID,
}

enum BattlePhase {
	SETUP,
	PLAYER_TURN,
	ENEMY_TURN,
	RESOLUTION,
	END,
}

enum SkillCategory {
	PHYSICAL,
	MAGICAL,
	SUPPORT,
	REACTION,
}
