package game

import "vendor:raylib"
import dm "../dotmap"
import "core:math/rand"

Sludgeclops_State :: enum {
	Unspawned,
	Idle,
	Approaching,
	Aiming,
	Firing,
	Cooldown,
	Dying,
	Dead,
}

Sludgewave_State :: enum {
	Inactive,
	Flying,
}

Sludgewave :: struct {
	state:         Sludgewave_State,
	pos:           raylib.Vector2,
	vel_x:         f32,
	travelled:     f32,
	max_dist:      f32,
	current_frame: f32,
	anim_timer:    f32,
}

Sludgeclops :: struct {
	pos:                    raylib.Vector2,
	spawn_pos:              raylib.Vector2,
	vel:                    raylib.Vector2,
	state:                  Sludgeclops_State,
	on_ground:              bool,
	facing_left:            bool,
	hp:                     f32,
	attack_range:           f32,
	current_frame:          f32,
	anim_timer:             f32,
	state_timer:            f32,
	death_timer:            f32,
	damage_flash_timer:     f32,
	stagger_timer:          f32,
	slow_timer:             f32,
	fired_this_attack:      bool,
	last_projectile_hit_id: u32,
	last_orb_hit_id:        u32,
	last_twister_hit_id:    u32,
	wave:                   Sludgewave,
}

Sludgeclops_Pool :: struct {
	slots:        [MAX_SLUDGECLOPS_SLOTS]Sludgeclops,
	count:        int,
	idle_tex:     raylib.Texture2D,
	move_tex:     raylib.Texture2D,
	wave_tex:     raylib.Texture2D,
	idle_frames:  int,
	move_frames:  int,
	wave_frames:  int,
}

init_sludgeclops :: proc(pool: ^Sludgeclops_Pool) {
	pool.idle_tex = raylib.LoadTexture("assets/sprites/enemy_sludgeclops_idle.png")
	pool.move_tex = raylib.LoadTexture("assets/sprites/enemy_sludgeclops_move.png")
	pool.wave_tex = raylib.LoadTexture("assets/sprites/enemy_sludgeclops_sludgewave_attack.png")
	pool.idle_frames = int(pool.idle_tex.width) / SLUDGECLOPS_SRC_SIZE
	pool.move_frames = int(pool.move_tex.width) / SLUDGECLOPS_SRC_SIZE
	pool.wave_frames = int(pool.wave_tex.width) / SLUDGEWAVE_SRC_SIZE
	pool.count = 0
}

unload_sludgeclops :: proc(pool: ^Sludgeclops_Pool) {
	raylib.UnloadTexture(pool.idle_tex)
	raylib.UnloadTexture(pool.move_tex)
	raylib.UnloadTexture(pool.wave_tex)
}

register_sludgeclops_slot :: proc(pool: ^Sludgeclops_Pool, pos: raylib.Vector2) {
	if pool.count >= MAX_SLUDGECLOPS_SLOTS {
		return
	}
	s := &pool.slots[pool.count]
	s^ = Sludgeclops{pos = pos, spawn_pos = pos, state = .Unspawned}
	pool.count += 1
}

reset_sludgeclops :: proc(pool: ^Sludgeclops_Pool) {
	for i := 0; i < pool.count; i += 1 {
		spawn := pool.slots[i].spawn_pos
		st: Sludgeclops_State = .Unspawned
		if rand.float32() >= SLUDGECLOPS_SPAWN_CHANCE {
			st = .Dead
		}
		pool.slots[i] = Sludgeclops{pos = spawn, spawn_pos = spawn, state = st}
	}
}

get_sludgeclops_hitbox :: proc(s: ^Sludgeclops) -> raylib.Rectangle {
	return {
		s.pos.x - f32(SLUDGECLOPS_HITBOX_W) / 2,
		s.pos.y - f32(SLUDGECLOPS_HITBOX_H),
		f32(SLUDGECLOPS_HITBOX_W),
		f32(SLUDGECLOPS_HITBOX_H),
	}
}

