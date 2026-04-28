package game

import "vendor:raylib"
import dm "../dotmap"
import "core:math"
import "core:math/rand"

Nergal_State :: enum {
	Unspawned,
	Idle,
	Approaching,
	Attacking,
	Cooldown,
	Dying,
	Dead,
}

Nergal_Phase :: enum {
	Phase_1,
	Phase_2,
	Phase_3,
}

Acid_Particle :: struct {
	pos:     raylib.Vector2,
	vel:     raylib.Vector2,
	life:    f32,
	max_life: f32,
	size:    f32,
	color:   raylib.Color,
	active:  bool,
}

Nergal_Bullet :: struct {
	pos:    raylib.Vector2,
	vel:    raylib.Vector2,
	life:   f32,
	color:  raylib.Color,
	active: bool,
}

Nergal :: struct {
	pos:                    raylib.Vector2,
	spawn_pos:              raylib.Vector2,
	vel:                    raylib.Vector2,
	state:                  Nergal_State,
	phase:                  Nergal_Phase,
	on_ground:              bool,
	facing_left:            bool,
	hp:                     f32,
	current_frame:          f32,
	anim_timer:             f32,
	state_timer:            f32,
	death_timer:            f32,
	damage_flash_timer:     f32,
	stagger_timer:          f32,
	slow_timer:             f32,
	hit_dealt_this_attack:  bool,
	summoned_phase_2:       bool,
	bullet_timer:           f32,
	bullet_burst_angle:     f32,
	last_projectile_hit_id: u32,
	last_orb_hit_id:        u32,
	last_twister_hit_id:    u32,
	acid_particles:         [NERGAL_ACID_PARTICLE_COUNT]Acid_Particle,
	bullets:                [NERGAL_BULLET_COUNT]Nergal_Bullet,
	idle_tex:               raylib.Texture2D,
	move_tex:               raylib.Texture2D,
	idle_frames:            int,
	move_frames:            int,
}

@(private = "file")
ACID_PALETTE := [3]raylib.Color{
	{0x9a, 0xeb, 0x00, 0xff},
	{0x51, 0xa2, 0x00, 0xff},
	{0x38, 0x6d, 0x00, 0xff},
}

init_nergal :: proc(n: ^Nergal) {
	n.idle_tex = raylib.LoadTexture("assets/sprites/boss_nergal_attacking_or_idle.png")
	n.move_tex = raylib.LoadTexture("assets/sprites/boss_nergal_move.png")
	n.idle_frames = int(n.idle_tex.width) / NERGAL_SRC_SIZE
	n.move_frames = int(n.move_tex.width) / NERGAL_SRC_SIZE
	n.state = .Dead
}

unload_nergal :: proc(n: ^Nergal) {
	raylib.UnloadTexture(n.idle_tex)
	raylib.UnloadTexture(n.move_tex)
}

set_nergal_dead :: proc(n: ^Nergal) {
	n.state = .Dead
	for &p in n.acid_particles {
		p.active = false
	}
	for &b in n.bullets {
		b.active = false
	}
}

spawn_nergal :: proc(n: ^Nergal, pos: raylib.Vector2) {
	for &p in n.acid_particles {
		p.active = false
	}
	for &b in n.bullets {
		b.active = false
	}
	n.pos = pos
	n.spawn_pos = pos
	n.vel = {0, 0}
	n.state = .Idle
	n.phase = .Phase_1
	n.hp = NERGAL_HP
	n.facing_left = true
	n.current_frame = 0
	n.anim_timer = 0
	n.state_timer = 0
	n.damage_flash_timer = 0
	n.stagger_timer = 0
	n.slow_timer = 0
	n.hit_dealt_this_attack = false
	n.summoned_phase_2 = false
	n.bullet_timer = 0
	n.bullet_burst_angle = 0
	n.last_projectile_hit_id = 0
	n.last_orb_hit_id = 0
	n.last_twister_hit_id = 0
	n.on_ground = false
	n.death_timer = 0
}

nergal_alive :: proc(n: ^Nergal) -> bool {
	return n.state != .Dead && n.state != .Unspawned
}

get_nergal_hitbox :: proc(n: ^Nergal) -> raylib.Rectangle {
	return {
		n.pos.x - f32(NERGAL_HITBOX_W) / 2,
		n.pos.y - f32(NERGAL_HITBOX_H),
		f32(NERGAL_HITBOX_W),
		f32(NERGAL_HITBOX_H),
	}
}

