package game

import "vendor:raylib"
import dm "../dotmap"
import "core:math/rand"

Soldier_State :: enum {
	Unspawned,
	Spawning,
	Idle,
	Approaching,
	Aiming,
	Firing,
	Cooldown,
	Dying,
	Dead,
}

Soldier_Projectile_State :: enum {
	Inactive,
	Flying,
}

Soldier_Projectile :: struct {
	state:        Soldier_Projectile_State,
	pos:          raylib.Vector2,
	vel_x:        f32,
	travelled:    f32,
	current_frame: f32,
	anim_timer:   f32,
}

Sludge_Soldier :: struct {
	pos:                raylib.Vector2,
	spawn_pos:          raylib.Vector2,
	vel:                raylib.Vector2,
	state:              Soldier_State,
	on_ground:          bool,
	facing_left:        bool,
	hp:                 f32,
	attack_range:       f32,
	current_frame:      f32,
	anim_timer:         f32,
	state_timer:        f32,
	death_timer:        f32,
	damage_flash_timer: f32,
	stagger_timer:      f32,
	slow_timer:         f32,
	fired_this_attack:  bool,
	last_projectile_hit_id: u32,
	last_orb_hit_id:    u32,
	last_twister_hit_id: u32,
	projectile:         Soldier_Projectile,
}

Soldier_Pool :: struct {
	slots:             [MAX_SOLDIER_SLOTS]Sludge_Soldier,
	count:             int,
	idle_tex:          raylib.Texture2D,
	spawn_tex:         raylib.Texture2D,
	attack_tex:        raylib.Texture2D,
	projectile_tex:    raylib.Texture2D,
	idle_frames:       int,
	spawn_frames:      int,
	attack_frames:     int,
	projectile_frames: int,
}

init_soldiers :: proc(pool: ^Soldier_Pool) {
	pool.idle_tex = raylib.LoadTexture("assets/sprites/enemy_sludge_soldier.png")
	pool.spawn_tex = raylib.LoadTexture("assets/sprites/enemy_sludge_soldier_spawn.png")
	pool.attack_tex = raylib.LoadTexture("assets/sprites/enemy_sludge_soldier_attacks.png")
	pool.projectile_tex = raylib.LoadTexture("assets/sprites/enemy_sludge_soldier_attack_projectile.png")
	pool.idle_frames = int(pool.idle_tex.width) / SOLDIER_SRC_SIZE
	pool.spawn_frames = int(pool.spawn_tex.width) / SOLDIER_SRC_SIZE
	pool.attack_frames = int(pool.attack_tex.width) / SOLDIER_SRC_SIZE
	pool.projectile_frames = int(pool.projectile_tex.width) / SOLDIER_PROJECTILE_SRC_SIZE
	pool.count = 0
}

unload_soldiers :: proc(pool: ^Soldier_Pool) {
	raylib.UnloadTexture(pool.idle_tex)
	raylib.UnloadTexture(pool.spawn_tex)
	raylib.UnloadTexture(pool.attack_tex)
	raylib.UnloadTexture(pool.projectile_tex)
}

register_soldier_slot :: proc(pool: ^Soldier_Pool, pos: raylib.Vector2) {
	if pool.count >= MAX_SOLDIER_SLOTS {
		return
	}
	s := &pool.slots[pool.count]
	s^ = Sludge_Soldier{pos = pos, spawn_pos = pos, state = .Unspawned}
	pool.count += 1
}

reset_soldiers :: proc(pool: ^Soldier_Pool) {
	for i := 0; i < pool.count; i += 1 {
		spawn := pool.slots[i].spawn_pos
		st: Soldier_State = .Unspawned
		if rand.float32() >= SOLDIER_SPAWN_CHANCE {
			st = .Dead
		}
		pool.slots[i] = Sludge_Soldier{pos = spawn, spawn_pos = spawn, state = st}
	}
}

get_soldier_hitbox :: proc(s: ^Sludge_Soldier) -> raylib.Rectangle {
	return {
		s.pos.x - f32(SOLDIER_HITBOX_W) / 2,
		s.pos.y - f32(SOLDIER_HITBOX_H),
		f32(SOLDIER_HITBOX_W),
		f32(SOLDIER_HITBOX_H),
	}
}

