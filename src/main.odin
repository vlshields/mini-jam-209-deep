package game

import "vendor:raylib"
import dm "../dotmap"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:strings"

Menu_State :: enum {
	Main_Menu,
	Playing,
	Choosing_Stats,
	Choosing_Weapon,
	Paused,
	Game_Over,
}

GAME_OVER_FADE_DURATION :: f32(2.0)
GAME_OVER_MENU_DELAY    :: f32(1.2)

Pause_Screen :: enum {
	Main,
	Controls,
	Options,
	Hints,
}

PAUSE_MAIN_ITEM_COUNT :: 5

Main_Menu_Screen :: enum {
	Main,
	Options,
	Controls,
	Audio,
	Hints,
}

Game_State :: struct {
	map_data:           dm.Dot_Map,
	tile_textures:      map[u8][dynamic]raylib.Texture2D,
	camera:             raylib.Camera2D,
	player:             Player,
	sludges:            Sludge_Pool,
	soldiers:           Soldier_Pool,
	wave:               int,
	spawn_pos:          raylib.Vector2,
	render_target:      raylib.RenderTexture2D,
	screen_scale:       f32,
	screen_offset:      raylib.Vector2,
	window_w:           i32,
	window_h:           i32,
	should_quit:        bool,
	bg_color:           raylib.Color,
	bg_textures:        [PARALLAX_LAYER_COUNT]raylib.Texture2D,
	combat_music:       raylib.Music,
	combat_music_loaded: bool,
	screen_shake:       f32,
	menu:               Menu_State,
	menu_selected:      int,
	stat_choices:       [3]Stat_Upgrade,
	weapon_choices:     [3]Weapon_Kind,
	weapon_count:       int,
	weapons_available:  [Weapon_Kind]bool,
	pause_screen:       Pause_Screen,
	music_volume:       f32,
	sfx_volume:         f32,
	game_over_timer:    f32,
	main_menu_screen:   Main_Menu_Screen,
	main_menu_timer:    f32,
	main_menu_title_y:  f32,
	main_menu_items_x:  f32,
	main_menu_idle_frame: int,
	main_menu_idle_timer: f32,
	hint_active:        bool,
	hint_current:       Hint_Kind,
	hint_display_timer: f32,
	hint_play_time:     f32,
	hint_auto_shown:    [Hint_Kind]bool,
	hint_view_idx:      int,
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

@(private = "file")
collect_bottom_platform_spawns :: proc(max_count: int) -> [dynamic]raylib.Vector2 {
	max_row := -1
	for row, ry in gs.map_data.grid {
		for cell in row {
			if cell.symbol == 'e' && ry > max_row {
				max_row = ry
			}
		}
	}
	positions := make([dynamic]raylib.Vector2, context.temp_allocator)
	if max_row < 0 {
		return positions
	}
	row := gs.map_data.grid[max_row]
	for cell, cx in row {
		if cell.symbol == 'e' {
			append(&positions, raylib.Vector2{
				f32(cx) * TILE_SIZE + TILE_SIZE / 2,
				f32(max_row) * TILE_SIZE + TILE_SIZE,
			})
		}
	}
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
	init_hitflash_shader()
	update_screen_scale()

	gs.bg_color = {0x3d, 0x1f, 0x4c, 0xff}
	gs.bg_textures[0] = raylib.LoadTexture("assets/tiles/Background.png")
	gs.bg_textures[1] = raylib.LoadTexture("assets/tiles/Background1.png")
	gs.bg_textures[2] = raylib.LoadTexture("assets/tiles/Background2.png")

	gs.music_volume = 1.0
	gs.sfx_volume = 1.0

	raylib.InitAudioDevice()
	if raylib.IsAudioDeviceReady() {
		gs.combat_music = raylib.LoadMusicStream("assets/audio/soundtrack/waves.ogg")
		gs.combat_music.looping = true
		raylib.SetMusicVolume(gs.combat_music, MUSIC_BASE_VOLUME * gs.music_volume)
		raylib.PlayMusicStream(gs.combat_music)
		gs.combat_music_loaded = true
		init_audio()
		set_master_sfx_volume(gs.sfx_volume)
	}

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

	init_soldiers(&gs.soldiers)
	soldier_positions := collect_bottom_platform_spawns(MAX_SOLDIER_SLOTS)
	for pos in soldier_positions {
		register_soldier_slot(&gs.soldiers, pos)
	}

	gs.wave = 1
	reset_sludges(&gs.sludges, compute_wave_sludge_target(gs.wave))
	reset_soldiers(&gs.soldiers)

	gs.camera = raylib.Camera2D{
		zoom   = 2,
		offset = {SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2},
		target = gs.player.pos,
	}

	gs.menu = .Main_Menu
	gs.main_menu_screen = .Main
	gs.menu_selected = 0
	gs.main_menu_timer = 0
	gs.weapons_available[.Double_Strike] = true
	gs.weapons_available[.Waveblade] = true
	gs.weapons_available[.Orb] = true
	gs.weapons_available[.Giant_Whale] = true
}

compute_wave_sludge_target :: proc(wave: int) -> int {
	if wave <= 2 {
		return WAVE_BASE_SLUDGES
	}
	capped := min(wave, WAVE_LAST_INCREMENT)
	return WAVE_BASE_SLUDGES + (capped - 2) * WAVE_SLUDGE_INCREMENT
}

@(private = "file")
count_remaining_enemies :: proc() -> int {
	n := 0
	for i := 0; i < gs.sludges.count; i += 1 {
		if gs.sludges.slots[i].state != .Dead {
			n += 1
		}
	}
	if gs.wave >= SOLDIER_WAVE_THRESHOLD {
		for i := 0; i < gs.soldiers.count; i += 1 {
			if gs.soldiers.slots[i].state != .Dead {
				n += 1
			}
		}
	}
	return n
}

update :: proc() {
	free_all(context.temp_allocator)

	dt := raylib.GetFrameTime()
	if dt > 0.05 {
		dt = 0.05
	}

	if gs.menu == .Playing && input_pause() {
		gs.menu = .Paused
		gs.pause_screen = .Main
		gs.menu_selected = 0
		gs.hint_active = false
		play_sound(.UI_Confirm)
	} else if gs.menu == .Paused && input_menu_back() {
		handle_pause_back()
	} else if gs.menu == .Main_Menu && input_menu_back() {
		handle_main_menu_back()
	}

	if gs.combat_music_loaded {
		if gs.menu == .Playing || gs.menu == .Main_Menu {
			raylib.ResumeMusicStream(gs.combat_music)
		} else {
			raylib.PauseMusicStream(gs.combat_music)
		}
		raylib.UpdateMusicStream(gs.combat_music)
	}

	switch gs.menu {
	case .Main_Menu:
		update_main_menu(dt)

	case .Playing:
		update_hints(dt)
		prev_dash_impact := gs.player.dash_impact_active
		prev_hp := gs.player.hp
		update_player(&gs.player, &gs.map_data, dt)
		if !prev_dash_impact && gs.player.dash_impact_active {
			gs.screen_shake = SCREENSHAKE_DURATION
			play_sound(.Player_Dash_Ground_Impact)
		}
		if gs.player.hp < prev_hp {
			play_sound(.Hit)
		}

		update_sludges(&gs.sludges, &gs.player, &gs.camera, &gs.map_data, dt)
		update_soldiers(&gs.soldiers, &gs.player, &gs.camera, &gs.map_data, dt,
			gs.wave >= SOLDIER_WAVE_THRESHOLD)

		if gs.player.dash_impact_active && !gs.player.dash_impact_damage_dealt {
			gs.player.dash_impact_damage_dealt = true
		}

		if gs.player.hp <= 0 {
			enter_game_over()
		} else {
			check_door_entry()
		}

	case .Choosing_Stats:
		handle_menu_input(3, proc(idx: int) {
			apply_stat_upgrade(&gs.player, gs.stat_choices[idx])
			close_menu_and_loop()
		})

	case .Choosing_Weapon:
		handle_menu_input(gs.weapon_count, proc(idx: int) {
			chosen := gs.weapon_choices[idx]
			apply_weapon_upgrade(&gs.player, chosen)
			gs.weapons_available[chosen] = false
			close_menu_and_loop()
		})

	case .Paused:
		update_pause_menu()

	case .Game_Over:
		update_game_over(dt)
	}

	if gs.menu != .Main_Menu {
		update_camera(dt)
	}

	raylib.BeginTextureMode(gs.render_target)
	raylib.ClearBackground(gs.bg_color)

	if gs.menu == .Main_Menu {
		draw_main_menu()
	} else {
		draw_parallax_bg()

		raylib.BeginMode2D(gs.camera)
		draw_map()
		draw_doors()
		draw_sludges(&gs.sludges)
		draw_soldiers(&gs.soldiers)
		draw_player(&gs.player)
		draw_waveblade(&gs.player)
		draw_dash_impact(&gs.player)
		draw_projectile(&gs.player)
		draw_orb(&gs.player)
		draw_whale(&gs.player)
		raylib.EndMode2D()

		draw_hud()
		draw_hint_popup()
		draw_choose_prompt()
		draw_menu_overlay()
	}

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
	unload_soldiers(&gs.soldiers)
	unload_map_data()
	for tex in gs.bg_textures {
		raylib.UnloadTexture(tex)
	}
	raylib.UnloadRenderTexture(gs.render_target)
	unload_hitflash_shader()
	if gs.combat_music_loaded {
		raylib.UnloadMusicStream(gs.combat_music)
	}
	unload_audio()
	raylib.CloseAudioDevice()
	raylib.CloseWindow()
}

@(private = "file")
enter_game_over :: proc() {
	gs.menu = .Game_Over
	gs.game_over_timer = 0
	gs.hint_active = false
	play_sound(.You_Died)
	if gs.combat_music_loaded {
		raylib.StopMusicStream(gs.combat_music)
	}
}

@(private = "file")
update_game_over :: proc(dt: f32) {
	gs.game_over_timer += dt
	if gs.game_over_timer >= GAME_OVER_FADE_DURATION && input_menu_confirm() {
		restart_run()
	}
}

@(private = "file")
draw_game_over :: proc() {
	fade_t := clamp(gs.game_over_timer / GAME_OVER_FADE_DURATION, 0, 1)
	eased := 1 - (1 - fade_t) * (1 - fade_t)
	overlay_alpha := u8(eased * 255)
	raylib.DrawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, raylib.Color{0, 0, 0, overlay_alpha})

	menu_t := clamp(
		(gs.game_over_timer - GAME_OVER_MENU_DELAY) / (GAME_OVER_FADE_DURATION - GAME_OVER_MENU_DELAY),
		0, 1,
	)
	if menu_t <= 0 {
		return
	}
	menu_alpha := u8(menu_t * 255)

	title: cstring = "YOU DIED"
	title_w := raylib.MeasureText(title, 20)
	raylib.DrawText(
		title, (SCREEN_WIDTH - title_w) / 2, SCREEN_HEIGHT / 2 - 20, 20,
		raylib.Color{0xFF, 0x33, 0x33, menu_alpha},
	)

	sub: cstring = gamepad_active() ? "Press A to play again" : "Press ENTER to play again"
	sub_w := raylib.MeasureText(sub, 10)
	raylib.DrawText(
		sub, (SCREEN_WIDTH - sub_w) / 2, SCREEN_HEIGHT / 2 + 10, 10,
		raylib.Color{255, 255, 255, menu_alpha},
	)
}

