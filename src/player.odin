package game

import "vendor:raylib"
import dm "../dotmap"
import "core:math/rand"

Dash_Particle :: struct {
	pos:      raylib.Vector2,
	vel:      raylib.Vector2,
	lifetime: f32,
	max_life: f32,
	active:   bool,
}

Projectile_State :: enum {
	Inactive,
	Outgoing,
	Returning,
}

Quick_Attack_State :: enum {
	None,
	Attack1,
	Attack2,
}

X_Weapon :: enum {
	Base_Combo,
	Waveblade,
}

Y_Weapon :: enum {
	Boomerang,
	Orb,
	Water_Twister,
}

Waveblade_State :: enum {
	Idle,
	Attacking,
}

Orb_State :: enum {
	Inactive,
	Spawning,
	Flying,
}

Twister_State :: enum {
	Inactive,
	Outgoing,
	Stalled,
	Returning,
}

Projectile :: struct {
	state:         Projectile_State,
	pos:           raylib.Vector2,
	origin:        raylib.Vector2,
	apex_x:        f32,
	travel_timer:  f32,
	moving_left:   bool,
	attack_id:     u32,
	current_frame: f32,
	anim_timer:    f32,
	out_tex:       raylib.Texture2D,
	return_tex:    raylib.Texture2D,
	out_frames:    int,
	return_frames: int,
}

Player :: struct {
	pos:                raylib.Vector2, // bottom-center
	vel:                raylib.Vector2,
	on_ground:          bool,
	jumps_left:         int,
	facing_left:        bool,
	moving:             bool,
	hp:                 f32,
	stamina:            f32,
	max_hp:             f32,
	max_stamina:        f32,
	damage_multiplier:       f32,
	crit_chance:             f32,
	attack_speed_multiplier: f32,
	has_double_strike:       bool,
	damage_flash_timer: f32,
	invuln_timer:       f32,
	idle_tex:      raylib.Texture2D,
	move_tex:      raylib.Texture2D,
	jump_tex:      raylib.Texture2D,
	fall_tex:      raylib.Texture2D,
	dash_tex:      raylib.Texture2D,
	idle_frames:   int,
	move_frames:   int,
	jump_frames:   int,
	fall_frames:   int,
	dash_frames:   int,
	current_frame: f32,
	anim_timer:    f32,
	dashing:       bool,
	down_dashing:  bool,
	dash_timer:    f32,
	dash_cooldown: f32,
	dash_dir:      f32,
	particles:     [MAX_DASH_PARTICLES]Dash_Particle,
	projectile:    Projectile,
	// Downward dash ground impact
	dash_impact_tex:          raylib.Texture2D,
	dash_impact_frames:       int,
	dash_impact_active:       bool,
	dash_impact_pos:          raylib.Vector2,
	dash_impact_frame:        f32,
	dash_impact_anim_timer:   f32,
	dash_impact_damage_dealt: bool,
	// Quick attack (melee combo)
	quick_attack_state:         Quick_Attack_State,
	quick_attack_frame:         f32,
	quick_attack_timer:         f32,
	quick_attack_cooldown:      f32,
	quick_attack_damage_active: bool,
	chain_buffered:             bool,
	attack1_tex:                raylib.Texture2D,
	attack2_tex:                raylib.Texture2D,
	quick_attack_frames:        int,
	// Weapon slots
	x_weapon: X_Weapon,
	y_weapon: Y_Weapon,
	// Waveblade
	waveblade_idle_tex:      raylib.Texture2D,
	waveblade_attack_tex:    raylib.Texture2D,
	waveblade_idle_frames:   int,
	waveblade_attack_frames: int,
	waveblade_state:         Waveblade_State,
	waveblade_frame:         f32,
	waveblade_anim_timer:    f32,
	waveblade_damage_active: bool,
	// Orb (Y replacement)
	orb_spawn_tex:      raylib.Texture2D,
	orb_idle_tex:       raylib.Texture2D,
	orb_attack_tex:     raylib.Texture2D,
	orb_spawn_frames:   int,
	orb_idle_frames:    int,
	orb_attack_frames:  int,
	orb_state:          Orb_State,
	orb_pos:            raylib.Vector2,
	orb_facing_left:    bool,
	orb_frame:          f32,
	orb_anim_timer:     f32,
	orb_flight_timer:   f32,
	orb_attack_id:      u32,
	// Water Twister (Y replacement)
	twister_tex:          raylib.Texture2D,
	twister_frames:       int,
	twister_state:        Twister_State,
	twister_pos:          raylib.Vector2,
	twister_origin:       raylib.Vector2,
	twister_apex_x:       f32,
	twister_travel_timer: f32,
	twister_moving_left:  bool,
	twister_attack_id:    u32,
	twister_frame:        f32,
	twister_anim_timer:   f32,
	stats_capped:         bool,
}