@(private = "file")
get_nergal_attack_rect :: proc(n: ^Nergal) -> raylib.Rectangle {
	w: f32 = NERGAL_ATTACK_RANGE
	h: f32 = NERGAL_HITBOX_H
	x: f32
	if n.facing_left {
		x = n.pos.x - f32(NERGAL_HITBOX_W) / 2 - w
	} else {
		x = n.pos.x + f32(NERGAL_HITBOX_W) / 2
	}
	return {x, n.pos.y - h, w, h}
}

update_nergal :: proc(
	n: ^Nergal,
	p: ^Player,
	soldiers: ^Soldier_Pool,
	map_data: ^dm.Dot_Map,
	dt: f32,
) {
	update_acid_particles(n, dt)
	update_nergal_bullets(n, p, map_data, dt)

	if n.state == .Unspawned || n.state == .Dead {
		return
	}

	prev_hp := n.hp
	prev_state := n.state

	if n.damage_flash_timer > 0 {
		n.damage_flash_timer -= dt
	}
	if n.slow_timer > 0 {
		n.slow_timer -= dt
	}

	if n.state != .Dying {
		update_nergal_phase(n, soldiers)
		fire_bullet_hell_if_needed(n, p, dt)
	}

	if n.stagger_timer > 0 && n.state != .Dying {
		n.stagger_timer -= dt
		nergal_apply_gravity(n, dt)
		nergal_move_and_collide(n, map_data, dt)
	} else {
		switch n.state {
		case .Unspawned, .Dead:
			// handled above

		case .Idle:
			n.vel.x = 0
			nergal_apply_gravity(n, dt)
			nergal_move_and_collide(n, map_data, dt)
			nergal_animate_loop(n, n.idle_frames, dt)
			n.facing_left = p.pos.x < n.pos.x
			n.state = .Approaching
			n.current_frame = 0
			n.anim_timer = 0

		case .Approaching:
			dx := p.pos.x - n.pos.x
			abs_dx := abs(dx)
			FACE_DEADZONE :: f32(2.0)
			if abs_dx > FACE_DEADZONE {
				n.facing_left = dx < 0
			}
			speed: f32 = NERGAL_SPEED
			if n.phase == .Phase_3 {
				speed *= NERGAL_PHASE_3_SPEED_MULT
			}
			if n.slow_timer > 0 {
				speed *= SLUDGE_SLOW_FACTOR
			}
			MOVE_DEADZONE :: f32(4.0)
			if abs_dx > NERGAL_ATTACK_RANGE * 0.6 {
				if abs_dx > MOVE_DEADZONE {
					n.vel.x = n.facing_left ? -speed : speed
				} else {
					n.vel.x = 0
				}
			} else {
				n.vel.x = 0
				n.state = .Attacking
				n.state_timer = NERGAL_ATTACK_DURATION
				n.current_frame = 0
				n.anim_timer = 0
				n.hit_dealt_this_attack = false
				spawn_acid_spray(n, p)
				play_sound(.Enemy_Devil_Attacks)
			}
			nergal_apply_gravity(n, dt)
			nergal_move_and_collide(n, map_data, dt)
			nergal_animate_loop(n, n.move_frames, dt)

		case .Attacking:
			n.vel.x = 0
			nergal_apply_gravity(n, dt)
			nergal_move_and_collide(n, map_data, dt)
			nergal_animate_loop(n, n.idle_frames, dt)
			prev_timer := n.state_timer
			n.state_timer -= dt
			hit_t: f32 = NERGAL_ATTACK_DURATION - NERGAL_HIT_AT
			if !n.hit_dealt_this_attack && prev_timer > hit_t && n.state_timer <= hit_t {
				if raylib.CheckCollisionRecs(get_nergal_attack_rect(n), get_player_hitbox(p)) {
					if !p.dashing {
						apply_damage_to_player(p, NERGAL_ATTACK_DAMAGE)
					}
				}
				n.hit_dealt_this_attack = true
			}
			if n.state_timer <= 0 {
				n.state = .Cooldown
				n.state_timer = NERGAL_ATTACK_COOLDOWN
				n.current_frame = 0
				n.anim_timer = 0
			}

		case .Cooldown:
			dx := p.pos.x - n.pos.x
			abs_dx := abs(dx)
			if abs_dx > 4.0 {
				n.facing_left = dx < 0
			}
			speed: f32 = NERGAL_SPEED
			if n.phase == .Phase_3 {
				speed *= NERGAL_PHASE_3_SPEED_MULT
			}
			if n.slow_timer > 0 {
				speed *= SLUDGE_SLOW_FACTOR
			}
			if abs_dx > NERGAL_ATTACK_RANGE * 0.6 {
				n.vel.x = n.facing_left ? -speed : speed
			} else {
				n.vel.x = 0
			}
			nergal_apply_gravity(n, dt)
			nergal_move_and_collide(n, map_data, dt)
			nergal_animate_loop(n, n.move_frames, dt)
			n.state_timer -= dt
			if n.state_timer <= 0 {
				n.state = .Approaching
				n.current_frame = 0
				n.anim_timer = 0
			}

		case .Dying:
			n.vel.x = 0
			nergal_apply_gravity(n, dt)
			nergal_move_and_collide(n, map_data, dt)
			n.death_timer -= dt
			if n.death_timer <= 0 {
				n.state = .Dead
			}
		}
	}

	apply_player_damage_to_nergal(n, p)

	if n.state == .Dying && prev_state != .Dying {
		play_sound(.Enemy_Dies)
	} else if n.hp < prev_hp {
		play_sound(.Hit)
	}
}