@(private = "file")
restart_run :: proc() {
	reset_player_run_state(&gs.player, gs.spawn_pos)
	gs.wave = 1
	reset_sludges(&gs.sludges, compute_wave_sludge_target(gs.wave))
	reset_soldiers(&gs.soldiers)
	gs.weapons_available = {}
	gs.weapons_available[.Double_Strike] = true
	gs.weapons_available[.Waveblade] = true
	gs.weapons_available[.Orb] = true
	gs.weapons_available[.Giant_Whale] = true
	gs.menu = .Playing
	gs.game_over_timer = 0
	gs.hint_active = false
	gs.hint_play_time = 0
	gs.hint_auto_shown = {}
	if gs.combat_music_loaded {
		raylib.PlayMusicStream(gs.combat_music)
	}
}

@(private = "file")
draw_hud :: proc() {
	BAR_X    :: i32(8)
	BAR_Y    :: i32(8)
	BAR_W    :: i32(80)
	BAR_H    :: i32(6)
	STAM_Y   :: BAR_Y + BAR_H + 3
	STAM_H   :: i32(4)

	raylib.DrawRectangle(BAR_X - 1, BAR_Y - 1, BAR_W + 2, BAR_H + 2, raylib.Color{0, 0, 0, 220})
	fill_w := i32(f32(BAR_W) * (gs.player.hp / gs.player.max_hp))
	if fill_w < 0 {
		fill_w = 0
	}
	raylib.DrawRectangle(BAR_X, BAR_Y, fill_w, BAR_H, raylib.Color{0x33, 0xCC, 0xFF, 0xFF})

	hp_text := fmt.ctprintf("%d/%d", i32(gs.player.hp), i32(gs.player.max_hp))
	raylib.DrawText(hp_text, BAR_X + BAR_W + 4, BAR_Y - 1, 8, raylib.WHITE)

	raylib.DrawRectangle(BAR_X - 1, STAM_Y - 1, BAR_W + 2, STAM_H + 2, raylib.Color{0, 0, 0, 220})
	stam_w := i32(f32(BAR_W) * (gs.player.stamina / gs.player.max_stamina))
	if stam_w < 0 {
		stam_w = 0
	}
	raylib.DrawRectangle(BAR_X, STAM_Y, stam_w, STAM_H, raylib.Color{0xCC, 0xCC, 0x33, 0xFF})

	stam_text := fmt.ctprintf("%d/%d", i32(gs.player.stamina), i32(gs.player.max_stamina))
	raylib.DrawText(stam_text, BAR_X + BAR_W + 4, STAM_Y - 2, 8, raylib.Color{0xCC, 0xCC, 0x33, 0xFF})

	remaining := count_remaining_enemies()
	if remaining > 0 {
		label: cstring = remaining == 1 ? "1 enemy remaining" : fmt.ctprintf("%d enemies remaining", remaining)
		tw := raylib.MeasureText(label, 8)
		raylib.DrawText(label, SCREEN_WIDTH - tw - 8, BAR_Y, 8, raylib.WHITE)
	}
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
all_enemies_cleared :: proc() -> bool {
	for i := 0; i < gs.sludges.count; i += 1 {
		if gs.sludges.slots[i].state != .Dead {
			return false
		}
	}
	if gs.wave >= SOLDIER_WAVE_THRESHOLD {
		if !soldiers_all_dead(&gs.soldiers, false) {
			return false
		}
	}
	return gs.sludges.count > 0 ||
		(gs.wave >= SOLDIER_WAVE_THRESHOLD && gs.soldiers.count > 0)
}

@(private = "file")
find_overlapping_door :: proc() -> u8 {
	hb := get_player_hitbox(&gs.player)
	x0 := int(hb.x) / TILE_SIZE
	y0 := int(hb.y) / TILE_SIZE
	x1 := int(hb.x + hb.width - 0.01) / TILE_SIZE
	y1 := int(hb.y + hb.height - 0.01) / TILE_SIZE
	for ty in y0 ..= y1 {
		if ty < 0 || ty >= len(gs.map_data.grid) {
			continue
		}
		row := gs.map_data.grid[ty]
		for tx in x0 ..= x1 {
			if tx < 0 || tx >= len(row) {
				continue
			}
			sym := row[tx].symbol
			if sym == 'd' || sym == 'D' {
				return sym
			}
		}
	}
	return 0
}

@(private = "file")
check_door_entry :: proc() {
	if !all_enemies_cleared() {
		return
	}
	sym := find_overlapping_door()
	switch sym {
	case 'd':
		gs.stat_choices = sample_stat_choices()
		gs.menu_selected = 0
		gs.menu = .Choosing_Stats
	case 'D':
		choices, count := sample_weapon_choices(gs.weapons_available)
		if count == 0 {
			return
		}
		gs.weapon_choices = choices
		gs.weapon_count = count
		gs.menu_selected = 0
		gs.menu = .Choosing_Weapon
	}
}

@(private = "file")
handle_menu_input :: proc(count: int, on_confirm: proc(int)) {
	if count <= 0 {
		return
	}
	if c := input_choice_pressed(); c >= 1 && c <= count {
		play_sound(.UI_Confirm)
		on_confirm(c - 1)
		return
	}
	if input_menu_left() {
		gs.menu_selected -= 1
		if gs.menu_selected < 0 {
			gs.menu_selected = count - 1
		}
	}
	if input_menu_right() {
		gs.menu_selected += 1
		if gs.menu_selected >= count {
			gs.menu_selected = 0
		}
	}
	if gs.menu_selected >= count {
		gs.menu_selected = count - 1
	}
	if input_menu_confirm() {
		play_sound(.UI_Confirm)
		on_confirm(gs.menu_selected)
	}
}

@(private = "file")
close_menu_and_loop :: proc() {
	gs.menu = .Playing
	gs.wave += 1
	reset_sludges(&gs.sludges, compute_wave_sludge_target(gs.wave))
	reset_soldiers(&gs.soldiers)
}

@(private = "file")
draw_choose_prompt :: proc() {
	if gs.menu != .Playing {
		return
	}
	if !all_enemies_cleared() {
		return
	}

	msg: cstring = "Choose an upgrade!"
	tw := raylib.MeasureText(msg, CHOOSE_PROMPT_TEXT_SIZE)
	tx := SCREEN_WIDTH/2 - tw/2
	ty := CHOOSE_PROMPT_TEXT_Y

	pulse := math.sin(f32(raylib.GetTime()) * CHOOSE_PROMPT_PULSE_HZ) * 0.5 + 0.5
	bg_alpha := u8(140 + pulse * 80)
	raylib.DrawRectangle(tx - 10, ty - 5, tw + 20, CHOOSE_PROMPT_TEXT_SIZE + 10, raylib.Color{0, 0, 0, bg_alpha})
	raylib.DrawRectangleLines(tx - 10, ty - 5, tw + 20, CHOOSE_PROMPT_TEXT_SIZE + 10, raylib.Color{0xFF, 0xE5, 0x99, 255})
	raylib.DrawText(msg, tx + 1, ty + 1, CHOOSE_PROMPT_TEXT_SIZE, raylib.Color{0, 0, 0, 200})
	raylib.DrawText(msg, tx, ty, CHOOSE_PROMPT_TEXT_SIZE, raylib.Color{0xFF, 0xE5, 0x99, 255})

	bob := math.sin(f32(raylib.GetTime()) * CHOOSE_ARROW_BOB_HZ) * CHOOSE_ARROW_BOB_AMP

	for ry in 0 ..< len(gs.map_data.grid) {
		row := gs.map_data.grid[ry]
		for cx in 0 ..< len(row) {
			sym := row[cx].symbol
			if sym != 'd' && sym != 'D' {
				continue
			}
			world_x := f32(cx * TILE_SIZE) + TILE_SIZE / 2
			world_y := f32(ry * TILE_SIZE)
			screen_pos := raylib.GetWorldToScreen2D({world_x, world_y}, gs.camera)

			if screen_pos.x < -20 || screen_pos.x > SCREEN_WIDTH + 20 {
				continue
			}
			if screen_pos.y < -20 || screen_pos.y > SCREEN_HEIGHT + 20 {
				continue
			}

			ax := screen_pos.x
			ay := screen_pos.y - 14 + bob

			color: raylib.Color
			if sym == 'd' {
				color = raylib.Color{0x55, 0xFF, 0x55, 255}
			} else {
				color = raylib.Color{0xFF, 0x88, 0xFF, 255}
			}

			top_left  := raylib.Vector2{ax - 7, ay - 7}
			top_right := raylib.Vector2{ax + 7, ay - 7}
			bottom    := raylib.Vector2{ax,     ay + 5}

			raylib.DrawTriangle(top_left, bottom, top_right, color)
			raylib.DrawLineEx(top_left,  bottom,    1, raylib.WHITE)
			raylib.DrawLineEx(bottom,    top_right, 1, raylib.WHITE)
			raylib.DrawLineEx(top_right, top_left,  1, raylib.WHITE)
		}
	}
}

@(private = "file")
draw_doors :: proc() {
	if !all_enemies_cleared() {
		return
	}
	for ry in 0 ..< len(gs.map_data.grid) {
		row := gs.map_data.grid[ry]
		for cx in 0 ..< len(row) {
			sym := row[cx].symbol
			if sym != 'd' && sym != 'D' {
				continue
			}
			cxp := i32(cx * TILE_SIZE + TILE_SIZE / 2)
			cyp := i32(ry * TILE_SIZE + TILE_SIZE / 2)
			inner, outer: raylib.Color
			if sym == 'd' {
				inner = raylib.Color{0xC0, 0xFF, 0x80, 0xFF}
				outer = raylib.Color{0x20, 0x70, 0x20, 0x00}
			} else {
				inner = raylib.Color{0xE0, 0xF8, 0xFF, 0xFF}
				outer = raylib.Color{0x10, 0x40, 0x90, 0x00}
			}
			raylib.DrawCircleGradient(cxp, cyp, 14, inner, outer)
		}
	}
}

@(private = "file")
draw_menu_overlay :: proc() {
	switch gs.menu {
	case .Main_Menu, .Playing:
		return
	case .Choosing_Stats:
		titles := make([]string, 3, context.temp_allocator)
		descs  := make([]string, 3, context.temp_allocator)
		for i in 0 ..< 3 {
			titles[i] = gs.stat_choices[i].title
			descs[i]  = gs.stat_choices[i].desc
		}
		draw_choice_menu("Choose a Stat Upgrade", titles, descs, 3, gs.menu_selected)
	case .Choosing_Weapon:
		titles := make([]string, gs.weapon_count, context.temp_allocator)
		descs  := make([]string, gs.weapon_count, context.temp_allocator)
		for i in 0 ..< gs.weapon_count {
			titles[i] = weapon_title(gs.weapon_choices[i])
			descs[i]  = weapon_desc(gs.weapon_choices[i])
		}
		draw_choice_menu("Choose a Weapon", titles, descs, gs.weapon_count, gs.menu_selected)
	case .Paused:
		draw_pause_overlay()
	case .Game_Over:
		draw_game_over()
	}
}

@(private = "file")
handle_pause_back :: proc() {
	switch gs.pause_screen {
	case .Main:
		gs.menu = .Playing
		play_sound(.UI_Negative_Back)
	case .Controls, .Options, .Hints:
		gs.pause_screen = .Main
		gs.menu_selected = 0
		play_sound(.UI_Negative_Back)
	}
}

@(private = "file")
update_pause_menu :: proc() {
	switch gs.pause_screen {
	case .Main:
		update_pause_main()
	case .Controls:
		// no-op, only ESC/Start to back out
	case .Options:
		update_pause_options()
	case .Hints:
		update_hints_menu()
	}
}

@(private = "file")
update_pause_main :: proc() {
	if input_menu_up() {
		gs.menu_selected -= 1
		if gs.menu_selected < 0 {
			gs.menu_selected = PAUSE_MAIN_ITEM_COUNT - 1
		}
	}
	if input_menu_down() {
		gs.menu_selected += 1
		if gs.menu_selected >= PAUSE_MAIN_ITEM_COUNT {
			gs.menu_selected = 0
		}
	}
	if !input_menu_confirm() {
		return
	}
	switch gs.menu_selected {
	case 0:
		gs.menu = .Playing
		play_sound(.UI_Negative_Back)
	case 1:
		gs.pause_screen = .Controls
		play_sound(.UI_Confirm)
	case 2:
		gs.pause_screen = .Options
		gs.menu_selected = 0
		play_sound(.UI_Confirm)
	case 3:
		gs.pause_screen = .Hints
		gs.hint_view_idx = 0
		play_sound(.UI_Confirm)
	case 4:
		when ODIN_ARCH != .wasm32 && ODIN_ARCH != .wasm64p32 {
			gs.should_quit = true
			play_sound(.UI_Negative_Back)
		}
	}
}

@(private = "file")
update_pause_options :: proc() {
	if input_menu_up() {
		gs.menu_selected = (gs.menu_selected + 1) % 2
	}
	if input_menu_down() {
		gs.menu_selected = (gs.menu_selected + 1) % 2
	}
	delta: f32 = 0
	if input_menu_left() {
		delta = -VOLUME_STEP
	}
	if input_menu_right() {
		delta = VOLUME_STEP
	}
	if delta == 0 {
		return
	}
	if gs.menu_selected == 0 {
		gs.music_volume = clamp(gs.music_volume + delta, 0, 1)
		if gs.combat_music_loaded {
			raylib.SetMusicVolume(gs.combat_music, MUSIC_BASE_VOLUME * gs.music_volume)
		}
	} else {
		gs.sfx_volume = clamp(gs.sfx_volume + delta, 0, 1)
		set_master_sfx_volume(gs.sfx_volume)
	}
	play_sound(.UI_Confirm)
}

@(private = "file")
draw_pause_overlay :: proc() {
	raylib.DrawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, raylib.Color{0, 0, 0, 200})

	switch gs.pause_screen {
	case .Main:
		draw_pause_main()
	case .Controls:
		draw_pause_controls()
	case .Options:
		draw_pause_options()
	case .Hints:
		draw_hints_panel()
	}

	if gs.pause_screen != .Hints {
		draw_player_stats_panel()
	}
}