init_player :: proc(p: ^Player, spawn: raylib.Vector2) {
	p.pos = spawn
	p.vel = {}
	p.on_ground = false
	p.jumps_left = MAX_JUMPS
	p.facing_left = false
	p.moving = false
	p.max_hp = PLAYER_MAX_HP
	p.max_stamina = PLAYER_MAX_STAMINA
	p.hp = p.max_hp
	p.stamina = p.max_stamina
	p.damage_multiplier = 0
	p.crit_chance = 0
	p.attack_speed_multiplier = 0
	p.has_double_strike = false
	p.damage_flash_timer = 0
	p.invuln_timer = 0
	p.current_frame = 0
	p.anim_timer = 0
	p.dashing = false
	p.down_dashing = false
	p.dash_timer = 0
	p.dash_cooldown = 0
	p.dash_dir = 1
	p.dash_impact_active = false

	p.idle_tex = raylib.LoadTexture("assets/sprites/player_idle.png")
	p.move_tex = raylib.LoadTexture("assets/sprites/player_move.png")
	p.jump_tex = raylib.LoadTexture("assets/sprites/player_jump.png")
	p.fall_tex = raylib.LoadTexture("assets/sprites/player_falling.png")
	p.dash_tex = raylib.LoadTexture("assets/sprites/player_dash.png")
	p.dash_impact_tex = raylib.LoadTexture("assets/sprites/player_downward_dash_slam.png")
	p.attack1_tex = raylib.LoadTexture("assets/sprites/player_base_melee_attack1.png")
	p.attack2_tex = raylib.LoadTexture("assets/sprites/player_base_melee_attack2.png")
	p.waveblade_idle_tex = raylib.LoadTexture("assets/sprites/player_waterblade.png")
	p.waveblade_attack_tex = raylib.LoadTexture("assets/sprites/player_waterblade_attack.png")
	p.orb_spawn_tex = raylib.LoadTexture("assets/sprites/player_waterorb_spawn.png")
	p.orb_idle_tex = raylib.LoadTexture("assets/sprites/player_waterorb_idle.png")
	p.orb_attack_tex = raylib.LoadTexture("assets/sprites/player_waterorb_attack.png")
	p.twister_tex = raylib.LoadTexture("assets/sprites/player_water_twister_attack.png")

	p.idle_frames = int(p.idle_tex.width) / SPRITE_SRC_SIZE
	p.move_frames = int(p.move_tex.width) / SPRITE_SRC_SIZE
	p.jump_frames = int(p.jump_tex.width) / SPRITE_SRC_SIZE
	p.fall_frames = int(p.fall_tex.width) / SPRITE_SRC_SIZE
	p.dash_frames = int(p.dash_tex.width) / SPRITE_SRC_SIZE
	p.dash_impact_frames = int(p.dash_impact_tex.width) / DASH_IMPACT_SIZE
	p.quick_attack_frames = int(p.attack1_tex.width) / QUICK_ATTACK_SRC_SIZE
	p.waveblade_idle_frames = int(p.waveblade_idle_tex.width) / WATERBLADE_SRC_SIZE
	p.waveblade_attack_frames = int(p.waveblade_attack_tex.width) / WATERBLADE_SRC_SIZE
	p.orb_spawn_frames = int(p.orb_spawn_tex.width) / WATERORB_SRC_SIZE
	p.orb_idle_frames = int(p.orb_idle_tex.width) / WATERORB_SRC_SIZE
	p.orb_attack_frames = int(p.orb_attack_tex.width) / WATERORB_SRC_SIZE
	p.twister_frames = int(p.twister_tex.width) / TWISTER_SRC_SIZE
	p.x_weapon = .Base_Combo
	p.y_weapon = .Boomerang
	p.waveblade_state = .Idle
	p.orb_state = .Inactive
	p.twister_state = .Inactive
	p.stats_capped = false

	p.projectile.out_tex = raylib.LoadTexture("assets/sprites/player_basic_projectile.png")
	p.projectile.return_tex = raylib.LoadTexture("assets/sprites/player_basic_projectile_returns.png")
	p.projectile.out_frames = int(p.projectile.out_tex.width) / PROJECTILE_SRC_SIZE
	p.projectile.return_frames = int(p.projectile.return_tex.width) / PROJECTILE_SRC_SIZE
}

reset_player_run_state :: proc(p: ^Player, spawn: raylib.Vector2) {
	p.pos = spawn
	p.vel = {}
	p.on_ground = false
	p.jumps_left = MAX_JUMPS
	p.facing_left = false
	p.moving = false
	p.max_hp = PLAYER_MAX_HP
	p.max_stamina = PLAYER_MAX_STAMINA
	p.hp = p.max_hp
	p.stamina = p.max_stamina
	p.damage_multiplier = 0
	p.crit_chance = 0
	p.attack_speed_multiplier = 0
	p.has_double_strike = false
	p.damage_flash_timer = 0
	p.invuln_timer = 0
	p.current_frame = 0
	p.anim_timer = 0
	p.dashing = false
	p.down_dashing = false
	p.dash_timer = 0
	p.dash_cooldown = 0
	p.dash_dir = 1
	p.dash_impact_active = false
	p.dash_impact_damage_dealt = false
	p.quick_attack_state = .None
	p.quick_attack_cooldown = 0
	p.quick_attack_damage_active = false
	p.chain_buffered = false
	p.x_weapon = .Base_Combo
	p.y_weapon = .Boomerang
	p.waveblade_state = .Idle
	p.waveblade_damage_active = false
	p.orb_state = .Inactive
	p.twister_state = .Inactive
	p.stats_capped = false
	p.projectile.state = .Inactive
	p.particles = {}
}

unload_player :: proc(p: ^Player) {
	raylib.UnloadTexture(p.idle_tex)
	raylib.UnloadTexture(p.move_tex)
	raylib.UnloadTexture(p.jump_tex)
	raylib.UnloadTexture(p.fall_tex)
	raylib.UnloadTexture(p.dash_tex)
	raylib.UnloadTexture(p.dash_impact_tex)
	raylib.UnloadTexture(p.attack1_tex)
	raylib.UnloadTexture(p.attack2_tex)
	raylib.UnloadTexture(p.waveblade_idle_tex)
	raylib.UnloadTexture(p.waveblade_attack_tex)
	raylib.UnloadTexture(p.orb_spawn_tex)
	raylib.UnloadTexture(p.orb_idle_tex)
	raylib.UnloadTexture(p.orb_attack_tex)
	raylib.UnloadTexture(p.twister_tex)
	raylib.UnloadTexture(p.projectile.out_tex)
	raylib.UnloadTexture(p.projectile.return_tex)
}

