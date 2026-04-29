package game

SCREEN_WIDTH  :: 640 // px
SCREEN_HEIGHT :: 360 // px
TILE_SIZE     :: 16  // px
TARGET_FPS    :: 60  // frames/s

PLAYER_SPEED   :: 120.0  // px/s
GRAVITY        :: 500.0  // px/s^2
JUMP_VELOCITY  :: -220.0 // px/s (negative = up)
MAX_FALL_SPEED :: 400.0  // px/s
MAX_JUMPS      :: 2      // count

PLAYER_HITBOX_W :: 8  // px
PLAYER_HITBOX_H :: 14 // px

SPRITE_SRC_SIZE :: 16 // px
SPRITE_DST_SIZE :: 16 // px

ANIM_FRAME_TIME :: 0.172 // s/frame

DASH_SPEED         :: 800.0 // px/s
DASH_DURATION      :: 0.15  // s
DASH_COOLDOWN      :: 0.5   // s
MAX_DASH_PARTICLES :: 64    // count

DASH_DOWN_SPEED    :: 900.0 // px/s
DASH_IMPACT_SIZE   :: 32    // px
DASH_IMPACT_DAMAGE :: 36.0  // HP
DASH_IMPACT_FPS    :: 18.0  // frames/s

SCREENSHAKE_DURATION  :: 0.1 // s
SCREENSHAKE_MAGNITUDE :: 1.5 // px

QUICK_ATTACK_SRC_SIZE     :: 32   // px
QUICK_ATTACK_FPS          :: 12.0 // frames/s
QUICK_ATTACK_DAMAGE_1     :: 8.0  // HP
QUICK_ATTACK_DAMAGE_2     :: 16.0 // HP
QUICK_ATTACK_COOLDOWN     :: 0.0  // s
QUICK_ATTACK_CHAIN_WINDOW :: 3    // frames before anim end when chain input is accepted
QUICK_ATTACK_HIT_FRAME    :: 3    // frame index that applies damage

DOUBLE_STRIKE_CHANCE :: 0.13 // probability (0..1)

WATERBLADE_SRC_SIZE     :: 32   // px
WATERBLADE_IDLE_FPS     :: 8.0  // frames/s
WATERBLADE_ATTACK_FPS   :: 12.0 // frames/s
WATERBLADE_DAMAGE       :: 30.0 // HP
WATERBLADE_CRIT_CHANCE  :: 0.04 // probability (0..1)
WATERBLADE_STAMINA_COST :: 10.0 // stamina
WATERBLADE_HIT_FRAME    :: 4    // frame index that applies damage
WATERBLADE_OFFSET_X     :: 14.0 // px
WATERBLADE_OFFSET_Y     :: 0.0  // px (nudge from player-sprite center, positive = up)

WATERORB_SRC_SIZE        :: 32   // px
WATERORB_SPAWN_FPS       :: 12.0 // frames/s
WATERORB_ATTACK_FPS      :: 12.0 // frames/s
WATERORB_DAMAGE          :: 40.0 // HP
WATERORB_SLOW_CHANCE     :: 0.20 // probability (0..1)
WATERORB_FLIGHT_DURATION :: 1.6  // s
WATERORB_STAMINA_COST    :: 15.0 // stamina

TWISTER_SRC_SIZE         :: 32    // px
TWISTER_DAMAGE           :: 20.0  // HP
TWISTER_BACKSTAB_BONUS   :: 0.18  // damage fraction (0..1)
TWISTER_RANGE            :: 90.0  // px
TWISTER_OUT_DURATION     :: 0.45  // s
TWISTER_RETURN_MAX_SPEED :: 360.0 // px/s
TWISTER_RETURN_ACCEL     :: 0.22  // s (ease-in duration to max return speed)
TWISTER_RETURN_STOP_DIST :: 4.0   // px
TWISTER_ANIM_FPS         :: 14.0  // frames/s
TWISTER_STAMINA_COST     :: 15.0  // stamina

SLUDGE_SLOW_DURATION :: 2.0 // s
SLUDGE_SLOW_FACTOR   :: 0.5 // speed multiplier (0..1)

PROJECTILE_RANGE            :: 90.0  // px
PROJECTILE_DAMAGE           :: 9.0   // HP
PROJECTILE_OUT_DURATION     :: 0.45  // s
PROJECTILE_RETURN_MAX_SPEED :: 360.0 // px/s
PROJECTILE_RETURN_ACCEL     :: 0.22  // s (ease-in duration to max return speed)
PROJECTILE_SRC_SIZE         :: 8     // px
PROJECTILE_ANIM_FPS         :: 14.0  // frames/s
PROJECTILE_RETURN_STOP_DIST :: 4.0   // px

PLAYER_MAX_HP          :: 100.0 // HP
PLAYER_MAX_STAMINA     :: 50.0     // stamina
PLAYER_INVULN_DURATION :: 0.6      // s
DAMAGE_FLASH_DURATION  :: 0.1      // s

DASH_STAMINA_COST  :: 5.0 // stamina
STAMINA_REGEN_RATE :: 5.0 // stamina/s