@(private = "file")
draw_pause_main :: proc() {
	title: cstring = "PAUSED"
	tw := raylib.MeasureText(title, 20)
	raylib.DrawText(title, SCREEN_WIDTH/2 - tw/2, 18, 20, raylib.WHITE)

	items := [PAUSE_MAIN_ITEM_COUNT]cstring{"Resume", "Controls", "Options", "Hints", "Quit"}
	for i in 0 ..< PAUSE_MAIN_ITEM_COUNT {
		item := items[i]
		color := raylib.WHITE
		if i == gs.menu_selected {
			color = raylib.YELLOW
		}
		when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
			if i == 4 {
				dimmed := color
				dimmed.r /= 2
				dimmed.g /= 2
				dimmed.b /= 2
				color = dimmed
			}
		}
		iw := raylib.MeasureText(item, 14)
		y := i32(60 + i * 22)
		raylib.DrawText(item, SCREEN_WIDTH/2 - iw/2, y, 14, color)
		if i == gs.menu_selected {
			raylib.DrawText(">", SCREEN_WIDTH/2 - iw/2 - 12, y, 14, raylib.YELLOW)
		}
	}

	hint: cstring = "Up/Down + Confirm   |   Esc/B to resume"
	hw := raylib.MeasureText(hint, 8)
	raylib.DrawText(hint, SCREEN_WIDTH/2 - hw/2, 180, 8, raylib.LIGHTGRAY)
}

