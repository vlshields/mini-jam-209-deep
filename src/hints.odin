package game

import "vendor:raylib"

Hint_Kind :: enum {
	Dash_Slam,
	Weapons_Vs_Stats,
	Wave_Seven_Reward,
}

HINT_COUNT              :: len(Hint_Kind)
HINT_BODY_LINES         :: 2
HINT_AUTOCLOSE_DURATION :: f32(8.0)

HINT_TRIGGER_TIME : [Hint_Kind]f32 = {
	.Dash_Slam         = 6.0,
	.Weapons_Vs_Stats  = 25.0,
	.Wave_Seven_Reward = 50.0,
}

HINT_TITLES : [Hint_Kind]cstring = {
	.Dash_Slam         = "Dash Slam",
	.Weapons_Vs_Stats  = "Upgrades",
	.Wave_Seven_Reward = "Hidden Reward",
}

HINT_BODIES : [Hint_Kind][HINT_BODY_LINES]cstring = {
	.Dash_Slam = {
		"While airborne, dash downwards toward",
		"an enemy to perform a devastating slam!",
	},
	.Weapons_Vs_Stats = {
		"Weapon upgrades give you new abilities.",
		"Player upgrades boost your stats!",
	},
	.Wave_Seven_Reward = {
		"If you can make it past 7 enemy waves,",
		"there may be a special reward for you.",
	},
}

input_hint_dismiss :: proc() -> bool {
	if raylib.IsKeyPressed(.C) {
		return true
	}
	if gamepad_active() && raylib.IsGamepadButtonPressed(GAMEPAD_ID, .MIDDLE_LEFT) {
		return true
	}
	return false
}