CRIT_DAMAGE_MULTIPLIER :: 4.0 // multiplier


SLUDGE_SRC_SIZE           :: 16    // px
SLUDGE_HITBOX_W           :: 14    // px
SLUDGE_HITBOX_H           :: 14    // px
SLUDGE_HP                 :: 30.0  // HP
SLUDGE_DAMAGE             :: 16.0  // HP
SLUDGE_SPEED              :: 80.0  // px/s
SLUDGE_ATTACK_COOLDOWN    :: 3.0   // s
SLUDGE_ANIM_FPS           :: 10.0  // frames/s
SLUDGE_DEATH_DURATION     :: 0.3   // s
SLUDGE_STAGGER_DURATION   :: 0.15  // s
SLUDGE_STAGGER_KNOCKBACK  :: 120.0 // px/s
MAX_SLUDGE_SLOTS          :: 40    // count
MAX_SLUDGE_ALIVE          :: 8     // count

WAVE_BASE_SLUDGES         :: 18    // count
WAVE_SLUDGE_INCREMENT     :: 2     // count/wave
WAVE_LAST_INCREMENT       :: 7     // wave number (cap: waves past this no longer add increment)

SOLDIER_SRC_SIZE          :: 16    // px
SOLDIER_HITBOX_W          :: 12    // px
SOLDIER_HITBOX_H          :: 14    // px
SOLDIER_HP                :: 40.0  // HP
SOLDIER_SPEED             :: 50.0  // px/s
SOLDIER_ANIM_FPS          :: 10.0  // frames/s
SOLDIER_DEATH_DURATION    :: 0.3   // s
SOLDIER_ATTACK_COOLDOWN   :: 2.2   // s
SOLDIER_RANGE_MIN         :: 80.0  // px
SOLDIER_RANGE_MAX         :: 150.0 // px
SOLDIER_RANGE_HYSTERESIS  :: 8.0   // px
SOLDIER_FIRE_FRAME        :: 2     // frame index that fires projectile
SOLDIER_PROJECTILE_SPEED  :: 220.0 // px/s
SOLDIER_PROJECTILE_DAMAGE :: 21.0  // HP
SOLDIER_PROJECTILE_SRC_SIZE :: 8   // px
SOLDIER_PROJECTILE_MAX_DIST :: 320.0 // px
SOLDIER_PROJECTILE_ANIM_FPS :: 12.0  // frames/s
SOLDIER_STAGGER_DURATION  :: 0.15  // s
SOLDIER_STAGGER_KNOCKBACK :: 90.0  // px/s
MAX_SOLDIER_SLOTS         :: 12    // count
MAX_SOLDIER_ALIVE         :: 4     // count
SOLDIER_WAVE_THRESHOLD    :: 3     // wave number (first wave soldiers can spawn)
SOLDIER_SPAWN_CHANCE      :: 0.3   // probability (0..1)

SLUDGECLOPS_SRC_SIZE         :: 16   // px
SLUDGECLOPS_HITBOX_W         :: 12   // px
SLUDGECLOPS_HITBOX_H         :: 14   // px
SLUDGECLOPS_HP               :: 40.0 // HP
SLUDGECLOPS_SPEED            :: 50.0 // px/s
SLUDGECLOPS_ANIM_FPS         :: 10.0 // frames/s
SLUDGECLOPS_DEATH_DURATION   :: 0.3  // s
SLUDGECLOPS_ATTACK_COOLDOWN  :: 2.2  // s
SLUDGECLOPS_RANGE_MIN        :: 60.0 // px
SLUDGECLOPS_RANGE_MAX        :: 95.0 // px
SLUDGECLOPS_RANGE_HYSTERESIS :: 8.0  // px
SLUDGECLOPS_FIRE_DURATION    :: 0.45 // s
SLUDGECLOPS_FIRE_AT          :: 0.20 // s (offset within fire duration when projectile spawns)
SLUDGECLOPS_STAGGER_DURATION :: 0.15 // s
SLUDGECLOPS_STAGGER_KNOCKBACK :: 90.0 // px/s
MAX_SLUDGECLOPS_SLOTS        :: 12   // count
MAX_SLUDGECLOPS_ALIVE        :: 4    // count
SLUDGECLOPS_WAVE_THRESHOLD   :: 5    // wave number (first wave sludgeclops can spawn)
SLUDGECLOPS_SPAWN_CHANCE     :: 0.3  // probability (0..1)

SLUDGEWAVE_SPEED       :: 165.0 // px/s
SLUDGEWAVE_DAMAGE      :: 25.0  // HP
SLUDGEWAVE_SRC_SIZE    :: 32    // px
SLUDGEWAVE_DIST_MIN    :: 85.0  // px
SLUDGEWAVE_DIST_MAX    :: 100.0 // px
SLUDGEWAVE_ANIM_FPS    :: 12.0  // frames/s