@(private = "file")
draw_pause_controls :: proc() {
	title: cstring = "CONTROLS"
	tw := raylib.MeasureText(title, 20)
	raylib.DrawText(title, SCREEN_WIDTH/2 - tw/2, 18, 20, raylib.WHITE)

	gp := gamepad_active()
	mode_label: cstring = gp ? "Gamepad" : "Keyboard / Mouse"
	mw := raylib.MeasureText(mode_label, 10)
	raylib.DrawText(mode_label, SCREEN_WIDTH/2 - mw/2, 44, 10, raylib.LIGHTGRAY)

	rows := [?][2]cstring{
		{"Move",    gp ? "Left Stick"     : "A / D / Left / Right"},
		{"Down",    gp ? "Left Stick Down": "S / Down"},
		{"Jump",    gp ? "A button"       : "W / Up / Space"},
		{"Attack",  gp ? "X button"       : "J / Left Mouse"},
		{"Special", gp ? "Y button"       : "K / Right Mouse"},
		{"Dash",    gp ? "B button"       : "Shift"},
		{"Pause",   gp ? "Start"          : "Esc"},
		{"Confirm", gp ? "A button"       : "Enter / Space"},
		{"Back",    gp ? "B button"       : "Esc"},
	}

	col_label_x: i32 = 130
	col_value_x: i32 = 320
	row_y_start: i32 = 64
	row_h: i32 = 14
	for row, i in rows {
		y := row_y_start + i32(i) * row_h
		raylib.DrawText(row[0], col_label_x, y, 10, raylib.WHITE)
		raylib.DrawText(row[1], col_value_x, y, 10, raylib.LIGHTGRAY)
	}

	hint: cstring = "Esc/B to go back"
	hw := raylib.MeasureText(hint, 8)
	raylib.DrawText(hint, SCREEN_WIDTH/2 - hw/2, row_y_start + i32(len(rows)) * row_h + 6, 8, raylib.LIGHTGRAY)
}