update_player :: proc(p: ^Player, map_data: ^dm.Dot_Map, dt: f32) {
	if p.dash_cooldown > 0 {
		p.dash_cooldown -= dt
	}
	if p.damage_flash_timer > 0 {
		p.damage_flash_timer -= dt
	}
	if p.invuln_timer > 0 {
		p.invuln_timer -= dt
	}

	p.stamina += STAMINA_REGEN_RATE * dt
	if p.stamina > p.max_stamina {
		p.stamina = p.max_stamina
	}

	update_dash_particles(p, dt)
	update_projectile(p, dt)

	if p.dash_impact_active {
		frame_dur: f32 = 1.0 / DASH_IMPACT_FPS
		p.dash_impact_anim_timer += dt
		if p.dash_impact_anim_timer >= frame_dur {
			p.dash_impact_anim_timer -= frame_dur
			p.dash_impact_frame += 1
			if int(p.dash_impact_frame) >= p.dash_impact_frames {
				p.dash_impact_active = false
			}
		}
	}

	if p.x_weapon == .Base_Combo {
		update_quick_attack(p, dt)
	} else {
		p.quick_attack_state = .None
		p.quick_attack_damage_active = false
	}

	update_waveblade(p, dt)
	update_orb(p, dt)
	update_twister(p, dt)

	if p.y_weapon == .Boomerang &&
	   p.projectile.state == .Inactive && !p.dashing && input_projectile() {
		fire_projectile(p)
	}

	if !p.dashing && p.dash_cooldown <= 0 && p.stamina >= DASH_STAMINA_COST && input_dash() {
		p.stamina -= DASH_STAMINA_COST
		p.dashing = true
		p.down_dashing = !p.on_ground && input_move_down()
		p.dash_timer = DASH_DURATION
		p.dash_dir = p.facing_left ? -1.0 : 1.0
		p.current_frame = 0
		p.anim_timer = 0
		play_sound(.Player_Dash)
	}

	if p.dashing {
		if p.down_dashing {
			p.vel.x = 0
			p.vel.y = DASH_DOWN_SPEED
			p.dash_timer -= dt

			spawn_dash_particles(p)
			move_and_collide(p, map_data, dt)

			if p.on_ground {
				p.dash_impact_active = true
				p.dash_impact_pos = p.pos
				p.dash_impact_frame = 0
				p.dash_impact_anim_timer = 0
				p.dash_impact_damage_dealt = false
				p.dashing = false
				p.down_dashing = false
				p.dash_cooldown = DASH_COOLDOWN
				p.vel.y = 0
			} else if p.dash_timer <= 0 {
				p.dashing = false
				p.down_dashing = false
				p.dash_cooldown = DASH_COOLDOWN
				p.vel.y = 0
			}
		} else {
			p.vel.x = DASH_SPEED * p.dash_dir
			p.vel.y = 0
			p.dash_timer -= dt

			spawn_dash_particles(p)
			move_and_collide(p, map_data, dt)

			if p.dash_timer <= 0 || p.vel.x == 0 {
				p.dashing = false
				p.dash_cooldown = DASH_COOLDOWN
				p.vel.x = 0
			}
		}

		if p.dash_frames > 1 {
			frame_dur := DASH_DURATION / f32(p.dash_frames)
			p.anim_timer += dt
			if p.anim_timer >= frame_dur {
				p.anim_timer -= frame_dur
				p.current_frame += 1
				if int(p.current_frame) >= p.dash_frames {
					p.current_frame = f32(p.dash_frames - 1)
				}
			}
		}
	} else {
		was_on_ground := p.on_ground
		was_rising := p.vel.y < 0

		move_x: f32 = 0
		if input_move_left() {
			move_x -= 1
		}
		if input_move_right() {
			move_x += 1
		}
		p.vel.x = move_x * PLAYER_SPEED

		if p.jumps_left > 0 && input_jump() {
			p.vel.y = JUMP_VELOCITY
			p.on_ground = false
			p.jumps_left -= 1
			play_sound(.Player_Jump)
		}

		p.vel.y += GRAVITY * dt
		if p.vel.y > MAX_FALL_SPEED {
			p.vel.y = MAX_FALL_SPEED
		}

		move_and_collide(p, map_data, dt)

		was_moving := p.moving
		p.moving = move_x != 0
		if move_x < 0 {
			p.facing_left = true
		} else if move_x > 0 {
			p.facing_left = false
		}

		rising := p.vel.y < 0
		anim_changed := (p.moving != was_moving) ||
			(p.on_ground != was_on_ground) ||
			(!p.on_ground && rising != was_rising)
		if anim_changed {
			p.current_frame = 0
			p.anim_timer = 0
		}

		if p.on_ground {
			frames := p.moving ? p.move_frames : p.idle_frames
			frame_dur: f32 = p.moving ? ANIM_FRAME_TIME : PLAYER_IDLE_ANIM_SPEED
			if frames > 1 {
				p.anim_timer += dt
				if p.anim_timer >= frame_dur {
					p.anim_timer -= frame_dur
					p.current_frame += 1
					if int(p.current_frame) >= frames {
						p.current_frame = 0
					}
				}
			}
		} else {
			frames := rising ? p.jump_frames : p.fall_frames
			if frames > 1 {
				p.anim_timer += dt
				if p.anim_timer >= ANIM_FRAME_TIME {
					p.anim_timer -= ANIM_FRAME_TIME
					p.current_frame += 1
					if int(p.current_frame) >= frames {
						p.current_frame = f32(frames - 1)
					}
				}
			}
		}
	}

	update_footsteps(!p.dashing && p.on_ground && p.moving, dt)
}