get_soldier_projectile_rect :: proc(pr: ^Soldier_Projectile) -> raylib.Rectangle {
	return {
		pr.pos.x - f32(SOLDIER_PROJECTILE_SRC_SIZE) / 2,
		pr.pos.y - f32(SOLDIER_PROJECTILE_SRC_SIZE) / 2,
		f32(SOLDIER_PROJECTILE_SRC_SIZE),
		f32(SOLDIER_PROJECTILE_SRC_SIZE),
	}
}

set_soldiers_all_dead :: proc(pool: ^Soldier_Pool) {
	for i := 0; i < pool.count; i += 1 {
		spawn := pool.slots[i].spawn_pos
		pool.slots[i] = Sludge_Soldier{pos = spawn, spawn_pos = spawn, state = .Dead}
	}
}

force_spawn_soldiers_at :: proc(pool: ^Soldier_Pool, pos: raylib.Vector2, count: int) -> int {
	spawned := 0
	for i := 0; i < pool.count && spawned < count; i += 1 {
		s := &pool.slots[i]
		if s.state != .Dead && s.state != .Unspawned {
			continue
		}
		offset_x: f32 = f32(spawned - count / 2) * 14.0
		s^ = Sludge_Soldier{
			pos = {pos.x + offset_x, pos.y},
			spawn_pos = {pos.x + offset_x, pos.y},
			state = .Spawning,
			hp = SOLDIER_HP,
			attack_range = rand.float32_range(SOLDIER_RANGE_MIN, SOLDIER_RANGE_MAX),
			facing_left = rand.float32() < 0.5,
		}
		spawned += 1
	}
	return spawned
}