@(private = "file")
draw_pause_options :: proc() {
	title: cstring = "OPTIONS"
	tw := raylib.MeasureText(title, 20)
	raylib.DrawText(title, SCREEN_WIDTH/2 - tw/2, 18, 20, raylib.WHITE)

	rows := [2]struct{ label: cstring, value: f32 }{
		{"Music", gs.music_volume},
		{"SFX",   gs.sfx_volume},
	}

	row_y_start: i32 = 70
	row_h: i32 = 24
	for row, i in rows {
		y := row_y_start + i32(i) * row_h
		selected := i == gs.menu_selected

		label_color := selected ? raylib.YELLOW : raylib.WHITE
		raylib.DrawText(row.label, 200, y, 14, label_color)

		bar_x: i32 = 280
		bar_w: i32 = 120
		bar_h: i32 = 8
		bar_y := y + 3

		raylib.DrawRectangle(bar_x - 1, bar_y - 1, bar_w + 2, bar_h + 2, raylib.Color{0, 0, 0, 220})
		fill_w := i32(f32(bar_w) * row.value)
		raylib.DrawRectangle(bar_x, bar_y, fill_w, bar_h, raylib.Color{0xCC, 0xCC, 0x33, 0xFF})

		pct := fmt.ctprintf("%d%%", i32(row.value * 100 + 0.5))
		raylib.DrawText(pct, bar_x + bar_w + 6, y, 14, label_color)

		if selected {
			raylib.DrawText("<", bar_x - 14, y, 14, raylib.YELLOW)
			raylib.DrawText(">", bar_x + bar_w + 60, y, 14, raylib.YELLOW)
		}
	}

	hint: cstring = "Up/Down to switch  |  Left/Right to adjust  |  Esc/B to go back"
	hw := raylib.MeasureText(hint, 8)
	raylib.DrawText(hint, SCREEN_WIDTH/2 - hw/2, row_y_start + i32(len(rows)) * row_h + 6, 8, raylib.LIGHTGRAY)
}