draw_player :: proc(p: ^Player) {
	draw_dash_particles(p)

	tex: raylib.Texture2D
	frames: int
	if p.dashing {
		tex = p.dash_tex
		frames = p.dash_frames
	} else if !p.on_ground {
		if p.vel.y < 0 {
			tex = p.jump_tex
			frames = p.jump_frames
		} else {
			tex = p.fall_tex
			frames = p.fall_frames
		}
	} else if p.moving {
		tex = p.move_tex
		frames = p.move_frames
	} else {
		tex = p.idle_tex
		frames = p.idle_frames
	}

	frame := int(p.current_frame)
	if frame >= frames {
		frame = frames - 1
	}

	src := raylib.Rectangle{
		f32(frame * SPRITE_SRC_SIZE), 0,
		p.facing_left ? -f32(SPRITE_SRC_SIZE) : f32(SPRITE_SRC_SIZE),
		f32(SPRITE_SRC_SIZE),
	}
	dst := raylib.Rectangle{
		p.pos.x - SPRITE_DST_SIZE / 2,
		p.pos.y - SPRITE_DST_SIZE,
		SPRITE_DST_SIZE,
		SPRITE_DST_SIZE,
	}
	tint := raylib.WHITE
	flashing := p.damage_flash_timer > 0
	if !flashing && p.invuln_timer > 0 {
		if int(p.invuln_timer * 20) % 2 == 0 {
			tint = raylib.Color{255, 255, 255, 120}
		}
	}
	if flashing {
		begin_hitflash(1.0)
	}
	raylib.DrawTexturePro(tex, src, dst, {0, 0}, 0, tint)
	if flashing {
		end_hitflash()
	}

	if p.quick_attack_state == .Attack1 || p.quick_attack_state == .Attack2 {
		qa_tex := p.quick_attack_state == .Attack1 ? p.attack1_tex : p.attack2_tex
		qa_frame := int(p.quick_attack_frame)
		if qa_frame >= p.quick_attack_frames {
			qa_frame = p.quick_attack_frames - 1
		}
		qa_src := raylib.Rectangle{
			f32(qa_frame * QUICK_ATTACK_SRC_SIZE), 0,
			p.facing_left ? -f32(QUICK_ATTACK_SRC_SIZE) : f32(QUICK_ATTACK_SRC_SIZE),
			f32(QUICK_ATTACK_SRC_SIZE),
		}
		offset_x: f32 = p.facing_left ? -16 : 16
		qa_dst := raylib.Rectangle{
			p.pos.x - f32(QUICK_ATTACK_SRC_SIZE) / 2 + offset_x,
			p.pos.y - f32(QUICK_ATTACK_SRC_SIZE),
			f32(QUICK_ATTACK_SRC_SIZE),
			f32(QUICK_ATTACK_SRC_SIZE),
		}
		raylib.DrawTexturePro(qa_tex, qa_src, qa_dst, {0, 0}, 0, raylib.WHITE)
	}
}

get_player_hitbox :: proc(p: ^Player) -> raylib.Rectangle {
	return {
		p.pos.x - f32(PLAYER_HITBOX_W) / 2,
		p.pos.y - f32(PLAYER_HITBOX_H),
		f32(PLAYER_HITBOX_W),
		f32(PLAYER_HITBOX_H),
	}
}

get_dash_impact_rect :: proc(p: ^Player) -> raylib.Rectangle {
	return {
		p.dash_impact_pos.x - f32(DASH_IMPACT_SIZE) / 2,
		p.dash_impact_pos.y - f32(DASH_IMPACT_SIZE),
		f32(DASH_IMPACT_SIZE),
		f32(DASH_IMPACT_SIZE),
	}
}

draw_dash_impact :: proc(p: ^Player) {
	if !p.dash_impact_active {
		return
	}
	frame := int(p.dash_impact_frame)
	if frame >= p.dash_impact_frames {
		frame = p.dash_impact_frames - 1
	}
	src := raylib.Rectangle{
		f32(frame * DASH_IMPACT_SIZE), 0,
		f32(DASH_IMPACT_SIZE),
		f32(DASH_IMPACT_SIZE),
	}
	dst := raylib.Rectangle{
		p.dash_impact_pos.x - f32(DASH_IMPACT_SIZE) / 2,
		p.dash_impact_pos.y - f32(DASH_IMPACT_SIZE),
		f32(DASH_IMPACT_SIZE),
		f32(DASH_IMPACT_SIZE),
	}
	raylib.DrawTexturePro(p.dash_impact_tex, src, dst, {0, 0}, 0, raylib.WHITE)
}

is_solid :: proc(map_data: ^dm.Dot_Map, tx, ty: int) -> bool {
	if ty < 0 || ty >= len(map_data.grid) {
		return true
	}
	row := map_data.grid[ty]
	if tx < 0 || tx >= len(row) {
		return true
	}
	sym := row[tx].symbol
	td, has := map_data.metadata[sym]
	if !has {
		return false
	}
	return !td.passable && len(td.tiles) > 0
}

check_rect_solid :: proc(map_data: ^dm.Dot_Map, rect: raylib.Rectangle) -> bool {
	x0 := int(rect.x) / TILE_SIZE
	y0 := int(rect.y) / TILE_SIZE
	x1 := int(rect.x + rect.width - 0.01) / TILE_SIZE
	y1 := int(rect.y + rect.height - 0.01) / TILE_SIZE

	for ty in y0 ..= y1 {
		for tx in x0 ..= x1 {
			if is_solid(map_data, tx, ty) {
				return true
			}
		}
	}
	return false
}