get_sludgewave_rect :: proc(w: ^Sludgewave) -> raylib.Rectangle {
	return {
		w.pos.x - f32(SLUDGEWAVE_SRC_SIZE) / 2,
		w.pos.y - f32(SLUDGEWAVE_SRC_SIZE) / 2,
		f32(SLUDGEWAVE_SRC_SIZE),
		f32(SLUDGEWAVE_SRC_SIZE),
	}
}

set_sludgeclops_all_dead :: proc(pool: ^Sludgeclops_Pool) {
	for i := 0; i < pool.count; i += 1 {
		spawn := pool.slots[i].spawn_pos
		pool.slots[i] = Sludgeclops{pos = spawn, spawn_pos = spawn, state = .Dead}
	}
}

sludgeclops_all_dead :: proc(pool: ^Sludgeclops_Pool, allow_unspawned: bool) -> bool {
	for i := 0; i < pool.count; i += 1 {
		st := pool.slots[i].state
		if st == .Dead {
			continue
		}
		if st == .Unspawned && allow_unspawned {
			continue
		}
		return false
	}
	return true
}

update_sludgeclops :: proc(
	pool: ^Sludgeclops_Pool,
	p: ^Player,
	camera: ^raylib.Camera2D,
	map_data: ^dm.Dot_Map,
	dt: f32,
	active: bool,
) {
	if active {
		alive := 0
		for i := 0; i < pool.count; i += 1 {
			s := &pool.slots[i]
			if s.state != .Unspawned && s.state != .Dead {
				alive += 1
			}
		}
		if alive < MAX_SLUDGECLOPS_ALIVE {
			for i := 0; i < pool.count && alive < MAX_SLUDGECLOPS_ALIVE; i += 1 {
				s := &pool.slots[i]
				if s.state != .Unspawned {
					continue
				}
				s.state = .Idle
				s.hp = SLUDGECLOPS_HP
				s.attack_range = rand.float32_range(SLUDGECLOPS_RANGE_MIN, SLUDGECLOPS_RANGE_MAX)
				s.current_frame = 0
				s.anim_timer = 0
				s.fired_this_attack = false
				alive += 1
			}
		}
	}

	half_w := f32(SCREEN_WIDTH) / (2 * camera.zoom)
	half_h := f32(SCREEN_HEIGHT) / (2 * camera.zoom)
	view_rect := raylib.Rectangle{
		camera.target.x - half_w,
		camera.target.y - half_h,
		half_w * 2,
		half_h * 2,
	}

	for i := 0; i < pool.count; i += 1 {
		s := &pool.slots[i]

		update_sludgewave(s, p, map_data, dt)

		if s.state == .Unspawned || s.state == .Dead {
			continue
		}

		prev_hp := s.hp
		prev_state := s.state

		if s.damage_flash_timer > 0 {
			s.damage_flash_timer -= dt
		}
		if s.slow_timer > 0 {
			s.slow_timer -= dt
		}

		if s.stagger_timer > 0 && s.state != .Dying && s.state != .Dead {
			s.stagger_timer -= dt
			sludgeclops_apply_gravity(s, dt)
			sludgeclops_move_and_collide(s, map_data, dt)
		} else {
		switch s.state {
		case .Unspawned, .Dead:
			// handled above

		case .Idle:
			s.vel.x = 0
			sludgeclops_apply_gravity(s, dt)
			sludgeclops_move_and_collide(s, map_data, dt)
			sludgeclops_animate_loop(s, pool.idle_frames, dt)

			if raylib.CheckCollisionRecs(get_sludgeclops_hitbox(s), view_rect) {
				s.state = .Approaching
				s.facing_left = p.pos.x < s.pos.x
				s.current_frame = 0
				s.anim_timer = 0
			}

		case .Approaching:
			dx := p.pos.x - s.pos.x
			abs_dx := abs(dx)
			FACE_DEADZONE :: f32(2.0)
			if abs_dx > FACE_DEADZONE {
				s.facing_left = dx < 0
			}
			speed: f32 = SLUDGECLOPS_SPEED
			if s.slow_timer > 0 {
				speed *= SLUDGE_SLOW_FACTOR
			}
			if abs_dx > s.attack_range + SLUDGECLOPS_RANGE_HYSTERESIS {
				s.vel.x = s.facing_left ? -speed : speed
			} else if abs_dx < s.attack_range - SLUDGECLOPS_RANGE_HYSTERESIS {
				s.vel.x = s.facing_left ? speed : -speed
			} else {
				s.vel.x = 0
				s.state = .Aiming
				s.state_timer = 0.25
				s.current_frame = 0
				s.anim_timer = 0
				s.fired_this_attack = false
			}
			sludgeclops_apply_gravity(s, dt)
			sludgeclops_move_and_collide(s, map_data, dt)
			sludgeclops_animate_loop(s, pool.move_frames, dt)

		case .Aiming:
			s.vel.x = 0
			s.facing_left = p.pos.x < s.pos.x
			sludgeclops_apply_gravity(s, dt)
			sludgeclops_move_and_collide(s, map_data, dt)
			sludgeclops_animate_loop(s, pool.idle_frames, dt)
			s.state_timer -= dt
			if s.state_timer <= 0 {
				s.state = .Firing
				s.state_timer = SLUDGECLOPS_FIRE_DURATION
				s.current_frame = 0
				s.anim_timer = 0
				s.fired_this_attack = false
			}

		case .Firing:
			s.vel.x = 0
			sludgeclops_apply_gravity(s, dt)
			sludgeclops_move_and_collide(s, map_data, dt)
			sludgeclops_animate_loop(s, pool.idle_frames, dt)
			prev_timer := s.state_timer
			s.state_timer -= dt
			fire_t: f32 = SLUDGECLOPS_FIRE_DURATION - SLUDGECLOPS_FIRE_AT
			if !s.fired_this_attack && prev_timer > fire_t && s.state_timer <= fire_t {
				fire_sludgewave(s)
				s.fired_this_attack = true
			}
			if s.state_timer <= 0 {
				if !s.fired_this_attack {
					fire_sludgewave(s)
					s.fired_this_attack = true
				}
				sludgeclops_enter_cooldown(s)
			}

		case .Cooldown:
			s.vel.x = 0
			sludgeclops_apply_gravity(s, dt)
			sludgeclops_move_and_collide(s, map_data, dt)
			sludgeclops_animate_loop(s, pool.idle_frames, dt)
			s.state_timer -= dt
			if s.state_timer <= 0 {
				if raylib.CheckCollisionRecs(get_sludgeclops_hitbox(s), view_rect) {
					s.state = .Approaching
					s.facing_left = p.pos.x < s.pos.x
				} else {
					s.state = .Idle
				}
				s.current_frame = 0
				s.anim_timer = 0
			}

		case .Dying:
			s.vel.x = 0
			sludgeclops_apply_gravity(s, dt)
			sludgeclops_move_and_collide(s, map_data, dt)
			s.death_timer -= dt
			if s.death_timer <= 0 {
				s.state = .Dead
			}
		}
		}

		// Boomerang collision — at most one hit per throw
		if s.state != .Dying && s.state != .Dead &&
		   p.projectile.state != .Inactive &&
		   s.last_projectile_hit_id != p.projectile.attack_id {
			if raylib.CheckCollisionRecs(get_projectile_rect(&p.projectile), get_sludgeclops_hitbox(s)) {
				s.hp -= compute_player_damage(p, PROJECTILE_DAMAGE)
				s.damage_flash_timer = DAMAGE_FLASH_DURATION
				s.last_projectile_hit_id = p.projectile.attack_id
				if s.hp <= 0 {
					sludgeclops_enter_dying(s)
				}
			}
		}

		// Downward dash slam
		if s.state != .Dying && s.state != .Dead &&
		   p.dash_impact_active && !p.dash_impact_damage_dealt {
			if raylib.CheckCollisionRecs(get_dash_impact_rect(p), get_sludgeclops_hitbox(s)) {
				s.hp -= compute_player_damage(p, DASH_IMPACT_DAMAGE)
				s.damage_flash_timer = DAMAGE_FLASH_DURATION
				if s.hp <= 0 {
					sludgeclops_enter_dying(s)
				}
			}
		}

		// Quick attack (melee combo)
		if s.state != .Dying && s.state != .Dead && p.quick_attack_damage_active {
			if raylib.CheckCollisionRecs(get_quick_attack_rect(p), get_sludgeclops_hitbox(s)) {
				base: f32 = p.quick_attack_state == .Attack1 ? QUICK_ATTACK_DAMAGE_1 : QUICK_ATTACK_DAMAGE_2
				dmg := compute_player_damage(p, base)
				if p.has_double_strike && p.quick_attack_state == .Attack2 &&
				   rand.float32() < DOUBLE_STRIKE_CHANCE {
					dmg *= 2
				}
				s.hp -= dmg
				s.damage_flash_timer = DAMAGE_FLASH_DURATION
				if s.hp <= 0 {
					sludgeclops_enter_dying(s)
				} else {
					s.stagger_timer = SLUDGECLOPS_STAGGER_DURATION
					kb_dir: f32 = p.facing_left ? -1.0 : 1.0
					s.vel.x = kb_dir * SLUDGECLOPS_STAGGER_KNOCKBACK
				}
			}
		}

		// Waveblade swing
		if s.state != .Dying && s.state != .Dead && p.waveblade_damage_active {
			if raylib.CheckCollisionRecs(get_waveblade_rect(p), get_sludgeclops_hitbox(s)) {
				dmg := compute_player_damage(p, WATERBLADE_DAMAGE, WATERBLADE_CRIT_CHANCE)
				s.hp -= dmg
				s.damage_flash_timer = DAMAGE_FLASH_DURATION
				if s.hp <= 0 {
					sludgeclops_enter_dying(s)
				} else {
					s.stagger_timer = SLUDGECLOPS_STAGGER_DURATION
					kb_dir: f32 = p.facing_left ? -1.0 : 1.0
					s.vel.x = kb_dir * SLUDGECLOPS_STAGGER_KNOCKBACK
				}
			}
		}

		// Water twister
		if s.state != .Dying && s.state != .Dead &&
		   p.twister_state != .Inactive &&
		   s.last_twister_hit_id != p.twister_attack_id {
			if raylib.CheckCollisionRecs(get_twister_rect(p), get_sludgeclops_hitbox(s)) {
				is_backstab := s.facing_left == (p.twister_pos.x > s.pos.x)
				dmg := compute_player_damage(p, TWISTER_DAMAGE)
				if is_backstab {
					dmg *= 1 + TWISTER_BACKSTAB_BONUS
				}
				s.hp -= dmg
				s.damage_flash_timer = DAMAGE_FLASH_DURATION
				s.last_twister_hit_id = p.twister_attack_id
				if s.hp <= 0 {
					sludgeclops_enter_dying(s)
				}
			}
		}

		// Orb projectile
		if s.state != .Dying && s.state != .Dead &&
		   p.orb_state == .Flying &&
		   s.last_orb_hit_id != p.orb_attack_id {
			if raylib.CheckCollisionRecs(get_orb_rect(p), get_sludgeclops_hitbox(s)) {
				s.hp -= compute_player_damage(p, WATERORB_DAMAGE)
				s.damage_flash_timer = DAMAGE_FLASH_DURATION
				s.last_orb_hit_id = p.orb_attack_id
				if rand.float32() < WATERORB_SLOW_CHANCE {
					s.slow_timer = SLUDGE_SLOW_DURATION
				}
				if s.hp <= 0 {
					sludgeclops_enter_dying(s)
				}
			}
		}

		if s.state == .Dying && prev_state != .Dying {
			play_sound(.Enemy_Dies)
		} else if s.hp < prev_hp {
			play_sound(.Hit)
		}
	}
}

