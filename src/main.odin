package game

import "vendor:raylib"
import dm "../dotmap"
import "core:fmt"
import "core:math/rand"
import "core:strings"

Game_State :: struct {
	map_data:      dm.Dot_Map,
	tile_textures: map[u8][dynamic]raylib.Texture2D,
	camera:        raylib.Camera2D,
	player:        Player,
	sludges:       Sludge_Pool,
	spawn_pos:     raylib.Vector2,
	render_target: raylib.RenderTexture2D,
	screen_scale:  f32,
	screen_offset: raylib.Vector2,
	window_w:      i32,
	window_h:      i32,
	should_quit:   bool,
	bg_color:      raylib.Color,
	screen_shake:  f32,
}

@(private = "file")
gs: Game_State

@(private = "file")
update_screen_scale :: proc() {
	win_w := gs.window_w
	win_h := gs.window_h
	if win_w <= 0 || win_h <= 0 {
		win_w = raylib.GetScreenWidth()
		win_h = raylib.GetScreenHeight()
	}
	scale_x := f32(win_w) / f32(SCREEN_WIDTH)
	scale_y := f32(win_h) / f32(SCREEN_HEIGHT)
	gs.screen_scale = min(scale_x, scale_y)
	gs.screen_offset = {
		(f32(win_w) - f32(SCREEN_WIDTH) * gs.screen_scale) / 2,
		(f32(win_h) - f32(SCREEN_HEIGHT) * gs.screen_scale) / 2,
	}
}

@(private = "file")
load_map_data :: proc(path: string) -> bool {
	map_bytes, map_ok := read_entire_file(path)
	if !map_ok {
		fmt.eprintln("Failed to load map file:", path)
		return false
	}
	map_data, parse_ok := dm.parse_map(string(map_bytes))
	delete(map_bytes)
	if !parse_ok {
		fmt.eprintln("Failed to parse map:", path)
		return false
	}
	gs.map_data = map_data

	gs.tile_textures = make(map[u8][dynamic]raylib.Texture2D)
	for sym, td in gs.map_data.metadata {
		textures: [dynamic]raylib.Texture2D
		for tile_path in td.tiles {
			cpath := strings.clone_to_cstring(tile_path)
			defer delete(cpath)
			tex := raylib.LoadTexture(cpath)
			if tex.id > 0 {
				append(&textures, tex)
			} else {
				fmt.eprintln("Failed to load texture:", tile_path)
			}
		}
		gs.tile_textures[sym] = textures
	}

	for sym, texs in gs.tile_textures {
		num_variants := len(texs)
		if num_variants > 1 {
			for &row in gs.map_data.grid {
				for &cell in row {
					if cell.symbol == sym {
						cell.tile_index = rand.int_max(num_variants)
					}
				}
			}
		}
	}

	return true
}

@(private = "file")
unload_map_data :: proc() {
	for _, &textures in gs.tile_textures {
		for &tex in textures {
			raylib.UnloadTexture(tex)
		}
		delete(textures)
	}
	delete(gs.tile_textures)
	dm.destroy_map(&gs.map_data)
}

@(private = "file")
find_spawn :: proc() -> raylib.Vector2 {
	for row, ry in gs.map_data.grid {
		for cell, cx in row {
			if cell.symbol == 's' {
				td, has_meta := gs.map_data.metadata['s']
				if !has_meta {
					continue
				}
				spawn_key := dm.extract_kv(td.other, "spawn_point")
				defer delete(spawn_key)
				if spawn_key == "player" {
					return {f32(cx) * TILE_SIZE + TILE_SIZE / 2, f32(ry) * TILE_SIZE + TILE_SIZE}
				}
			}
		}
	}
	return {100, 100}
}

@(private = "file")
collect_enemy_spawns :: proc(max_count: int) -> [dynamic]raylib.Vector2 {
	positions := make([dynamic]raylib.Vector2, context.temp_allocator)
	for row, ry in gs.map_data.grid {
		for cell, cx in row {
			if cell.symbol == 'e' {
				append(&positions, raylib.Vector2{
					f32(cx) * TILE_SIZE + TILE_SIZE / 2,
					f32(ry) * TILE_SIZE + TILE_SIZE,
				})
			}
		}
	}
	// Fisher-Yates shuffle
	for i := len(positions) - 1; i > 0; i -= 1 {
		j := int(rand.int31_max(i32(i + 1)))
		positions[i], positions[j] = positions[j], positions[i]
	}
	if len(positions) > max_count {
		resize(&positions, max_count)
	}
	return positions
}