@(private = "file")
move_and_collide :: proc(p: ^Player, map_data: ^dm.Dot_Map, dt: f32) {
	p.pos.x += p.vel.x * dt
	hb := get_player_hitbox(p)
	if check_rect_solid(map_data, hb) {
		if p.vel.x > 0 {
			tile_x := int(hb.x + hb.width) / TILE_SIZE
			p.pos.x = f32(tile_x * TILE_SIZE) - f32(PLAYER_HITBOX_W) / 2
		} else if p.vel.x < 0 {
			tile_x := int(hb.x) / TILE_SIZE
			p.pos.x = f32((tile_x + 1) * TILE_SIZE) + f32(PLAYER_HITBOX_W) / 2
		}
		p.vel.x = 0
	}

	p.pos.y += p.vel.y * dt
	hb = get_player_hitbox(p)
	p.on_ground = false
	if check_rect_solid(map_data, hb) {
		if p.vel.y > 0 {
			tile_y := int(hb.y + hb.height) / TILE_SIZE
			p.pos.y = f32(tile_y * TILE_SIZE)
			p.on_ground = true
			p.jumps_left = MAX_JUMPS
		} else if p.vel.y < 0 {
			tile_y := int(hb.y) / TILE_SIZE
			p.pos.y = f32((tile_y + 1) * TILE_SIZE) + f32(PLAYER_HITBOX_H)
		}
		p.vel.y = 0
	}
}

fire_projectile :: proc(p: ^Player) {
	pr := &p.projectile
	pr.state = .Outgoing
	pr.moving_left = p.facing_left
	pr.pos = {p.pos.x, p.pos.y - f32(PLAYER_HITBOX_H) / 2}
	pr.origin = pr.pos
	dir: f32 = p.facing_left ? -1.0 : 1.0
	pr.apex_x = pr.origin.x + PROJECTILE_RANGE * dir
	pr.travel_timer = 0
	pr.current_frame = 0
	pr.anim_timer = 0
	pr.attack_id += 1
	play_sound(.Player_Base_Special_Attack)
}

get_projectile_rect :: proc(pr: ^Projectile) -> raylib.Rectangle {
	return {
		pr.pos.x - f32(PROJECTILE_SRC_SIZE) / 2,
		pr.pos.y - f32(PROJECTILE_SRC_SIZE) / 2,
		f32(PROJECTILE_SRC_SIZE),
		f32(PROJECTILE_SRC_SIZE),
	}
}

update_quick_attack :: proc(p: ^Player, dt: f32) {
	if p.quick_attack_cooldown > 0 {
		p.quick_attack_cooldown -= dt
	}

	p.quick_attack_damage_active = false

	attack_pressed := input_attack()

	switch p.quick_attack_state {
	case .None:
		if !p.dashing && p.quick_attack_cooldown <= 0 && attack_pressed {
			p.quick_attack_state = .Attack1
			p.quick_attack_frame = 0
			p.quick_attack_timer = 0
			p.chain_buffered = false
			play_sound(.Player_Base_Melee_Attacks)
		}

	case .Attack1:
		prev := int(p.quick_attack_frame)
		qa_advance_oneshot(p, dt)
		cur := int(p.quick_attack_frame)

		if prev < QUICK_ATTACK_HIT_FRAME && cur >= QUICK_ATTACK_HIT_FRAME {
			p.quick_attack_damage_active = true
		}

		if cur >= p.quick_attack_frames - QUICK_ATTACK_CHAIN_WINDOW && attack_pressed {
			p.chain_buffered = true
		}

		if cur >= p.quick_attack_frames {
			if p.chain_buffered {
				p.quick_attack_state = .Attack2
				p.quick_attack_frame = 0
				p.quick_attack_timer = 0
				play_sound(.Player_Base_Melee_Attacks)
			} else {
				p.quick_attack_state = .None
				p.quick_attack_cooldown = QUICK_ATTACK_COOLDOWN
			}
		}

	case .Attack2:
		prev := int(p.quick_attack_frame)
		qa_advance_oneshot(p, dt)
		cur := int(p.quick_attack_frame)

		if prev < QUICK_ATTACK_HIT_FRAME && cur >= QUICK_ATTACK_HIT_FRAME {
			p.quick_attack_damage_active = true
		}

		if cur >= p.quick_attack_frames {
			p.quick_attack_state = .None
			p.quick_attack_cooldown = QUICK_ATTACK_COOLDOWN
		}
	}
}

get_quick_attack_rect :: proc(p: ^Player) -> raylib.Rectangle {
	offset_x: f32 = p.facing_left ? -16 : 16
	return {
		p.pos.x - f32(QUICK_ATTACK_SRC_SIZE) / 2 + offset_x,
		p.pos.y - f32(QUICK_ATTACK_SRC_SIZE),
		f32(QUICK_ATTACK_SRC_SIZE),
		f32(QUICK_ATTACK_SRC_SIZE),
	}
}

@(private = "file")
qa_advance_oneshot :: proc(p: ^Player, dt: f32) {
	fps := QUICK_ATTACK_FPS * (1 + p.attack_speed_multiplier)
	total_dur: f32 = f32(p.quick_attack_frames) / fps
	p.quick_attack_timer += dt
	if p.quick_attack_timer >= total_dur {
		p.quick_attack_timer = total_dur
		p.quick_attack_frame = f32(p.quick_attack_frames)
	} else {
		p.quick_attack_frame = p.quick_attack_timer * fps
	}
}