draw_sludgeclops :: proc(pool: ^Sludgeclops_Pool) {
	for i := 0; i < pool.count; i += 1 {
		s := &pool.slots[i]
		if s.state != .Unspawned && s.state != .Dead {
			tex:    raylib.Texture2D
			frames: int
			switch s.state {
			case .Approaching:
				tex = pool.move_tex
				frames = pool.move_frames
			case .Idle, .Aiming, .Firing, .Cooldown, .Dying:
				tex = pool.idle_tex
				frames = pool.idle_frames
			case .Unspawned, .Dead:
				continue
			}

			frame := int(s.current_frame)
			if frame >= frames {
				frame = frames - 1
			}

			src := raylib.Rectangle{
				f32(frame * SLUDGECLOPS_SRC_SIZE), 0,
				s.facing_left ? -f32(SLUDGECLOPS_SRC_SIZE) : f32(SLUDGECLOPS_SRC_SIZE),
				f32(SLUDGECLOPS_SRC_SIZE),
			}
			dst := raylib.Rectangle{
				s.pos.x - f32(SLUDGECLOPS_SRC_SIZE) / 2,
				s.pos.y - f32(SLUDGECLOPS_SRC_SIZE),
				f32(SLUDGECLOPS_SRC_SIZE),
				f32(SLUDGECLOPS_SRC_SIZE),
			}

			tint := raylib.WHITE
			flashing := false
			if s.state == .Dying {
				t := clamp(s.death_timer / SLUDGECLOPS_DEATH_DURATION, 0, 1)
				tint.a = u8(255.0 * t)
			} else if s.damage_flash_timer > 0 {
				flashing = true
			}

			if flashing {
				begin_hitflash(1.0)
			}
			raylib.DrawTexturePro(tex, src, dst, {0, 0}, 0, tint)
			if flashing {
				end_hitflash()
			}
		}

		if s.wave.state == .Flying {
			w := &s.wave
			frame := int(w.current_frame)
			if pool.wave_frames > 0 {
				frame = frame % pool.wave_frames
			}
			facing_left := w.vel_x < 0
			src := raylib.Rectangle{
				f32(frame * SLUDGEWAVE_SRC_SIZE), 0,
				facing_left ? -f32(SLUDGEWAVE_SRC_SIZE) : f32(SLUDGEWAVE_SRC_SIZE),
				f32(SLUDGEWAVE_SRC_SIZE),
			}
			dst := raylib.Rectangle{
				w.pos.x - f32(SLUDGEWAVE_SRC_SIZE) / 2,
				w.pos.y - f32(SLUDGEWAVE_SRC_SIZE) / 2,
				f32(SLUDGEWAVE_SRC_SIZE),
				f32(SLUDGEWAVE_SRC_SIZE),
			}
			raylib.DrawTexturePro(pool.wave_tex, src, dst, {0, 0}, 0, raylib.WHITE)
		}
	}
}

