package game

import "vendor:raylib"

Sound_Kind :: enum {
	Player_Jump,
	Player_Dash,
	Player_Dash_Ground_Impact,
	Player_Footsteps,
	Player_Base_Melee_Attacks,
	Player_Base_Special_Attack,
	Waterblade_Attack,
	Water_Orb_Spawns,
	Water_Orb_Attack,
	Enemy_Devil_Attacks,
	Enemy_Soldier_Attacks,
	Enemy_Dies,
	Hit,
	UI_Confirm,
	UI_Negative_Back,
	You_Died,
}

@(private = "file")
SOUND_PATHS := [Sound_Kind]cstring{
	.Player_Jump                = "assets/audio/sfx/player_jump.wav",
	.Player_Dash                = "assets/audio/sfx/player_dash.wav",
	.Player_Dash_Ground_Impact  = "assets/audio/sfx/player_dash_ground_impact.wav",
	.Player_Footsteps           = "assets/audio/sfx/player_footsteps.wav",
	.Player_Base_Melee_Attacks  = "assets/audio/sfx/player_base_melee_attacks.wav",
	.Player_Base_Special_Attack = "assets/audio/sfx/player_base_special_attack.wav",
	.Waterblade_Attack          = "assets/audio/sfx/waterblade_attack.wav",
	.Water_Orb_Spawns           = "assets/audio/sfx/water_orb_spawns.wav",
	.Water_Orb_Attack           = "assets/audio/sfx/water_orb_attack.wav",
	.Enemy_Devil_Attacks        = "assets/audio/sfx/enemy_devil_attacks.wav",
	.Enemy_Soldier_Attacks      = "assets/audio/sfx/enemy_soldier_attacks.wav",
	.Enemy_Dies                 = "assets/audio/sfx/enemy_dies.wav",
	.Hit                        = "assets/audio/sfx/hit.wav",
	.UI_Confirm                 = "assets/audio/sfx/ui_confirm.wav",
	.UI_Negative_Back           = "assets/audio/sfx/ui_negative-back.wav",
	.You_Died                   = "assets/audio/sfx/you_died.wav",
}

@(private = "file")
SOUND_VOLUMES := [Sound_Kind]f32{
	.Player_Jump                = 0.55,
	.Player_Dash                = 0.55,
	.Player_Dash_Ground_Impact  = 0.7,
	.Player_Footsteps           = 0.30,
	.Player_Base_Melee_Attacks  = 0.55,
	.Player_Base_Special_Attack = 0.55,
	.Waterblade_Attack          = 0.55,
	.Water_Orb_Spawns           = 0.55,
	.Water_Orb_Attack           = 0.55,
	.Enemy_Devil_Attacks        = 0.50,
	.Enemy_Soldier_Attacks      = 0.50,
	.Enemy_Dies                 = 0.55,
	.Hit                        = 0.55,
	.UI_Confirm                 = 0.55,
	.UI_Negative_Back           = 0.55,
	.You_Died                   = 0.7,
}

FOOTSTEP_INTERVAL :: 0.27

@(private = "file")
sounds: [Sound_Kind]raylib.Sound

@(private = "file")
audio_initialized: bool

@(private = "file")
footstep_timer: f32

@(private = "file")
master_sfx_volume: f32 = 1.0

set_master_sfx_volume :: proc(v: f32) {
	master_sfx_volume = clamp(v, 0, 1)
	if !audio_initialized {
		return
	}
	for kind in Sound_Kind {
		raylib.SetSoundVolume(sounds[kind], SOUND_VOLUMES[kind] * master_sfx_volume)
	}
}

get_master_sfx_volume :: proc() -> f32 {
	return master_sfx_volume
}

init_audio :: proc() {
	for kind in Sound_Kind {
		sounds[kind] = raylib.LoadSound(SOUND_PATHS[kind])
		raylib.SetSoundVolume(sounds[kind], SOUND_VOLUMES[kind] * master_sfx_volume)
	}
	audio_initialized = true
	footstep_timer = 0
}

unload_audio :: proc() {
	if !audio_initialized {
		return
	}
	for kind in Sound_Kind {
		raylib.UnloadSound(sounds[kind])
	}
	audio_initialized = false
}

play_sound :: proc(kind: Sound_Kind) {
	if !audio_initialized {
		return
	}
	raylib.PlaySound(sounds[kind])
}

update_footsteps :: proc(active: bool, dt: f32) {
	if !active {
		footstep_timer = 0
		return
	}
	footstep_timer -= dt
	if footstep_timer <= 0 {
		play_sound(.Player_Footsteps)
		footstep_timer = FOOTSTEP_INTERVAL
	}
}