update_waveblade :: proc(p: ^Player, dt: f32) {
	if p.x_weapon != .Waveblade {
		p.waveblade_state = .Idle
		p.waveblade_damage_active = false
		return
	}

	p.waveblade_damage_active = false

	switch p.waveblade_state {
	case .Idle:
		frame_dur: f32 = 1.0 / WATERBLADE_IDLE_FPS
		p.waveblade_anim_timer += dt
		if p.waveblade_anim_timer >= frame_dur {
			p.waveblade_anim_timer -= frame_dur
			p.waveblade_frame += 1
			if int(p.waveblade_frame) >= p.waveblade_idle_frames {
				p.waveblade_frame = 0
			}
		}
		if !p.dashing && p.stamina >= WATERBLADE_STAMINA_COST && input_attack() {
			p.stamina -= WATERBLADE_STAMINA_COST
			p.waveblade_state = .Attacking
			p.waveblade_frame = 0
			p.waveblade_anim_timer = 0
			play_sound(.Waterblade_Attack)
		}

	case .Attacking:
		prev := int(p.waveblade_frame)
		fps := WATERBLADE_ATTACK_FPS * (1 + p.attack_speed_multiplier)
		frame_dur: f32 = 1.0 / fps
		p.waveblade_anim_timer += dt
		if p.waveblade_anim_timer >= frame_dur {
			p.waveblade_anim_timer -= frame_dur
			p.waveblade_frame += 1
		}
		cur := int(p.waveblade_frame)

		if prev < WATERBLADE_HIT_FRAME && cur >= WATERBLADE_HIT_FRAME {
			p.waveblade_damage_active = true
		}

		if cur >= p.waveblade_attack_frames {
			p.waveblade_state = .Idle
			p.waveblade_frame = 0
			p.waveblade_anim_timer = 0
		}
	}
}

get_waveblade_rect :: proc(p: ^Player) -> raylib.Rectangle {
	offset_x: f32 = p.facing_left ? -WATERBLADE_OFFSET_X : WATERBLADE_OFFSET_X
	y_top := p.pos.y - f32(SPRITE_DST_SIZE) / 2 - f32(WATERBLADE_SRC_SIZE) / 2 - WATERBLADE_OFFSET_Y
	return {
		p.pos.x - f32(WATERBLADE_SRC_SIZE) / 2 + offset_x,
		y_top,
		f32(WATERBLADE_SRC_SIZE),
		f32(WATERBLADE_SRC_SIZE),
	}
}

draw_waveblade :: proc(p: ^Player) {
	if p.x_weapon != .Waveblade {
		return
	}

	tex:    raylib.Texture2D
	frames: int
	if p.waveblade_state == .Attacking {
		tex = p.waveblade_attack_tex
		frames = p.waveblade_attack_frames
	} else {
		tex = p.waveblade_idle_tex
		frames = p.waveblade_idle_frames
	}

	frame := int(p.waveblade_frame)
	if frame >= frames {
		frame = frames - 1
	}
	src := raylib.Rectangle{
		f32(frame * WATERBLADE_SRC_SIZE), 0,
		p.facing_left ? -f32(WATERBLADE_SRC_SIZE) : f32(WATERBLADE_SRC_SIZE),
		f32(WATERBLADE_SRC_SIZE),
	}
	offset_x: f32 = p.facing_left ? -WATERBLADE_OFFSET_X : WATERBLADE_OFFSET_X
	y_top := p.pos.y - f32(SPRITE_DST_SIZE) / 2 - f32(WATERBLADE_SRC_SIZE) / 2 - WATERBLADE_OFFSET_Y
	dst := raylib.Rectangle{
		p.pos.x - f32(WATERBLADE_SRC_SIZE) / 2 + offset_x,
		y_top,
		f32(WATERBLADE_SRC_SIZE),
		f32(WATERBLADE_SRC_SIZE),
	}
	raylib.DrawTexturePro(tex, src, dst, {0, 0}, 0, raylib.WHITE)
}

update_orb :: proc(p: ^Player, dt: f32) {
	if p.y_weapon != .Orb {
		p.orb_state = .Inactive
		return
	}

	switch p.orb_state {
	case .Inactive:
		if !p.dashing && p.stamina >= WATERORB_STAMINA_COST && input_projectile() {
			p.stamina -= WATERORB_STAMINA_COST
			p.orb_state = .Spawning
			p.orb_facing_left = p.facing_left
			offset_x: f32 = p.orb_facing_left ? -f32(TILE_SIZE) : f32(TILE_SIZE)
			p.orb_pos = {p.pos.x + offset_x, p.pos.y}
			p.orb_frame = 0
			p.orb_anim_timer = 0
			p.orb_attack_id += 1
			play_sound(.Water_Orb_Spawns)
		}

	case .Spawning:
		offset_x: f32 = p.orb_facing_left ? -f32(TILE_SIZE) : f32(TILE_SIZE)
		p.orb_pos = {p.pos.x + offset_x, p.pos.y}
		frame_dur: f32 = 1.0 / WATERORB_SPAWN_FPS
		p.orb_anim_timer += dt
		if p.orb_anim_timer >= frame_dur {
			p.orb_anim_timer -= frame_dur
			p.orb_frame += 1
		}
		if int(p.orb_frame) >= p.orb_spawn_frames {
			p.orb_state = .Flying
			p.orb_frame = 0
			p.orb_anim_timer = 0
			p.orb_flight_timer = WATERORB_FLIGHT_DURATION
			play_sound(.Water_Orb_Attack)
		}

	case .Flying:
		p.orb_flight_timer -= dt

		frame_dur: f32 = 1.0 / WATERORB_ATTACK_FPS
		p.orb_anim_timer += dt
		if p.orb_anim_timer >= frame_dur {
			p.orb_anim_timer -= frame_dur
			p.orb_frame += 1
			if int(p.orb_frame) >= p.orb_attack_frames {
				p.orb_frame = 0
			}
		}

		if p.orb_flight_timer <= 0 {
			p.orb_state = .Inactive
		}
	}
}

