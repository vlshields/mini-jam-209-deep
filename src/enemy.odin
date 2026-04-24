package game

import "vendor:raylib"
import dm "../dotmap"

Sludge_State :: enum {
	Unspawned,
	Spawning,
	Idle,
	Charging,
	Attacking,
	Cooldown,
	Dying,
	Dead,
}

Sludge :: struct {
	pos:                    raylib.Vector2, // bottom-center (also the spawn point while Unspawned)
	vel:                    raylib.Vector2,
	state:                  Sludge_State,
	on_ground:              bool,
	facing_left:            bool,
	hp:                     f32,
	current_frame:          f32,
	anim_timer:             f32,
	state_timer:            f32,
	death_timer:            f32,
	damage_flash_timer:     f32,
	last_projectile_hit_id: u32,
}

Sludge_Pool :: struct {
	slots:         [MAX_SLUDGE_SLOTS]Sludge,
	count:         int,
	spawn_tex:     raylib.Texture2D,
	idle_tex:      raylib.Texture2D,
	moving_tex:    raylib.Texture2D,
	charge_tex:    raylib.Texture2D,
	spawn_frames:  int,
	idle_frames:   int,
	moving_frames: int,
	charge_frames: int,
}

init_sludges :: proc(pool: ^Sludge_Pool) {
	pool.spawn_tex = raylib.LoadTexture("assets/sprites/enemy_sludge_grunt_spawn.png")
	pool.idle_tex = raylib.LoadTexture("assets/sprites/enemy_sludge_grunt_idle.png")
	pool.moving_tex = raylib.LoadTexture("assets/sprites/enemy_sludge_grunt_moving.png")
	pool.charge_tex = raylib.LoadTexture("assets/sprites/enemy_sludge_grunt_charge_attack.png")
	pool.spawn_frames = int(pool.spawn_tex.width) / SLUDGE_SRC_SIZE
	pool.idle_frames = int(pool.idle_tex.width) / SLUDGE_SRC_SIZE
	pool.moving_frames = int(pool.moving_tex.width) / SLUDGE_SRC_SIZE
	pool.charge_frames = int(pool.charge_tex.width) / SLUDGE_SRC_SIZE
	pool.count = 0
}

unload_sludges :: proc(pool: ^Sludge_Pool) {
	raylib.UnloadTexture(pool.spawn_tex)
	raylib.UnloadTexture(pool.idle_tex)
	raylib.UnloadTexture(pool.moving_tex)
	raylib.UnloadTexture(pool.charge_tex)
}

register_sludge_slot :: proc(pool: ^Sludge_Pool, pos: raylib.Vector2) {
	if pool.count >= MAX_SLUDGE_SLOTS {
		return
	}
	s := &pool.slots[pool.count]
	s^ = Sludge{pos = pos, state = .Unspawned}
	pool.count += 1
}

get_sludge_hitbox :: proc(s: ^Sludge) -> raylib.Rectangle {
	return {
		s.pos.x - f32(SLUDGE_HITBOX_W) / 2,
		s.pos.y - f32(SLUDGE_HITBOX_H),
		f32(SLUDGE_HITBOX_W),
		f32(SLUDGE_HITBOX_H),
	}
}