@(private = "file")
draw_player_stats_panel :: proc() {
	box_x: i32 = 20
	box_y: i32 = 250
	box_w: i32 = SCREEN_WIDTH - 40
	box_h: i32 = 90

	raylib.DrawRectangle(box_x, box_y, box_w, box_h, raylib.Color{0x10, 0x10, 0x28, 230})
	raylib.DrawRectangleLines(box_x, box_y, box_w, box_h, raylib.Color{0xAA, 0xAA, 0xAA, 255})

	header: cstring = "Player Stats"
	hw := raylib.MeasureText(header, 12)
	raylib.DrawText(header, box_x + box_w/2 - hw/2, box_y + 6, 12, raylib.WHITE)

	p := &gs.player
	caps_note: cstring = p.stats_capped ? " (capped)" : ""

	hp_text   := fmt.ctprintf("HP:        %d / %d%s", i32(p.hp), i32(p.max_hp), caps_note)
	stam_text := fmt.ctprintf("Stamina:   %d / %d",   i32(p.stamina), i32(p.max_stamina))
	dmg_text  := fmt.ctprintf("Damage:    +%d%%%s",   i32(p.damage_multiplier * 100 + 0.5), caps_note)
	crit_text := fmt.ctprintf("Crit:      %d%%%s",    i32(p.crit_chance * 100 + 0.5), caps_note)
	atks_text := fmt.ctprintf("Atk Speed: +%d%%%s",   i32(p.attack_speed_multiplier * 100 + 0.5), caps_note)

	col_l_x := box_x + 12
	col_r_x := box_x + box_w/2 + 4
	row_y_start := box_y + 26
	row_h: i32 = 14

	raylib.DrawText(hp_text,   col_l_x, row_y_start + 0 * row_h, 10, raylib.WHITE)
	raylib.DrawText(stam_text, col_l_x, row_y_start + 1 * row_h, 10, raylib.WHITE)
	raylib.DrawText(dmg_text,  col_l_x, row_y_start + 2 * row_h, 10, raylib.WHITE)
	raylib.DrawText(crit_text, col_r_x, row_y_start + 0 * row_h, 10, raylib.WHITE)
	raylib.DrawText(atks_text, col_r_x, row_y_start + 1 * row_h, 10, raylib.WHITE)
}

@(private = "file")
draw_parallax_bg :: proc() {
	speeds := PARALLAX_SPEEDS
	for i in 0 ..< PARALLAX_LAYER_COUNT {
		tex := gs.bg_textures[i]
		if tex.id == 0 {
			continue
		}
		offset := gs.camera.target.x * speeds[i] * gs.camera.zoom
		wrapped := offset - f32(SCREEN_WIDTH) * math.floor_f32(offset / f32(SCREEN_WIDTH))
		src := raylib.Rectangle{0, 0, f32(SCREEN_WIDTH), f32(SCREEN_HEIGHT)}
		raylib.DrawTextureRec(tex, src, {-wrapped, 0}, raylib.WHITE)
		raylib.DrawTextureRec(tex, src, {f32(SCREEN_WIDTH) - wrapped, 0}, raylib.WHITE)
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

@(private = "file")
update_main_menu :: proc(dt: f32) {
	gs.main_menu_timer += dt

	title_t := min(gs.main_menu_timer / MAIN_MENU_TITLE_ANIM_DUR, 1.0)
	inv_t := 1.0 - title_t
	title_ease := 1.0 - inv_t * inv_t * inv_t
	gs.main_menu_title_y = MAIN_MENU_TITLE_START_Y +
		(MAIN_MENU_TITLE_REST_Y - MAIN_MENU_TITLE_START_Y) * title_ease

	items_elapsed := max(gs.main_menu_timer - MAIN_MENU_ITEMS_DELAY, 0.0)
	items_t := min(items_elapsed / MAIN_MENU_ITEMS_ANIM_DUR, 1.0)
	inv_it := 1.0 - items_t
	items_ease := 1.0 - inv_it * inv_it * inv_it
	gs.main_menu_items_x = MAIN_MENU_ITEMS_OFFSET * (1.0 - items_ease)

	idle_frames := gs.player.idle_frames
	if idle_frames > 1 {
		gs.main_menu_idle_timer += dt
		if gs.main_menu_idle_timer >= PLAYER_IDLE_ANIM_SPEED {
			gs.main_menu_idle_timer -= PLAYER_IDLE_ANIM_SPEED
			gs.main_menu_idle_frame += 1
			if gs.main_menu_idle_frame >= idle_frames {
				gs.main_menu_idle_frame = 0
			}
		}
	}

	switch gs.main_menu_screen {
	case .Main:
		update_main_menu_main()
	case .Options:
		update_main_menu_options()
	case .Controls:
		// only ESC/Start to back out
	case .Audio:
		update_pause_options()
	case .Hints:
		update_hints_menu()
	}
}

@(private = "file")
update_main_menu_main :: proc() {
	if input_menu_up() {
		gs.menu_selected -= 1
		if gs.menu_selected < 0 {
			gs.menu_selected = MAIN_MENU_ITEM_COUNT - 1
		}
	}
	if input_menu_down() {
		gs.menu_selected += 1
		if gs.menu_selected >= MAIN_MENU_ITEM_COUNT {
			gs.menu_selected = 0
		}
	}
	if !input_menu_confirm() {
		return
	}
	switch gs.menu_selected {
	case 0:
		gs.menu = .Playing
		play_sound(.UI_Confirm)
	case 1:
		gs.main_menu_screen = .Options
		gs.menu_selected = 0
		play_sound(.UI_Confirm)
	case 2:
		when ODIN_ARCH != .wasm32 && ODIN_ARCH != .wasm64p32 {
			gs.should_quit = true
			play_sound(.UI_Negative_Back)
		}
	}
}

@(private = "file")
update_main_menu_options :: proc() {
	if input_menu_up() {
		gs.menu_selected -= 1
		if gs.menu_selected < 0 {
			gs.menu_selected = MAIN_MENU_OPTIONS_ITEM_COUNT - 1
		}
	}
	if input_menu_down() {
		gs.menu_selected += 1
		if gs.menu_selected >= MAIN_MENU_OPTIONS_ITEM_COUNT {
			gs.menu_selected = 0
		}
	}
	if !input_menu_confirm() {
		return
	}
	switch gs.menu_selected {
	case 0:
		gs.main_menu_screen = .Audio
		gs.menu_selected = 0
		play_sound(.UI_Confirm)
	case 1:
		gs.main_menu_screen = .Controls
		play_sound(.UI_Confirm)
	case 2:
		gs.main_menu_screen = .Hints
		gs.hint_view_idx = 0
		play_sound(.UI_Confirm)
	}
}

@(private = "file")
handle_main_menu_back :: proc() {
	switch gs.main_menu_screen {
	case .Main:
		// nothing to do — already at top level
	case .Options:
		gs.main_menu_screen = .Main
		gs.menu_selected = 1
		play_sound(.UI_Negative_Back)
	case .Controls, .Audio, .Hints:
		gs.main_menu_screen = .Options
		gs.menu_selected = 0
		play_sound(.UI_Negative_Back)
	}
}

@(private = "file")
draw_main_menu :: proc() {
	draw_main_menu_parallax()

	switch gs.main_menu_screen {
	case .Main:
		draw_main_menu_idle_sprite()
		draw_main_menu_title()
		draw_main_menu_items()
	case .Options:
		raylib.DrawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, raylib.Color{0, 0, 0, 200})
		draw_main_menu_options_panel()
	case .Controls:
		raylib.DrawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, raylib.Color{0, 0, 0, 200})
		draw_pause_controls()
	case .Audio:
		raylib.DrawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, raylib.Color{0, 0, 0, 200})
		draw_pause_options()
	case .Hints:
		raylib.DrawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, raylib.Color{0, 0, 0, 200})
		draw_hints_panel()
	}
}