get_orb_rect :: proc(p: ^Player) -> raylib.Rectangle {
	return {
		p.orb_pos.x - f32(WATERORB_SRC_SIZE) / 2,
		p.orb_pos.y - f32(WATERORB_SRC_SIZE),
		f32(WATERORB_SRC_SIZE),
		f32(WATERORB_SRC_SIZE),
	}
}

update_twister :: proc(p: ^Player, dt: f32) {
	if p.y_weapon != .Water_Twister {
		p.twister_state = .Inactive
		return
	}

	advance_twister_anim :: proc(p: ^Player, dt: f32) {
		if p.twister_frames <= 1 {
			return
		}
		frame_dur: f32 = 1.0 / TWISTER_ANIM_FPS
		p.twister_anim_timer += dt
		if p.twister_anim_timer >= frame_dur {
			p.twister_anim_timer -= frame_dur
			p.twister_frame += 1
			if int(p.twister_frame) >= p.twister_frames {
				p.twister_frame = 0
			}
		}
	}

	switch p.twister_state {
	case .Inactive:
		if !p.dashing && p.on_ground && p.stamina >= TWISTER_STAMINA_COST && input_projectile() {
			p.stamina -= TWISTER_STAMINA_COST
			p.twister_state = .Outgoing
			p.twister_moving_left = p.facing_left
			p.twister_pos = {p.pos.x, p.pos.y}
			p.twister_origin = p.twister_pos
			dir: f32 = p.facing_left ? -1.0 : 1.0
			p.twister_apex_x = p.twister_origin.x + TWISTER_RANGE * dir
			p.twister_travel_timer = 0
			p.twister_frame = 0
			p.twister_anim_timer = 0
			p.twister_attack_id += 1
			play_sound(.Water_Orb_Attack)
		}

	case .Outgoing:
		p.twister_travel_timer += dt
		t := p.twister_travel_timer / TWISTER_OUT_DURATION
		eased := ease_out_cubic(t)
		p.twister_pos.x = p.twister_origin.x + (p.twister_apex_x - p.twister_origin.x) * eased
		if p.twister_travel_timer >= TWISTER_OUT_DURATION {
			p.twister_pos.x = p.twister_apex_x
			p.twister_state = .Stalled
		}
		advance_twister_anim(p, dt)

	case .Stalled:
		if input_projectile() {
			p.twister_state = .Returning
			p.twister_travel_timer = 0
			p.twister_attack_id += 1
		}
		advance_twister_anim(p, dt)

	case .Returning:
		target := raylib.Vector2{p.pos.x, p.pos.y}
		diff := target - p.twister_pos
		dist := raylib.Vector2Length(diff)
		if dist <= TWISTER_RETURN_STOP_DIST {
			p.twister_state = .Inactive
			return
		}
		p.twister_travel_timer += dt
		speed := TWISTER_RETURN_MAX_SPEED * ease_in_cubic(p.twister_travel_timer / TWISTER_RETURN_ACCEL)
		dir := diff / dist
		p.twister_pos += dir * speed * dt
		p.twister_moving_left = dir.x < 0
		advance_twister_anim(p, dt)
	}
}

get_twister_rect :: proc(p: ^Player) -> raylib.Rectangle {
	return {
		p.twister_pos.x - f32(TWISTER_SRC_SIZE) / 2,
		p.twister_pos.y - f32(TWISTER_SRC_SIZE),
		f32(TWISTER_SRC_SIZE),
		f32(TWISTER_SRC_SIZE),
	}
}

draw_twister :: proc(p: ^Player) {
	if p.y_weapon != .Water_Twister || p.twister_state == .Inactive {
		return
	}
	frame := int(p.twister_frame)
	if frame >= p.twister_frames {
		frame = p.twister_frames - 1
	}
	src := raylib.Rectangle{
		f32(frame * TWISTER_SRC_SIZE), 0,
		p.twister_moving_left ? -f32(TWISTER_SRC_SIZE) : f32(TWISTER_SRC_SIZE),
		f32(TWISTER_SRC_SIZE),
	}
	dst := raylib.Rectangle{
		p.twister_pos.x - f32(TWISTER_SRC_SIZE) / 2,
		p.twister_pos.y - f32(TWISTER_SRC_SIZE),
		f32(TWISTER_SRC_SIZE),
		f32(TWISTER_SRC_SIZE),
	}
	raylib.DrawTexturePro(p.twister_tex, src, dst, {0, 0}, 0, raylib.WHITE)
}

draw_orb :: proc(p: ^Player) {
	if p.y_weapon != .Orb || p.orb_state == .Inactive {
		return
	}

	tex:    raylib.Texture2D
	frames: int
	switch p.orb_state {
	case .Spawning:
		tex = p.orb_spawn_tex
		frames = p.orb_spawn_frames
	case .Flying:
		tex = p.orb_attack_tex
		frames = p.orb_attack_frames
	case .Inactive:
		return
	}

	frame := int(p.orb_frame)
	if frame >= frames {
		frame = frames - 1
	}
	src := raylib.Rectangle{
		f32(frame * WATERORB_SRC_SIZE), 0,
		p.orb_facing_left ? -f32(WATERORB_SRC_SIZE) : f32(WATERORB_SRC_SIZE),
		f32(WATERORB_SRC_SIZE),
	}
	dst := raylib.Rectangle{
		p.orb_pos.x - f32(WATERORB_SRC_SIZE) / 2,
		p.orb_pos.y - f32(WATERORB_SRC_SIZE),
		f32(WATERORB_SRC_SIZE),
		f32(WATERORB_SRC_SIZE),
	}
	raylib.DrawTexturePro(tex, src, dst, {0, 0}, 0, raylib.WHITE)
}