update_sludges :: proc(
	pool: ^Sludge_Pool,
	p: ^Player,
	camera: ^raylib.Camera2D,
	map_data: ^dm.Dot_Map,
	dt: f32,
) {
	// Count alive, then activate new slots up to MAX_SLUDGE_ALIVE
	alive := 0
	for i := 0; i < pool.count; i += 1 {
		s := &pool.slots[i]
		if s.state != .Unspawned && s.state != .Dead {
			alive += 1
		}
	}
	if alive < MAX_SLUDGE_ALIVE {
		for i := 0; i < pool.count && alive < MAX_SLUDGE_ALIVE; i += 1 {
			s := &pool.slots[i]
			if s.state == .Unspawned {
				s.state = .Spawning
				s.hp = SLUDGE_HP
				s.current_frame = 0
				s.anim_timer = 0
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
		if s.state == .Unspawned || s.state == .Dead {
			continue
		}

		if s.damage_flash_timer > 0 {
			s.damage_flash_timer -= dt
		}

		switch s.state {
		case .Unspawned, .Dead:
		// handled above

		case .Spawning:
			s.vel.x = 0
			sludge_apply_gravity(s, dt)
			sludge_move_and_collide(s, map_data, dt)
			if sludge_advance_oneshot(s, pool.spawn_frames, dt) {
				s.state = .Idle
				s.current_frame = 0
				s.anim_timer = 0
			}

		case .Idle:
			s.vel.x = 0
			sludge_apply_gravity(s, dt)
			sludge_move_and_collide(s, map_data, dt)
			sludge_animate_loop(s, pool.idle_frames, dt)

			if raylib.CheckCollisionRecs(get_sludge_hitbox(s), view_rect) {
				s.state = .Charging
				s.facing_left = p.pos.x < s.pos.x
				s.current_frame = 0
				s.anim_timer = 0
			}

		case .Charging:
			s.facing_left = p.pos.x < s.pos.x
			s.vel.x = s.facing_left ? -SLUDGE_SPEED : SLUDGE_SPEED
			sludge_apply_gravity(s, dt)
			sludge_move_and_collide(s, map_data, dt)
			sludge_animate_loop(s, pool.moving_frames, dt)

			if raylib.CheckCollisionRecs(get_sludge_hitbox(s), get_player_hitbox(p)) {
				s.state = .Attacking
				s.vel.x = 0
				s.current_frame = 0
				s.anim_timer = 0
			}

		case .Attacking:
			s.vel.x = 0
			sludge_apply_gravity(s, dt)
			sludge_move_and_collide(s, map_data, dt)
			if sludge_advance_oneshot(s, pool.charge_frames, dt) {
				if raylib.CheckCollisionRecs(get_sludge_hitbox(s), get_player_hitbox(p)) && !p.dashing {
					apply_damage_to_player(p, SLUDGE_DAMAGE)
				}
				sludge_enter_cooldown(s)
			}

		case .Cooldown:
			s.vel.x = 0
			sludge_apply_gravity(s, dt)
			sludge_move_and_collide(s, map_data, dt)
			sludge_animate_loop(s, pool.idle_frames, dt)
			s.state_timer -= dt
			if s.state_timer <= 0 {
				if raylib.CheckCollisionRecs(get_sludge_hitbox(s), view_rect) {
					s.state = .Charging
					s.facing_left = p.pos.x < s.pos.x
				} else {
					s.state = .Idle
				}
				s.current_frame = 0
				s.anim_timer = 0
			}

		case .Dying:
			s.vel.x = 0
			sludge_apply_gravity(s, dt)
			sludge_move_and_collide(s, map_data, dt)
			s.death_timer -= dt
			if s.death_timer <= 0 {
				s.state = .Dead
			}
		}

		// Boomerang collision — at most one hit per throw
		if s.state != .Dying && s.state != .Dead &&
		   p.projectile.state != .Inactive &&
		   s.last_projectile_hit_id != p.projectile.attack_id {
			if raylib.CheckCollisionRecs(get_projectile_rect(&p.projectile), get_sludge_hitbox(s)) {
				s.hp -= PROJECTILE_DAMAGE
				s.damage_flash_timer = DAMAGE_FLASH_DURATION
				s.last_projectile_hit_id = p.projectile.attack_id
				if s.hp <= 0 {
					s.state = .Dying
					s.death_timer = SLUDGE_DEATH_DURATION
					s.vel.x = 0
					s.current_frame = 0
					s.anim_timer = 0
				}
			}
		}

		// Downward dash slam collision — once per impact
		if s.state != .Dying && s.state != .Dead &&
		   p.dash_impact_active && !p.dash_impact_damage_dealt {
			if raylib.CheckCollisionRecs(get_dash_impact_rect(p), get_sludge_hitbox(s)) {
				s.hp -= DASH_IMPACT_DAMAGE
				s.damage_flash_timer = DAMAGE_FLASH_DURATION
				if s.hp <= 0 {
					s.state = .Dying
					s.death_timer = SLUDGE_DEATH_DURATION
					s.vel.x = 0
					s.current_frame = 0
					s.anim_timer = 0
				}
			}
		}
	}
}

draw_sludges :: proc(pool: ^Sludge_Pool) {
	for i := 0; i < pool.count; i += 1 {
		s := &pool.slots[i]
		if s.state == .Unspawned || s.state == .Dead {
			continue
		}

		tex:    raylib.Texture2D
		frames: int
		switch s.state {
		case .Spawning:
			tex = pool.spawn_tex
			frames = pool.spawn_frames
		case .Charging:
			tex = pool.moving_tex
			frames = pool.moving_frames
		case .Attacking:
			tex = pool.charge_tex
			frames = pool.charge_frames
		case .Idle, .Cooldown, .Dying:
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
			f32(frame * SLUDGE_SRC_SIZE), 0,
			s.facing_left ? -f32(SLUDGE_SRC_SIZE) : f32(SLUDGE_SRC_SIZE),
			f32(SLUDGE_SRC_SIZE),
		}
		dst := raylib.Rectangle{
			s.pos.x - f32(SLUDGE_SRC_SIZE) / 2,
			s.pos.y - f32(SLUDGE_SRC_SIZE),
			f32(SLUDGE_SRC_SIZE),
			f32(SLUDGE_SRC_SIZE),
		}

		tint := raylib.WHITE
		if s.state == .Dying {
			t := clamp(s.death_timer / SLUDGE_DEATH_DURATION, 0, 1)
			tint.a = u8(255.0 * t)
		} else if s.damage_flash_timer > 0 {
			tint = raylib.Color{255, 90, 90, 255}
		}

		raylib.DrawTexturePro(tex, src, dst, {0, 0}, 0, tint)
	}
}

@(private = "file")
sludge_enter_cooldown :: proc(s: ^Sludge) {
	s.state = .Cooldown
	s.state_timer = SLUDGE_ATTACK_COOLDOWN
	s.vel.x = 0
	s.current_frame = 0
	s.anim_timer = 0
}

@(private = "file")
sludge_apply_gravity :: proc(s: ^Sludge, dt: f32) {
	s.vel.y += GRAVITY * dt
	if s.vel.y > MAX_FALL_SPEED {
		s.vel.y = MAX_FALL_SPEED
	}
}

@(private = "file")
sludge_move_and_collide :: proc(s: ^Sludge, map_data: ^dm.Dot_Map, dt: f32) {
	s.pos.x += s.vel.x * dt
	hb := get_sludge_hitbox(s)
	if check_rect_solid(map_data, hb) {
		if s.vel.x > 0 {
			tile_x := int(hb.x + hb.width) / TILE_SIZE
			s.pos.x = f32(tile_x * TILE_SIZE) - f32(SLUDGE_HITBOX_W) / 2
		} else if s.vel.x < 0 {
			tile_x := int(hb.x) / TILE_SIZE
			s.pos.x = f32((tile_x + 1) * TILE_SIZE) + f32(SLUDGE_HITBOX_W) / 2
		}
		s.vel.x = 0
	}

	s.pos.y += s.vel.y * dt
	hb = get_sludge_hitbox(s)
	s.on_ground = false
	if check_rect_solid(map_data, hb) {
		if s.vel.y > 0 {
			tile_y := int(hb.y + hb.height) / TILE_SIZE
			s.pos.y = f32(tile_y * TILE_SIZE)
			s.on_ground = true
		} else if s.vel.y < 0 {
			tile_y := int(hb.y) / TILE_SIZE
			s.pos.y = f32((tile_y + 1) * TILE_SIZE) + f32(SLUDGE_HITBOX_H)
		}
		s.vel.y = 0
	}
}

@(private = "file")
sludge_advance_oneshot :: proc(s: ^Sludge, total_frames: int, dt: f32) -> bool {
	frame_dur: f32 = 1.0 / SLUDGE_ANIM_FPS
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
sludge_animate_loop :: proc(s: ^Sludge, total_frames: int, dt: f32) {
	if total_frames <= 1 {
		return
	}
	frame_dur: f32 = 1.0 / SLUDGE_ANIM_FPS
	s.anim_timer += dt
	if s.anim_timer >= frame_dur {
		s.anim_timer -= frame_dur
		s.current_frame += 1
		if int(s.current_frame) >= total_frames {
			s.current_frame = 0
		}
	}
}