@(private = "file")
draw_main_menu_parallax :: proc() {
	speeds := PARALLAX_SPEEDS
	scroll := gs.main_menu_timer * 30
	for i in 0 ..< PARALLAX_LAYER_COUNT {
		tex := gs.bg_textures[i]
		if tex.id == 0 {
			continue
		}
		offset := scroll * speeds[i] * 4
		wrapped := offset - f32(SCREEN_WIDTH) * math.floor_f32(offset / f32(SCREEN_WIDTH))
		src := raylib.Rectangle{0, 0, f32(SCREEN_WIDTH), f32(SCREEN_HEIGHT)}
		raylib.DrawTextureRec(tex, src, {-wrapped, 0}, raylib.WHITE)
		raylib.DrawTextureRec(tex, src, {f32(SCREEN_WIDTH) - wrapped, 0}, raylib.WHITE)
	}
}

@(private = "file")
draw_main_menu_idle_sprite :: proc() {
	if gs.player.idle_tex.id == 0 || gs.player.idle_frames <= 0 {
		return
	}
	frame := gs.main_menu_idle_frame
	if frame >= gs.player.idle_frames {
		frame = 0
	}
	src := raylib.Rectangle{
		f32(frame * SPRITE_SRC_SIZE), 0,
		f32(SPRITE_SRC_SIZE),
		f32(SPRITE_SRC_SIZE),
	}
	dst := raylib.Rectangle{
		f32(SCREEN_WIDTH) * 0.78 - MAIN_MENU_SPRITE_SIZE / 2,
		f32(SCREEN_HEIGHT) * 0.62 - MAIN_MENU_SPRITE_SIZE / 2,
		MAIN_MENU_SPRITE_SIZE,
		MAIN_MENU_SPRITE_SIZE,
	}
	raylib.DrawTexturePro(gs.player.idle_tex, src, dst, {0, 0}, 0, raylib.WHITE)
}

@(private = "file")
draw_main_menu_title :: proc() {
	title : cstring = "Ziusudra's Last Stand"
	title_w := raylib.MeasureText(title, MAIN_MENU_TITLE_SIZE)
	title_x := (SCREEN_WIDTH - title_w) / 2
	raylib.DrawText(title, title_x + 2, i32(gs.main_menu_title_y) + 2, MAIN_MENU_TITLE_SIZE, raylib.Color{0, 0, 0, 180})
	raylib.DrawText(title, title_x, i32(gs.main_menu_title_y), MAIN_MENU_TITLE_SIZE, raylib.Color{0xFF, 0xE5, 0x99, 0xFF})

	subtitle : cstring = "Your life, or the lives of your people"
	sub_w := raylib.MeasureText(subtitle, MAIN_MENU_SUBTITLE_SIZE)
	sub_y := i32(gs.main_menu_title_y) + MAIN_MENU_TITLE_SIZE + 4
	raylib.DrawText(subtitle, (SCREEN_WIDTH - sub_w) / 2, sub_y, MAIN_MENU_SUBTITLE_SIZE, raylib.Color{220, 220, 220, 255})
}

@(private = "file")
draw_main_menu_items :: proc() {
	when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
		items := [MAIN_MENU_ITEM_COUNT]cstring{"PLAY", "OPTIONS"}
	} else {
		items := [MAIN_MENU_ITEM_COUNT]cstring{"PLAY", "OPTIONS", "QUIT"}
	}

	for item, i in items {
		item_w := raylib.MeasureText(item, MAIN_MENU_ITEM_SIZE)
		item_x := (SCREEN_WIDTH - item_w) / 2 + i32(gs.main_menu_items_x)
		item_y := MAIN_MENU_ITEM_BASE_Y + i32(i) * MAIN_MENU_ITEM_SPACING

		color := raylib.Color{170, 170, 170, 255}
		if i == gs.menu_selected {
			color = raylib.YELLOW
		}
		raylib.DrawText(item, item_x, item_y, MAIN_MENU_ITEM_SIZE, color)
	}

	if gs.menu_selected >= 0 && gs.menu_selected < MAIN_MENU_ITEM_COUNT {
		sel_item := items[gs.menu_selected]
		sel_w := raylib.MeasureText(sel_item, MAIN_MENU_ITEM_SIZE)
		arrow_x := (SCREEN_WIDTH - sel_w) / 2 + i32(gs.main_menu_items_x) - 16
		arrow_y := MAIN_MENU_ITEM_BASE_Y + i32(gs.menu_selected) * MAIN_MENU_ITEM_SPACING
		raylib.DrawText(">", arrow_x, arrow_y, MAIN_MENU_ITEM_SIZE, raylib.YELLOW)
	}

	hint: cstring = "Up/Down + Confirm"
	hw := raylib.MeasureText(hint, MAIN_MENU_HINT_SIZE)
	raylib.DrawText(hint, (SCREEN_WIDTH - hw) / 2, SCREEN_HEIGHT - 16, MAIN_MENU_HINT_SIZE, raylib.Color{180, 180, 180, 255})
}