compute_player_damage :: proc(p: ^Player, base: f32, base_crit: f32 = 0) -> f32 {
	dmg := base * (1 + p.damage_multiplier)
	crit := base_crit + p.crit_chance
	if crit > 0 && rand.float32() < crit {
		dmg *= CRIT_DAMAGE_MULTIPLIER
	}
	return dmg
}

apply_damage_to_player :: proc(p: ^Player, amount: f32) {
	if p.invuln_timer > 0 {
		return
	}
	p.hp -= amount
	if p.hp < 0 {
		p.hp = 0
	}
	p.damage_flash_timer = DAMAGE_FLASH_DURATION
	p.invuln_timer = PLAYER_INVULN_DURATION
}

update_projectile :: proc(p: ^Player, dt: f32) {
	pr := &p.projectile
	switch pr.state {
	case .Inactive:
		return

	case .Outgoing:
		pr.travel_timer += dt
		t := pr.travel_timer / PROJECTILE_OUT_DURATION
		eased := ease_out_cubic(t)
		pr.pos.x = pr.origin.x + (pr.apex_x - pr.origin.x) * eased
		if pr.travel_timer >= PROJECTILE_OUT_DURATION {
			pr.pos.x = pr.apex_x
			pr.state = .Returning
			pr.travel_timer = 0
			pr.current_frame = 0
			pr.anim_timer = 0
		}
		advance_projectile_anim(pr, pr.out_frames, dt)

	case .Returning:
		target := raylib.Vector2{p.pos.x, p.pos.y - f32(PLAYER_HITBOX_H) / 2}
		diff := target - pr.pos
		dist := raylib.Vector2Length(diff)
		if dist <= PROJECTILE_RETURN_STOP_DIST {
			pr.state = .Inactive
			return
		}
		pr.travel_timer += dt
		speed := PROJECTILE_RETURN_MAX_SPEED * ease_in_cubic(pr.travel_timer / PROJECTILE_RETURN_ACCEL)
		dir := diff / dist
		pr.pos += dir * speed * dt
		pr.moving_left = dir.x < 0
		advance_projectile_anim(pr, pr.return_frames, dt)
	}
}

@(private = "file")
ease_out_cubic :: proc(t: f32) -> f32 {
	tc := clamp(t, 0, 1)
	inv := 1 - tc
	return 1 - inv * inv * inv
}

@(private = "file")
ease_in_cubic :: proc(t: f32) -> f32 {
	tc := clamp(t, 0, 1)
	return tc * tc * tc
}

draw_projectile :: proc(p: ^Player) {
	pr := &p.projectile
	if pr.state == .Inactive {
		return
	}

	tex:    raylib.Texture2D
	frames: int
	if pr.state == .Outgoing {
		tex = pr.out_tex
		frames = pr.out_frames
	} else {
		tex = pr.return_tex
		frames = pr.return_frames
	}

	frame := int(pr.current_frame)
	if frame >= frames {
		frame = frames - 1
	}

	src := raylib.Rectangle{
		f32(frame * PROJECTILE_SRC_SIZE), 0,
		pr.moving_left ? -f32(PROJECTILE_SRC_SIZE) : f32(PROJECTILE_SRC_SIZE),
		f32(PROJECTILE_SRC_SIZE),
	}
	dst := raylib.Rectangle{
		pr.pos.x - f32(PROJECTILE_SRC_SIZE) / 2,
		pr.pos.y - f32(PROJECTILE_SRC_SIZE) / 2,
		f32(PROJECTILE_SRC_SIZE),
		f32(PROJECTILE_SRC_SIZE),
	}
	raylib.DrawTexturePro(tex, src, dst, {0, 0}, 0, raylib.WHITE)
}

@(private = "file")
advance_projectile_anim :: proc(pr: ^Projectile, total_frames: int, dt: f32) {
	if total_frames <= 1 {
		return
	}
	frame_dur: f32 = 1.0 / PROJECTILE_ANIM_FPS
	pr.anim_timer += dt
	if pr.anim_timer >= frame_dur {
		pr.anim_timer -= frame_dur
		pr.current_frame += 1
		if int(pr.current_frame) >= total_frames {
			pr.current_frame = 0
		}
	}
}

@(private = "file")
spawn_dash_particles :: proc(p: ^Player) {
	spawned := 0
	for &part in p.particles {
		if spawned >= 2 {
			break
		}
		if !part.active {
			part.active = true
			part.pos = {
				p.pos.x + (rand.float32() * 6 - 3),
				p.pos.y - (rand.float32() * 8 + 2),
			}
			part.vel = {
				-p.dash_dir * (rand.float32() * 40 + 20),
				rand.float32() * 40 - 20,
			}
			part.max_life = rand.float32() * 0.15 + 0.15
			part.lifetime = part.max_life
			spawned += 1
		}
	}
}

@(private = "file")
update_dash_particles :: proc(p: ^Player, dt: f32) {
	for &part in p.particles {
		if part.active {
			part.pos.x += part.vel.x * dt
			part.pos.y += part.vel.y * dt
			part.lifetime -= dt
			if part.lifetime <= 0 {
				part.active = false
			}
		}
	}
}

@(private = "file")
draw_dash_particles :: proc(p: ^Player) {
	for &part in p.particles {
		if part.active {
			t := part.lifetime / part.max_life
			alpha := u8(255 * t)
			size := 1.0 + t * 1.5
			color := raylib.Color{255, 255, 255, alpha}
			raylib.DrawCircleV(part.pos, size, color)
		}
	}
}