@(private = "file")
update_nergal_phase :: proc(n: ^Nergal, soldiers: ^Soldier_Pool) {
	new_phase := n.phase
	if n.hp <= NERGAL_PHASE_3_HP {
		new_phase = .Phase_3
	} else if n.hp <= NERGAL_PHASE_2_HP {
		new_phase = .Phase_2
	} else {
		new_phase = .Phase_1
	}
	if new_phase == n.phase {
		return
	}
	n.phase = new_phase
	if (n.phase == .Phase_2 || n.phase == .Phase_3) && !n.summoned_phase_2 {
		n.summoned_phase_2 = true
		summon_pos := raylib.Vector2{n.pos.x, n.pos.y}
		force_spawn_soldiers_at(soldiers, summon_pos, NERGAL_SUMMON_COUNT)
		play_sound(.Enemy_Soldier_Attacks)
	}
}

@(private = "file")
fire_bullet_hell_if_needed :: proc(n: ^Nergal, p: ^Player, dt: f32) {
	if n.phase != .Phase_3 {
		return
	}
	n.bullet_timer -= dt
	if n.bullet_timer > 0 {
		return
	}
	interval: f32 = NERGAL_BULLET_INTERVAL
	if n.hp <= NERGAL_BULLET_FRENZY_HP {
		interval /= 3
	} else if n.hp <= NERGAL_BULLET_RAGE_HP {
		interval /= 2
	}
	n.bullet_timer = interval
	origin := raylib.Vector2{n.pos.x, n.pos.y - f32(NERGAL_HITBOX_H) / 2}
	step := f32(math.TAU) / f32(NERGAL_BULLET_PER_BURST)
	for i in 0 ..< NERGAL_BULLET_PER_BURST {
		angle := n.bullet_burst_angle + f32(i) * step
		dir := raylib.Vector2{math.cos(angle), math.sin(angle)}
		spawn_nergal_bullet(n, origin, dir)
	}
	n.bullet_burst_angle += step * 0.5
	if n.bullet_burst_angle > f32(math.TAU) {
		n.bullet_burst_angle -= f32(math.TAU)
	}
	play_sound(.Player_Base_Special_Attack)
}

@(private = "file")
spawn_nergal_bullet :: proc(n: ^Nergal, pos: raylib.Vector2, dir: raylib.Vector2) {
	for &b in n.bullets {
		if b.active {
			continue
		}
		b.active = true
		b.pos = pos
		b.vel = {dir.x * NERGAL_BULLET_SPEED, dir.y * NERGAL_BULLET_SPEED}
		b.life = NERGAL_BULLET_LIFE
		b.color = ACID_PALETTE[rand.int_max(3)]
		return
	}
}