@(private = "file")
draw_main_menu_options_panel :: proc() {
	title: cstring = "OPTIONS"
	tw := raylib.MeasureText(title, 20)
	raylib.DrawText(title, SCREEN_WIDTH/2 - tw/2, 18, 20, raylib.WHITE)

	items := [MAIN_MENU_OPTIONS_ITEM_COUNT]cstring{"AUDIO", "CONTROLS", "HINTS"}

	for item, i in items {
		iw := raylib.MeasureText(item, MAIN_MENU_ITEM_SIZE)
		ix := SCREEN_WIDTH/2 - iw/2
		iy := MAIN_MENU_OPTIONS_BASE_Y + i32(i) * MAIN_MENU_OPTIONS_SPACING
		color := raylib.WHITE
		if i == gs.menu_selected {
			color = raylib.YELLOW
		}
		raylib.DrawText(item, ix, iy, MAIN_MENU_ITEM_SIZE, color)
		if i == gs.menu_selected {
			raylib.DrawText(">", ix - 14, iy, MAIN_MENU_ITEM_SIZE, raylib.YELLOW)
		}
	}

	hint: cstring = "Esc/B to go back"
	hw := raylib.MeasureText(hint, 8)
	raylib.DrawText(hint, SCREEN_WIDTH/2 - hw/2, SCREEN_HEIGHT - 20, 8, raylib.LIGHTGRAY)
}

@(private = "file")
update_hints :: proc(dt: f32) {
	if gs.wave <= 2 && !gs.hint_active {
		gs.hint_play_time += dt
		for kind in Hint_Kind {
			if gs.hint_auto_shown[kind] {
				continue
			}
			if gs.hint_play_time >= HINT_TRIGGER_TIME[kind] {
				gs.hint_active = true
				gs.hint_current = kind
				gs.hint_display_timer = 0
				gs.hint_auto_shown[kind] = true
				play_sound(.UI_Confirm)
				break
			}
		}
	}

	if !gs.hint_active {
		return
	}
	if input_hint_dismiss() {
		gs.hint_active = false
		play_sound(.UI_Negative_Back)
		return
	}
	gs.hint_display_timer += dt
	if gs.hint_display_timer >= HINT_AUTOCLOSE_DURATION {
		gs.hint_active = false
	}
}

@(private = "file")
update_hints_menu :: proc() {
	if input_menu_left() {
		gs.hint_view_idx -= 1
		if gs.hint_view_idx < 0 {
			gs.hint_view_idx = HINT_COUNT - 1
		}
		play_sound(.UI_Confirm)
	}
	if input_menu_right() {
		gs.hint_view_idx += 1
		if gs.hint_view_idx >= HINT_COUNT {
			gs.hint_view_idx = 0
		}
		play_sound(.UI_Confirm)
	}
}

@(private = "file")
draw_hint_popup :: proc() {
	if !gs.hint_active {
		return
	}

	kind := gs.hint_current
	title := HINT_TITLES[kind]
	body  := HINT_BODIES[kind]

	box_w: i32 = 360
	box_h: i32 = 64
	box_x: i32 = SCREEN_WIDTH/2 - box_w/2
	box_y: i32 = 6

	raylib.DrawRectangle(box_x, box_y, box_w, box_h, raylib.Color{0x10, 0x10, 0x28, 230})
	raylib.DrawRectangleLines(box_x, box_y, box_w, box_h, raylib.Color{0xFF, 0xE5, 0x99, 0xFF})

	tw := raylib.MeasureText(title, 10)
	raylib.DrawText(title, SCREEN_WIDTH/2 - tw/2, box_y + 4, 10, raylib.YELLOW)

	line_y := box_y + 18
	for line in body {
		if line == "" {
			continue
		}
		lw := raylib.MeasureText(line, 8)
		raylib.DrawText(line, SCREEN_WIDTH/2 - lw/2, line_y, 8, raylib.WHITE)
		line_y += 10
	}

	dismiss: cstring = gamepad_active() ? "Back to dismiss" : "Press C to dismiss"
	dw := raylib.MeasureText(dismiss, 8)
	raylib.DrawText(dismiss, SCREEN_WIDTH/2 - dw/2, box_y + box_h - 11, 8, raylib.LIGHTGRAY)
}

@(private = "file")
draw_hints_panel :: proc() {
	title: cstring = "HINTS"
	tw := raylib.MeasureText(title, 20)
	raylib.DrawText(title, SCREEN_WIDTH/2 - tw/2, 18, 20, raylib.WHITE)

	idx := gs.hint_view_idx
	if idx < 0 || idx >= HINT_COUNT {
		idx = 0
	}
	kind := Hint_Kind(idx)

	page := fmt.ctprintf("%d / %d", idx + 1, HINT_COUNT)
	pw := raylib.MeasureText(page, 8)
	raylib.DrawText(page, SCREEN_WIDTH/2 - pw/2, 46, 8, raylib.LIGHTGRAY)

	htitle := HINT_TITLES[kind]
	htw := raylib.MeasureText(htitle, 16)
	raylib.DrawText(htitle, SCREEN_WIDTH/2 - htw/2, 84, 16, raylib.YELLOW)

	body := HINT_BODIES[kind]
	line_y: i32 = 130
	for line in body {
		if line == "" {
			continue
		}
		lw := raylib.MeasureText(line, 12)
		raylib.DrawText(line, SCREEN_WIDTH/2 - lw/2, line_y, 12, raylib.WHITE)
		line_y += 18
	}

	arrow_y: i32 = 124
	raylib.DrawText("<", 80, arrow_y, 24, raylib.YELLOW)
	raylib.DrawText(">", SCREEN_WIDTH - 96, arrow_y, 24, raylib.YELLOW)

	hint: cstring = "Left/Right to browse  |  Esc/B to go back"
	hw := raylib.MeasureText(hint, 8)
	raylib.DrawText(hint, SCREEN_WIDTH/2 - hw/2, SCREEN_HEIGHT - 24, 8, raylib.LIGHTGRAY)
}