NERGAL_WAVE             :: 7      // wave number (boss wave)
NERGAL_HP               :: 600.0  // HP
NERGAL_SRC_SIZE         :: 16     // px
NERGAL_DRAW_SIZE        :: 32     // px
NERGAL_HITBOX_W         :: 22     // px
NERGAL_HITBOX_H         :: 28     // px
NERGAL_SPEED            :: 83.0   // px/s
NERGAL_PHASE_2_HP       :: 400.0  // HP threshold
NERGAL_PHASE_3_HP       :: 200.0  // HP threshold
NERGAL_PHASE_3_SPEED_MULT :: 1.10 // multiplier
NERGAL_ATTACK_RANGE     :: 44.0   // px
NERGAL_ATTACK_DAMAGE    :: 12.0   // HP
NERGAL_ATTACK_COOLDOWN  :: 0.7    // s
NERGAL_ATTACK_DURATION  :: 0.45   // s
NERGAL_HIT_AT           :: 0.18   // s (offset within attack duration when hit registers)
NERGAL_DEATH_DURATION   :: 0.8    // s
NERGAL_ANIM_FPS         :: 10.0   // frames/s
NERGAL_STAGGER_DURATION :: 0.10   // s
NERGAL_STAGGER_KNOCKBACK :: 40.0  // px/s

NERGAL_ACID_PARTICLE_COUNT :: 80     // count (pool size)
NERGAL_ACID_PARTICLES_PER_SHOT :: 28 // count
NERGAL_ACID_PARTICLE_LIFE  :: 0.55   // s
NERGAL_ACID_PARTICLE_SPEED_MIN :: 80.0  // px/s
NERGAL_ACID_PARTICLE_SPEED_MAX :: 180.0 // px/s
NERGAL_ACID_PARTICLE_GRAVITY   :: 280.0 // px/s^2
NERGAL_ACID_CONE_RADIANS       :: 0.9   // radians (half-angle of spread cone)
NERGAL_ACID_PARTICLE_SIZE      :: 2.5   // px

NERGAL_SUMMON_COUNT     :: 6 // count

NERGAL_BULLET_COUNT       :: 96    // count (pool size)
NERGAL_BULLET_INTERVAL    :: 1.5   // s
NERGAL_BULLET_RAGE_HP     :: 100.0 // HP threshold
NERGAL_BULLET_FRENZY_HP   :: 50.0  // HP threshold
NERGAL_BULLET_PER_BURST   :: 12    // count
NERGAL_BULLET_SPEED       :: 110.0 // px/s
NERGAL_BULLET_LIFE        :: 4.0   // s
NERGAL_BULLET_DAMAGE      :: 8.0   // HP
NERGAL_BULLET_RADIUS      :: 3.0   // px

LEVEL_MAP_PATH :: "assets/maps/lvl1.map" // path

PARALLAX_LAYER_COUNT :: 3
PARALLAX_SPEEDS : [PARALLAX_LAYER_COUNT]f32 : {0.05, 0.20, 0.50} // camera-position multipliers (0 = static, 1 = locked to camera)

MUSIC_BASE_VOLUME :: 0.2  // volume (0..1)
VOLUME_STEP       :: 0.10 // volume (0..1)

// Animation Speeds
IDLE_OFFSET :: 0.04 // s/frame (added to ANIM_FRAME_TIME so idle animations are slower than others)

PLAYER_IDLE_ANIM_SPEED :: ANIM_FRAME_TIME + IDLE_OFFSET // s/frame

MAIN_MENU_OPTIONS_ITEM_COUNT :: 3 // count

when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
	MAIN_MENU_ITEM_COUNT :: 2 // count
} else {
	MAIN_MENU_ITEM_COUNT :: 3 // count
}

MAIN_MENU_TITLE_ANIM_DUR :: f32(0.8)  // s
MAIN_MENU_TITLE_START_Y  :: f32(-40)  // px
MAIN_MENU_TITLE_REST_Y   :: f32(60)   // px
MAIN_MENU_ITEMS_DELAY    :: f32(0.3)  // s
MAIN_MENU_ITEMS_ANIM_DUR :: f32(0.6)  // s
MAIN_MENU_ITEMS_OFFSET   :: f32(-250) // px (initial X offset, eased to 0)

MAIN_MENU_TITLE_SIZE     :: i32(28)  // px (font size)
MAIN_MENU_SUBTITLE_SIZE  :: i32(10)  // px (font size)
MAIN_MENU_ITEM_SIZE      :: i32(14)  // px (font size)
MAIN_MENU_ITEM_BASE_Y    :: i32(170) // px
MAIN_MENU_ITEM_SPACING   :: i32(24)  // px
MAIN_MENU_HINT_SIZE      :: i32(8)   // px (font size)
MAIN_MENU_SPRITE_SIZE    :: f32(64)  // px

MAIN_MENU_OPTIONS_BASE_Y  :: i32(80) // px
MAIN_MENU_OPTIONS_SPACING :: i32(24) // px

CHOOSE_PROMPT_TEXT_SIZE :: i32(16) // px (font size)
CHOOSE_PROMPT_TEXT_Y    :: i32(28) // px
CHOOSE_PROMPT_PULSE_HZ  :: f32(4.0) // Hz
CHOOSE_ARROW_BOB_HZ     :: f32(6.0) // Hz
CHOOSE_ARROW_BOB_AMP    :: f32(3.0) // px