init :: proc() {
	raylib.SetConfigFlags({.WINDOW_RESIZABLE})
	raylib.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Sandcastle")
	raylib.SetRandomSeed(u32(raylib.GetTime() * 1000000) + 1)

	when ODIN_ARCH != .wasm32 && ODIN_ARCH != .wasm64p32 {
		monitor := raylib.GetCurrentMonitor()
		screen_w := raylib.GetMonitorWidth(monitor)
		screen_h := raylib.GetMonitorHeight(monitor)
		raylib.SetWindowSize(screen_w, screen_h)
		raylib.ToggleFullscreen()
		raylib.SetTargetFPS(TARGET_FPS)
	}

	gs.render_target = raylib.LoadRenderTexture(SCREEN_WIDTH, SCREEN_HEIGHT)
	raylib.SetTextureFilter(gs.render_target.texture, .POINT)
	update_screen_scale()

	gs.bg_color = {0x3d, 0x1f, 0x4c, 0xff}

	if !load_map_data(LEVEL_MAP_PATH) {
		gs.should_quit = true
		return
	}

	gs.spawn_pos = find_spawn()
	init_player(&gs.player, gs.spawn_pos)

	init_sludges(&gs.sludges)
	enemy_positions := collect_enemy_spawns(MAX_SLUDGE_SLOTS)
	for pos in enemy_positions {
		register_sludge_slot(&gs.sludges, pos)
	}

	gs.camera = raylib.Camera2D{
		zoom   = 2,
		offset = {SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2},
		target = gs.player.pos,
	}
}

update :: proc() {
	free_all(context.temp_allocator)

	dt := raylib.GetFrameTime()
	if dt > 0.05 {
		dt = 0.05
	}

	if input_pause() {
		gs.should_quit = true
	}

	prev_dash_impact := gs.player.dash_impact_active
	update_player(&gs.player, &gs.map_data, dt)
	if !prev_dash_impact && gs.player.dash_impact_active {
		gs.screen_shake = SCREENSHAKE_DURATION
	}

	update_sludges(&gs.sludges, &gs.player, &gs.camera, &gs.map_data, dt)

	if gs.player.dash_impact_active && !gs.player.dash_impact_damage_dealt {
		gs.player.dash_impact_damage_dealt = true
	}

	if gs.player.hp <= 0 {
		respawn_player()
	}

	update_camera(dt)

	raylib.BeginTextureMode(gs.render_target)
	raylib.ClearBackground(gs.bg_color)

	raylib.BeginMode2D(gs.camera)
	draw_map()
	draw_sludges(&gs.sludges)
	draw_player(&gs.player)
	draw_dash_impact(&gs.player)
	draw_projectile(&gs.player)
	raylib.EndMode2D()

	draw_hud()

	raylib.EndTextureMode()

	update_screen_scale()

	raylib.BeginDrawing()
	raylib.ClearBackground(raylib.BLACK)
	src := raylib.Rectangle{0, 0, f32(SCREEN_WIDTH), -f32(SCREEN_HEIGHT)}
	dst := raylib.Rectangle{
		gs.screen_offset.x,
		gs.screen_offset.y,
		f32(SCREEN_WIDTH) * gs.screen_scale,
		f32(SCREEN_HEIGHT) * gs.screen_scale,
	}
	raylib.DrawTexturePro(gs.render_target.texture, src, dst, {0, 0}, 0, raylib.WHITE)
	raylib.EndDrawing()
}

should_run :: proc() -> bool {
	return !raylib.WindowShouldClose() && !gs.should_quit
}

shutdown :: proc() {
	unload_player(&gs.player)
	unload_sludges(&gs.sludges)
	unload_map_data()
	raylib.UnloadRenderTexture(gs.render_target)
	raylib.CloseWindow()
}

@(private = "file")
respawn_player :: proc() {
	gs.player.pos = gs.spawn_pos
	gs.player.vel = {}
	gs.player.hp = PLAYER_MAX_HP
	gs.player.damage_flash_timer = 0
	gs.player.invuln_timer = PLAYER_INVULN_DURATION
	gs.player.dashing = false
	gs.player.down_dashing = false
	gs.player.dash_timer = 0
	gs.player.dash_cooldown = 0
	gs.player.dash_impact_active = false
	gs.player.projectile.state = .Inactive
}