@(private = "file")
update_nergal_bullets :: proc(n: ^Nergal, p: ^Player, map_data: ^dm.Dot_Map, dt: f32) {
	for &b in n.bullets {
		if !b.active {
			continue
		}
		b.life -= dt
		if b.life <= 0 {
			b.active = false
			continue
		}
		b.pos.x += b.vel.x * dt
		b.pos.y += b.vel.y * dt
		rect := raylib.Rectangle{
			b.pos.x - NERGAL_BULLET_RADIUS,
			b.pos.y - NERGAL_BULLET_RADIUS,
			NERGAL_BULLET_RADIUS * 2,
			NERGAL_BULLET_RADIUS * 2,
		}
		if check_rect_solid(map_data, rect) {
			b.active = false
			continue
		}
		if !p.dashing && raylib.CheckCollisionRecs(rect, get_player_hitbox(p)) {
			apply_damage_to_player(p, NERGAL_BULLET_DAMAGE)
			b.active = false
		}
	}
}

@(private = "file")
spawn_acid_spray :: proc(n: ^Nergal, p: ^Player) {
	mouth_offset_x: f32 = n.facing_left ? -8 : 8
	origin := raylib.Vector2{
		n.pos.x + mouth_offset_x,
		n.pos.y - f32(NERGAL_HITBOX_H) * 0.55,
	}
	dx := p.pos.x - origin.x
	dy := (p.pos.y - f32(PLAYER_HITBOX_H) * 0.5) - origin.y
	base_angle := math.atan2(dy, dx)
	spawned := 0
	for &part in n.acid_particles {
		if spawned >= NERGAL_ACID_PARTICLES_PER_SHOT {
			break
		}
		if part.active {
			continue
		}
		angle := base_angle + rand.float32_range(-NERGAL_ACID_CONE_RADIANS, NERGAL_ACID_CONE_RADIANS) / 2
		speed := rand.float32_range(NERGAL_ACID_PARTICLE_SPEED_MIN, NERGAL_ACID_PARTICLE_SPEED_MAX)
		life := rand.float32_range(NERGAL_ACID_PARTICLE_LIFE * 0.7, NERGAL_ACID_PARTICLE_LIFE)
		part.active = true
		part.pos = origin
		part.vel = {math.cos(angle) * speed, math.sin(angle) * speed}
		part.life = life
		part.max_life = life
		part.size = rand.float32_range(NERGAL_ACID_PARTICLE_SIZE * 0.7, NERGAL_ACID_PARTICLE_SIZE * 1.4)
		part.color = ACID_PALETTE[rand.int_max(3)]
		spawned += 1
	}
}

@(private = "file")
update_acid_particles :: proc(n: ^Nergal, dt: f32) {
	for &part in n.acid_particles {
		if !part.active {
			continue
		}
		part.life -= dt
		if part.life <= 0 {
			part.active = false
			continue
		}
		part.vel.y += NERGAL_ACID_PARTICLE_GRAVITY * dt
		part.pos.x += part.vel.x * dt
		part.pos.y += part.vel.y * dt
	}
}