soldiers_all_dead :: proc(pool: ^Soldier_Pool, allow_unspawned: bool) -> bool {
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

update_soldiers :: proc(
	pool: ^Soldier_Pool,
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
		if alive < MAX_SOLDIER_ALIVE {
			for i := 0; i < pool.count && alive < MAX_SOLDIER_ALIVE; i += 1 {
				s := &pool.slots[i]
				if s.state != .Unspawned {
					continue
				}
				s.state = .Spawning
				s.hp = SOLDIER_HP
				s.attack_range = rand.float32_range(SOLDIER_RANGE_MIN, SOLDIER_RANGE_MAX)
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

		update_soldier_projectile(s, p, map_data, dt)

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
			soldier_apply_gravity(s, dt)
			soldier_move_and_collide(s, map_data, dt)
		} else {
		switch s.state {
		case .Unspawned, .Dead:
		// handled above

		case .Spawning:
			s.vel.x = 0
			soldier_apply_gravity(s, dt)
			soldier_move_and_collide(s, map_data, dt)
			if soldier_advance_oneshot(s, pool.spawn_frames, dt) {
				s.state = .Idle
				s.current_frame = 0
				s.anim_timer = 0
			}

		case .Idle:
			s.vel.x = 0
			soldier_apply_gravity(s, dt)
			soldier_move_and_collide(s, map_data, dt)
			soldier_animate_loop(s, pool.idle_frames, dt)

			if raylib.CheckCollisionRecs(get_soldier_hitbox(s), view_rect) {
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
			speed: f32 = SOLDIER_SPEED
			if s.slow_timer > 0 {
				speed *= SLUDGE_SLOW_FACTOR
			}
			if abs_dx > s.attack_range + SOLDIER_RANGE_HYSTERESIS {
				s.vel.x = s.facing_left ? -speed : speed
			} else if abs_dx < s.attack_range - SOLDIER_RANGE_HYSTERESIS {
				s.vel.x = s.facing_left ? speed : -speed
			} else {
				s.vel.x = 0
				s.state = .Aiming
				s.state_timer = 0.25
				s.current_frame = 0
				s.anim_timer = 0
				s.fired_this_attack = false
			}
			soldier_apply_gravity(s, dt)
			soldier_move_and_collide(s, map_data, dt)
			soldier_animate_loop(s, pool.idle_frames, dt)

		case .Aiming:
			s.vel.x = 0
			s.facing_left = p.pos.x < s.pos.x
			soldier_apply_gravity(s, dt)
			soldier_move_and_collide(s, map_data, dt)
			soldier_animate_loop(s, pool.idle_frames, dt)
			s.state_timer -= dt
			if s.state_timer <= 0 {
				s.state = .Firing
				s.current_frame = 0
				s.anim_timer = 0
				s.fired_this_attack = false
			}

		case .Firing:
			s.vel.x = 0
			soldier_apply_gravity(s, dt)
			soldier_move_and_collide(s, map_data, dt)
			prev_frame := int(s.current_frame)
			done := soldier_advance_oneshot(s, pool.attack_frames, dt)
			cur_frame := int(s.current_frame)
			if !s.fired_this_attack &&
			   prev_frame < SOLDIER_FIRE_FRAME && cur_frame >= SOLDIER_FIRE_FRAME {
				fire_soldier_projectile(s)
				s.fired_this_attack = true
			}
			if done {
				if !s.fired_this_attack {
					fire_soldier_projectile(s)
					s.fired_this_attack = true
				}
				soldier_enter_cooldown(s)
			}

		case .Cooldown:
			s.vel.x = 0
			soldier_apply_gravity(s, dt)
			soldier_move_and_collide(s, map_data, dt)
			soldier_animate_loop(s, pool.idle_frames, dt)
			s.state_timer -= dt
			if s.state_timer <= 0 {
				if raylib.CheckCollisionRecs(get_soldier_hitbox(s), view_rect) {
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
			soldier_apply_gravity(s, dt)
			soldier_move_and_collide(s, map_data, dt)
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
			if raylib.CheckCollisionRecs(get_projectile_rect(&p.projectile), get_soldier_hitbox(s)) {
				s.hp -= compute_player_damage(p, PROJECTILE_DAMAGE)
				s.damage_flash_timer = DAMAGE_FLASH_DURATION
				s.last_projectile_hit_id = p.projectile.attack_id
				if s.hp <= 0 {
					soldier_enter_dying(s)
				}
			}
		}

		// Downward dash slam — once per impact
		if s.state != .Dying && s.state != .Dead &&
		   p.dash_impact_active && !p.dash_impact_damage_dealt {
			if raylib.CheckCollisionRecs(get_dash_impact_rect(p), get_soldier_hitbox(s)) {
				s.hp -= compute_player_damage(p, DASH_IMPACT_DAMAGE)
				s.damage_flash_timer = DAMAGE_FLASH_DURATION
				if s.hp <= 0 {
					soldier_enter_dying(s)
				}
			}
		}

		// Quick attack (melee combo)
		if s.state != .Dying && s.state != .Dead && p.quick_attack_damage_active {
			if raylib.CheckCollisionRecs(get_quick_attack_rect(p), get_soldier_hitbox(s)) {
				base: f32 = p.quick_attack_state == .Attack1 ? QUICK_ATTACK_DAMAGE_1 : QUICK_ATTACK_DAMAGE_2
				dmg := compute_player_damage(p, base)
				if p.has_double_strike && p.quick_attack_state == .Attack2 &&
				   rand.float32() < DOUBLE_STRIKE_CHANCE {
					dmg *= 2
				}
				s.hp -= dmg
				s.damage_flash_timer = DAMAGE_FLASH_DURATION
				if s.hp <= 0 {
					soldier_enter_dying(s)
				} else {
					s.stagger_timer = SOLDIER_STAGGER_DURATION
					kb_dir: f32 = p.facing_left ? -1.0 : 1.0
					s.vel.x = kb_dir * SOLDIER_STAGGER_KNOCKBACK
				}
			}
		}

		// Waveblade swing
		if s.state != .Dying && s.state != .Dead && p.waveblade_damage_active {
			if raylib.CheckCollisionRecs(get_waveblade_rect(p), get_soldier_hitbox(s)) {
				dmg := compute_player_damage(p, WATERBLADE_DAMAGE, WATERBLADE_CRIT_CHANCE)
				s.hp -= dmg
				s.damage_flash_timer = DAMAGE_FLASH_DURATION
				if s.hp <= 0 {
					soldier_enter_dying(s)
				} else {
					s.stagger_timer = SOLDIER_STAGGER_DURATION
					kb_dir: f32 = p.facing_left ? -1.0 : 1.0
					s.vel.x = kb_dir * SOLDIER_STAGGER_KNOCKBACK
				}
			}
		}

		// Water twister — pierces foes, +18% damage on backstab. At most one hit per throw per foe.
		if s.state != .Dying && s.state != .Dead &&
		   p.twister_state != .Inactive &&
		   s.last_twister_hit_id != p.twister_attack_id {
			if raylib.CheckCollisionRecs(get_twister_rect(p), get_soldier_hitbox(s)) {
				is_backstab := s.facing_left == (p.twister_pos.x > s.pos.x)
				dmg := compute_player_damage(p, TWISTER_DAMAGE)
				if is_backstab {
					dmg *= 1 + TWISTER_BACKSTAB_BONUS
				}
				s.hp -= dmg
				s.damage_flash_timer = DAMAGE_FLASH_DURATION
				s.last_twister_hit_id = p.twister_attack_id
				if s.hp <= 0 {
					soldier_enter_dying(s)
				}
			}
		}

		// Orb projectile
		if s.state != .Dying && s.state != .Dead &&
		   p.orb_state == .Flying &&
		   s.last_orb_hit_id != p.orb_attack_id {
			if raylib.CheckCollisionRecs(get_orb_rect(p), get_soldier_hitbox(s)) {
				s.hp -= compute_player_damage(p, WATERORB_DAMAGE)
				s.damage_flash_timer = DAMAGE_FLASH_DURATION
				s.last_orb_hit_id = p.orb_attack_id
				if rand.float32() < WATERORB_SLOW_CHANCE {
					s.slow_timer = SLUDGE_SLOW_DURATION
				}
				if s.hp <= 0 {
					soldier_enter_dying(s)
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

draw_soldiers :: proc(pool: ^Soldier_Pool) {
	for i := 0; i < pool.count; i += 1 {
		s := &pool.slots[i]
		if s.state != .Unspawned && s.state != .Dead {
			tex:    raylib.Texture2D
			frames: int
			switch s.state {
			case .Spawning:
				tex = pool.spawn_tex
				frames = pool.spawn_frames
			case .Firing:
				tex = pool.attack_tex
				frames = pool.attack_frames
			case .Idle, .Approaching, .Aiming, .Cooldown, .Dying:
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
				f32(frame * SOLDIER_SRC_SIZE), 0,
				s.facing_left ? -f32(SOLDIER_SRC_SIZE) : f32(SOLDIER_SRC_SIZE),
				f32(SOLDIER_SRC_SIZE),
			}
			dst := raylib.Rectangle{
				s.pos.x - f32(SOLDIER_SRC_SIZE) / 2,
				s.pos.y - f32(SOLDIER_SRC_SIZE),
				f32(SOLDIER_SRC_SIZE),
				f32(SOLDIER_SRC_SIZE),
			}

			tint := raylib.WHITE
			flashing := false
			if s.state == .Dying {
				t := clamp(s.death_timer / SOLDIER_DEATH_DURATION, 0, 1)
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

		if s.projectile.state == .Flying {
			pr := &s.projectile
			frame := int(pr.current_frame)
			if frame >= pool.projectile_frames {
				frame = pool.projectile_frames - 1
			}
			facing_left := pr.vel_x < 0
			src := raylib.Rectangle{
				f32(frame * SOLDIER_PROJECTILE_SRC_SIZE), 0,
				facing_left ? -f32(SOLDIER_PROJECTILE_SRC_SIZE) : f32(SOLDIER_PROJECTILE_SRC_SIZE),
				f32(SOLDIER_PROJECTILE_SRC_SIZE),
			}
			dst := raylib.Rectangle{
				pr.pos.x - f32(SOLDIER_PROJECTILE_SRC_SIZE) / 2,
				pr.pos.y - f32(SOLDIER_PROJECTILE_SRC_SIZE) / 2,
				f32(SOLDIER_PROJECTILE_SRC_SIZE),
				f32(SOLDIER_PROJECTILE_SRC_SIZE),
			}
			raylib.DrawTexturePro(pool.projectile_tex, src, dst, {0, 0}, 0, raylib.WHITE)
		}
	}
}

@(private = "file")
fire_soldier_projectile :: proc(s: ^Sludge_Soldier) {
	pr := &s.projectile
	pr.state = .Flying
	pr.pos = {s.pos.x, s.pos.y - f32(SOLDIER_HITBOX_H) / 2}
	pr.vel_x = s.facing_left ? -SOLDIER_PROJECTILE_SPEED : SOLDIER_PROJECTILE_SPEED
	pr.travelled = 0
	pr.current_frame = 0
	pr.anim_timer = 0
	play_sound(.Enemy_Soldier_Attacks)
}

@(private = "file")
update_soldier_projectile :: proc(
	s: ^Sludge_Soldier,
	p: ^Player,
	map_data: ^dm.Dot_Map,
	dt: f32,
) {
	pr := &s.projectile
	if pr.state != .Flying {
		return
	}

	step := pr.vel_x * dt
	pr.pos.x += step
	pr.travelled += abs(step)

	frame_dur: f32 = 1.0 / SOLDIER_PROJECTILE_ANIM_FPS
	pr.anim_timer += dt
	if pr.anim_timer >= frame_dur {
		pr.anim_timer -= frame_dur
		pr.current_frame += 1
	}

	rect := get_soldier_projectile_rect(pr)

	if check_rect_solid(map_data, rect) {
		pr.state = .Inactive
		return
	}

	if pr.travelled >= SOLDIER_PROJECTILE_MAX_DIST {
		pr.state = .Inactive
		return
	}

	if !p.dashing && raylib.CheckCollisionRecs(rect, get_player_hitbox(p)) {
		apply_damage_to_player(p, SOLDIER_PROJECTILE_DAMAGE)
		pr.state = .Inactive
		return
	}
}

@(private = "file")
soldier_enter_dying :: proc(s: ^Sludge_Soldier) {
	s.state = .Dying
	s.death_timer = SOLDIER_DEATH_DURATION
	s.vel.x = 0
	s.current_frame = 0
	s.anim_timer = 0
}

@(private = "file")
soldier_enter_cooldown :: proc(s: ^Sludge_Soldier) {
	s.state = .Cooldown
	s.state_timer = SOLDIER_ATTACK_COOLDOWN
	s.vel.x = 0
	s.current_frame = 0
	s.anim_timer = 0
}

@(private = "file")
soldier_apply_gravity :: proc(s: ^Sludge_Soldier, dt: f32) {
	s.vel.y += GRAVITY * dt
	if s.vel.y > MAX_FALL_SPEED {
		s.vel.y = MAX_FALL_SPEED
	}
}

@(private = "file")
soldier_move_and_collide :: proc(s: ^Sludge_Soldier, map_data: ^dm.Dot_Map, dt: f32) {
	s.pos.x += s.vel.x * dt
	hb := get_soldier_hitbox(s)
	if check_rect_solid(map_data, hb) {
		if s.vel.x > 0 {
			tile_x := int(hb.x + hb.width) / TILE_SIZE
			s.pos.x = f32(tile_x * TILE_SIZE) - f32(SOLDIER_HITBOX_W) / 2
		} else if s.vel.x < 0 {
			tile_x := int(hb.x) / TILE_SIZE
			s.pos.x = f32((tile_x + 1) * TILE_SIZE) + f32(SOLDIER_HITBOX_W) / 2
		}
		s.vel.x = 0
	}

	s.pos.y += s.vel.y * dt
	hb = get_soldier_hitbox(s)
	s.on_ground = false
	if check_rect_solid(map_data, hb) {
		if s.vel.y > 0 {
			tile_y := int(hb.y + hb.height) / TILE_SIZE
			s.pos.y = f32(tile_y * TILE_SIZE)
			s.on_ground = true
		} else if s.vel.y < 0 {
			tile_y := int(hb.y) / TILE_SIZE
			s.pos.y = f32((tile_y + 1) * TILE_SIZE) + f32(SOLDIER_HITBOX_H)
		}
		s.vel.y = 0
	}
}

@(private = "file")
soldier_advance_oneshot :: proc(s: ^Sludge_Soldier, total_frames: int, dt: f32) -> bool {
	frame_dur: f32 = 1.0 / SOLDIER_ANIM_FPS
	s.anim_timer += dt
	if s.anim_timer >= frame_dur {
		s.anim_timer -= frame_dur
		s.current_frame += 1
		if int(s.current_frame) >= total_frames {
			return true
		}
	}
	return false
}

@(private = "file")
soldier_animate_loop :: proc(s: ^Sludge_Soldier, total_frames: int, dt: f32) {
	if total_frames <= 1 {
		return
	}
	frame_dur: f32 = 1.0 / SOLDIER_ANIM_FPS
	s.anim_timer += dt
	if s.anim_timer >= frame_dur {
		s.anim_timer -= frame_dur
		s.current_frame += 1
		if int(s.current_frame) >= total_frames {
			s.current_frame = 0
		}
	}
}