@(private = "file")
fire_sludgewave :: proc(s: ^Sludgeclops) {
	w := &s.wave
	w.state = .Flying
	// Anchor wave bottom to platform top (= sludgeclops feet) so it doesn't
	// instantly intersect the floor on the solid-tile check.
	w.pos = {s.pos.x, s.pos.y - f32(SLUDGEWAVE_SRC_SIZE) / 2}
	w.vel_x = s.facing_left ? -SLUDGEWAVE_SPEED : SLUDGEWAVE_SPEED
	w.travelled = 0
	w.max_dist = rand.float32_range(SLUDGEWAVE_DIST_MIN, SLUDGEWAVE_DIST_MAX)
	w.current_frame = 0
	w.anim_timer = 0
	play_sound(.Enemy_Soldier_Attacks)
}

@(private = "file")
update_sludgewave :: proc(
	s: ^Sludgeclops,
	p: ^Player,
	map_data: ^dm.Dot_Map,
	dt: f32,
) {
	w := &s.wave
	if w.state != .Flying {
		return
	}

	step := w.vel_x * dt
	w.pos.x += step
	w.travelled += abs(step)

	frame_dur: f32 = 1.0 / SLUDGEWAVE_ANIM_FPS
	w.anim_timer += dt
	if w.anim_timer >= frame_dur {
		w.anim_timer -= frame_dur
		w.current_frame += 1
	}

	rect := get_sludgewave_rect(w)

	if check_rect_solid(map_data, rect) {
		w.state = .Inactive
		return
	}

	if w.travelled >= w.max_dist {
		w.state = .Inactive
		return
	}

	if !p.dashing && raylib.CheckCollisionRecs(rect, get_player_hitbox(p)) {
		apply_damage_to_player(p, SLUDGEWAVE_DAMAGE)
		w.state = .Inactive
		return
	}
}