draw_nergal :: proc(n: ^Nergal) {
	if n.state != .Unspawned && n.state != .Dead {
		tex:    raylib.Texture2D
		frames: int
		switch n.state {
		case .Approaching, .Cooldown:
			tex = n.move_tex
			frames = n.move_frames
		case .Idle, .Attacking, .Dying:
			tex = n.idle_tex
			frames = n.idle_frames
		case .Unspawned, .Dead:
			return
		}

		frame := int(n.current_frame)
		if frame >= frames {
			frame = frames - 1
		}

		src := raylib.Rectangle{
			f32(frame * NERGAL_SRC_SIZE), 0,
			n.facing_left ? -f32(NERGAL_SRC_SIZE) : f32(NERGAL_SRC_SIZE),
			f32(NERGAL_SRC_SIZE),
		}
		dst := raylib.Rectangle{
			n.pos.x - f32(NERGAL_DRAW_SIZE) / 2,
			n.pos.y - f32(NERGAL_DRAW_SIZE),
			f32(NERGAL_DRAW_SIZE),
			f32(NERGAL_DRAW_SIZE),
		}

		tint := raylib.WHITE
		flashing := false
		if n.state == .Dying {
			t := clamp(n.death_timer / NERGAL_DEATH_DURATION, 0, 1)
			tint.a = u8(255.0 * t)
		} else if n.damage_flash_timer > 0 {
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

	for &part in n.acid_particles {
		if !part.active {
			continue
		}
		t := clamp(part.life / part.max_life, 0, 1)
		col := part.color
		col.a = u8(255.0 * t)
		raylib.DrawCircleV(part.pos, part.size, col)
	}

	for &b in n.bullets {
		if !b.active {
			continue
		}
		raylib.DrawCircleV(b.pos, NERGAL_BULLET_RADIUS, b.color)
		inner := raylib.Color{0xff, 0xff, 0xff, 0xc0}
		raylib.DrawCircleV(b.pos, NERGAL_BULLET_RADIUS * 0.4, inner)
	}
}

draw_nergal_hp_bar :: proc(n: ^Nergal) {
	if !nergal_alive(n) {
		return
	}
	BAR_W :: i32(240)
	BAR_H :: i32(8)
	BAR_X :: SCREEN_WIDTH/2 - BAR_W/2
	BAR_Y :: i32(30)
	raylib.DrawRectangle(BAR_X - 1, BAR_Y - 1, BAR_W + 2, BAR_H + 2, raylib.Color{0, 0, 0, 220})
	fill_w := i32(f32(BAR_W) * (n.hp / NERGAL_HP))
	if fill_w < 0 {
		fill_w = 0
	}
	raylib.DrawRectangle(BAR_X, BAR_Y, fill_w, BAR_H, raylib.Color{0x9a, 0xeb, 0x00, 0xff})
	label: cstring = "NERGAL"
	tw := raylib.MeasureText(label, 8)
	raylib.DrawText(label, SCREEN_WIDTH/2 - tw/2, BAR_Y - 10, 8, raylib.Color{0x9a, 0xeb, 0x00, 0xff})
}

@(private = "file")
nergal_enter_dying :: proc(n: ^Nergal) {
	n.state = .Dying
	n.death_timer = NERGAL_DEATH_DURATION
	n.vel.x = 0
	n.current_frame = 0
	n.anim_timer = 0
	for &part in n.acid_particles {
		part.active = false
	}
	for &b in n.bullets {
		b.active = false
	}
}

@(private = "file")
apply_player_damage_to_nergal :: proc(n: ^Nergal, p: ^Player) {
	if n.state == .Dying || n.state == .Dead {
		return
	}

	if p.projectile.state != .Inactive && n.last_projectile_hit_id != p.projectile.attack_id {
		if raylib.CheckCollisionRecs(get_projectile_rect(&p.projectile), get_nergal_hitbox(n)) {
			n.hp -= compute_player_damage(p, PROJECTILE_DAMAGE)
			n.damage_flash_timer = DAMAGE_FLASH_DURATION
			n.last_projectile_hit_id = p.projectile.attack_id
			if n.hp <= 0 {
				nergal_enter_dying(n)
				return
			}
		}
	}

	if p.dash_impact_active && !p.dash_impact_damage_dealt {
		if raylib.CheckCollisionRecs(get_dash_impact_rect(p), get_nergal_hitbox(n)) {
			n.hp -= compute_player_damage(p, DASH_IMPACT_DAMAGE)
			n.damage_flash_timer = DAMAGE_FLASH_DURATION
			if n.hp <= 0 {
				nergal_enter_dying(n)
				return
			}
		}
	}

	if p.quick_attack_damage_active {
		if raylib.CheckCollisionRecs(get_quick_attack_rect(p), get_nergal_hitbox(n)) {
			base: f32 = p.quick_attack_state == .Attack1 ? QUICK_ATTACK_DAMAGE_1 : QUICK_ATTACK_DAMAGE_2
			dmg := compute_player_damage(p, base)
			if p.has_double_strike && p.quick_attack_state == .Attack2 &&
			   rand.float32() < DOUBLE_STRIKE_CHANCE {
				dmg *= 2
			}
			n.hp -= dmg
			n.damage_flash_timer = DAMAGE_FLASH_DURATION
			if n.hp <= 0 {
				nergal_enter_dying(n)
				return
			}
			n.stagger_timer = NERGAL_STAGGER_DURATION
			kb_dir: f32 = p.facing_left ? -1.0 : 1.0
			n.vel.x = kb_dir * NERGAL_STAGGER_KNOCKBACK
		}
	}

	if p.waveblade_damage_active {
		if raylib.CheckCollisionRecs(get_waveblade_rect(p), get_nergal_hitbox(n)) {
			dmg := compute_player_damage(p, WATERBLADE_DAMAGE, WATERBLADE_CRIT_CHANCE)
			n.hp -= dmg
			n.damage_flash_timer = DAMAGE_FLASH_DURATION
			if n.hp <= 0 {
				nergal_enter_dying(n)
				return
			}
			n.stagger_timer = NERGAL_STAGGER_DURATION
			kb_dir: f32 = p.facing_left ? -1.0 : 1.0
			n.vel.x = kb_dir * NERGAL_STAGGER_KNOCKBACK
		}
	}

	if p.twister_state != .Inactive && n.last_twister_hit_id != p.twister_attack_id {
		if raylib.CheckCollisionRecs(get_twister_rect(p), get_nergal_hitbox(n)) {
			is_backstab := n.facing_left == (p.twister_pos.x > n.pos.x)
			dmg := compute_player_damage(p, TWISTER_DAMAGE)
			if is_backstab {
				dmg *= 1 + TWISTER_BACKSTAB_BONUS
			}
			n.hp -= dmg
			n.damage_flash_timer = DAMAGE_FLASH_DURATION
			n.last_twister_hit_id = p.twister_attack_id
			if n.hp <= 0 {
				nergal_enter_dying(n)
				return
			}
		}
	}

	if p.orb_state == .Flying && n.last_orb_hit_id != p.orb_attack_id {
		if raylib.CheckCollisionRecs(get_orb_rect(p), get_nergal_hitbox(n)) {
			n.hp -= compute_player_damage(p, WATERORB_DAMAGE)
			n.damage_flash_timer = DAMAGE_FLASH_DURATION
			n.last_orb_hit_id = p.orb_attack_id
			if rand.float32() < WATERORB_SLOW_CHANCE {
				n.slow_timer = SLUDGE_SLOW_DURATION
			}
			if n.hp <= 0 {
				nergal_enter_dying(n)
				return
			}
		}
	}
}

@(private = "file")
nergal_apply_gravity :: proc(n: ^Nergal, dt: f32) {
	n.vel.y += GRAVITY * dt
	if n.vel.y > MAX_FALL_SPEED {
		n.vel.y = MAX_FALL_SPEED
	}
}

@(private = "file")
nergal_move_and_collide :: proc(n: ^Nergal, map_data: ^dm.Dot_Map, dt: f32) {
	n.pos.x += n.vel.x * dt
	hb := get_nergal_hitbox(n)
	if check_rect_solid(map_data, hb) {
		if n.vel.x > 0 {
			tile_x := int(hb.x + hb.width) / TILE_SIZE
			n.pos.x = f32(tile_x * TILE_SIZE) - f32(NERGAL_HITBOX_W) / 2
		} else if n.vel.x < 0 {
			tile_x := int(hb.x) / TILE_SIZE
			n.pos.x = f32((tile_x + 1) * TILE_SIZE) + f32(NERGAL_HITBOX_W) / 2
		}
		n.vel.x = 0
	}

	n.pos.y += n.vel.y * dt
	hb = get_nergal_hitbox(n)
	n.on_ground = false
	if check_rect_solid(map_data, hb) {
		if n.vel.y > 0 {
			tile_y := int(hb.y + hb.height) / TILE_SIZE
			n.pos.y = f32(tile_y * TILE_SIZE)
			n.on_ground = true
		} else if n.vel.y < 0 {
			tile_y := int(hb.y) / TILE_SIZE
			n.pos.y = f32((tile_y + 1) * TILE_SIZE) + f32(NERGAL_HITBOX_H)
		}
		n.vel.y = 0
	}
}

@(private = "file")
nergal_animate_loop :: proc(n: ^Nergal, total_frames: int, dt: f32) {
	if total_frames <= 1 {
		return
	}
	frame_dur: f32 = 1.0 / NERGAL_ANIM_FPS
	n.anim_timer += dt
	if n.anim_timer >= frame_dur {
		n.anim_timer -= frame_dur
		n.current_frame += 1
		if int(n.current_frame) >= total_frames {
			n.current_frame = 0
		}
	}
}