@(private = "file")
draw_hud :: proc() {
	BAR_X :: i32(8)
	BAR_Y :: i32(8)
	BAR_W :: i32(80)
	BAR_H :: i32(6)

	raylib.DrawRectangle(BAR_X - 1, BAR_Y - 1, BAR_W + 2, BAR_H + 2, raylib.Color{0, 0, 0, 220})
	fill_w := i32(f32(BAR_W) * (gs.player.hp / PLAYER_MAX_HP))
	if fill_w < 0 {
		fill_w = 0
	}
	raylib.DrawRectangle(BAR_X, BAR_Y, fill_w, BAR_H, raylib.Color{0x33, 0xCC, 0xFF, 0xFF})

	hp_text := fmt.ctprintf("%d/%d", i32(gs.player.hp), i32(PLAYER_MAX_HP))
	raylib.DrawText(hp_text, BAR_X + BAR_W + 4, BAR_Y - 1, 8, raylib.WHITE)
}

parent_window_size_changed :: proc(w, h: int) {
	gs.window_w = i32(w)
	gs.window_h = i32(h)
	raylib.SetWindowSize(gs.window_w, gs.window_h)
	update_screen_scale()
}

set_web_mouse_pos :: proc(x, y: int) {
	// placeholder for future mouse support
}

set_web_mouse_down :: proc(down: bool) {
	// placeholder for future mouse support
}

@(private = "file")
update_camera :: proc(dt: f32) {
	gs.camera.target = gs.player.pos

	map_w := f32(gs.map_data.width) * TILE_SIZE
	map_h := f32(gs.map_data.height) * TILE_SIZE
	half_w := f32(SCREEN_WIDTH) / (2 * gs.camera.zoom)
	half_h := f32(SCREEN_HEIGHT) / (2 * gs.camera.zoom)

	if gs.camera.target.x < half_w {
		gs.camera.target.x = half_w
	}
	if gs.camera.target.x > map_w - half_w {
		gs.camera.target.x = map_w - half_w
	}
	if gs.camera.target.y < half_h {
		gs.camera.target.y = half_h
	}
	if gs.camera.target.y > map_h - half_h {
		gs.camera.target.y = map_h - half_h
	}

	if gs.screen_shake > 0 {
		gs.screen_shake -= dt
		if gs.screen_shake > 0 {
			intensity := gs.screen_shake / SCREENSHAKE_DURATION
			mag := SCREENSHAKE_MAGNITUDE * intensity
			gs.camera.target.x += rand.float32_range(-mag, mag)
			gs.camera.target.y += rand.float32_range(-mag, mag)
		}
	}
}

@(private = "file")
draw_map :: proc() {
	cam := gs.camera
	half_w := f32(SCREEN_WIDTH) / (2 * cam.zoom)
	half_h := f32(SCREEN_HEIGHT) / (2 * cam.zoom)
	min_x := int((cam.target.x - half_w) / TILE_SIZE) - 1
	max_x := int((cam.target.x + half_w) / TILE_SIZE) + 1
	min_y := int((cam.target.y - half_h) / TILE_SIZE) - 1
	max_y := int((cam.target.y + half_h) / TILE_SIZE) + 1

	if min_x < 0 {
		min_x = 0
	}
	if min_y < 0 {
		min_y = 0
	}
	if max_x >= gs.map_data.width {
		max_x = gs.map_data.width - 1
	}
	if max_y >= gs.map_data.height {
		max_y = gs.map_data.height - 1
	}

	for ry in min_y ..= max_y {
		if ry >= len(gs.map_data.grid) {
			break
		}
		row := gs.map_data.grid[ry]
		for cx in min_x ..= max_x {
			if cx >= len(row) {
				break
			}
			cell := row[cx]
			draw_x := f32(cx) * TILE_SIZE
			draw_y := f32(ry) * TILE_SIZE

			if cell.symbol == '.' || cell.symbol == 's' {
				continue
			}

			textures, has_tex := gs.tile_textures[cell.symbol]
			if !has_tex || len(textures) == 0 {
				continue
			}

			idx := cell.tile_index
			if idx >= len(textures) {
				idx = 0
			}
			tex := textures[idx]
			raylib.DrawTexture(tex, i32(draw_x), i32(draw_y), raylib.WHITE)
		}
	}
}