@(private = "file")
sludgeclops_enter_dying :: proc(s: ^Sludgeclops) {
	s.state = .Dying
	s.death_timer = SLUDGECLOPS_DEATH_DURATION
	s.vel.x = 0
	s.current_frame = 0
	s.anim_timer = 0
}

@(private = "file")
sludgeclops_enter_cooldown :: proc(s: ^Sludgeclops) {
	s.state = .Cooldown
	s.state_timer = SLUDGECLOPS_ATTACK_COOLDOWN
	s.vel.x = 0
	s.current_frame = 0
	s.anim_timer = 0
}

@(private = "file")
sludgeclops_apply_gravity :: proc(s: ^Sludgeclops, dt: f32) {
	s.vel.y += GRAVITY * dt
	if s.vel.y > MAX_FALL_SPEED {
		s.vel.y = MAX_FALL_SPEED
	}
}

@(private = "file")
sludgeclops_move_and_collide :: proc(s: ^Sludgeclops, map_data: ^dm.Dot_Map, dt: f32) {
	s.pos.x += s.vel.x * dt
	hb := get_sludgeclops_hitbox(s)
	if check_rect_solid(map_data, hb) {
		if s.vel.x > 0 {
			tile_x := int(hb.x + hb.width) / TILE_SIZE
			s.pos.x = f32(tile_x * TILE_SIZE) - f32(SLUDGECLOPS_HITBOX_W) / 2
		} else if s.vel.x < 0 {
			tile_x := int(hb.x) / TILE_SIZE
			s.pos.x = f32((tile_x + 1) * TILE_SIZE) + f32(SLUDGECLOPS_HITBOX_W) / 2
		}
		s.vel.x = 0
	}

	s.pos.y += s.vel.y * dt
	hb = get_sludgeclops_hitbox(s)
	s.on_ground = false
	if check_rect_solid(map_data, hb) {
		if s.vel.y > 0 {
			tile_y := int(hb.y + hb.height) / TILE_SIZE
			s.pos.y = f32(tile_y * TILE_SIZE)
			s.on_ground = true
		} else if s.vel.y < 0 {
			tile_y := int(hb.y) / TILE_SIZE
			s.pos.y = f32((tile_y + 1) * TILE_SIZE) + f32(SLUDGECLOPS_HITBOX_H)
		}
		s.vel.y = 0
	}
}

@(private = "file")
sludgeclops_animate_loop :: proc(s: ^Sludgeclops, total_frames: int, dt: f32) {
	if total_frames <= 1 {
		return
	}
	frame_dur: f32 = 1.0 / SLUDGECLOPS_ANIM_FPS
	s.anim_timer += dt
	if s.anim_timer >= frame_dur {
		s.anim_timer -= frame_dur
		s.current_frame += 1
		if int(s.current_frame) >= total_frames {
			s.current_frame = 0
		}
	}
}
