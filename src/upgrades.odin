package game

import "vendor:raylib"
import "core:fmt"
import "core:math/rand"
import "core:strings"

Stat_Kind :: enum {
	HP,
	Stamina,
	Attack_Speed,
	Damage,
	Crit_Chance,
}

Stat_Upgrade :: struct {
	kind:   Stat_Kind,
	amount: f32,
	title:  string,
	desc:   string,
}

Weapon_Kind :: enum {
	Double_Strike,
	Waveblade,
	Orb,
	Water_Twister,
}

WEAPON_COUNT :: len(Weapon_Kind)

@(private = "file")
sample_stat_variant :: proc(kind: Stat_Kind) -> (amount: f32, desc: string) {
	r := rand.float32()
	switch kind {
	case .HP:
		if r < 0.6 { return 15, "+15 max HP" }
		if r < 0.9 { return 10, "+10 max HP" }
		return 35, "+35 max HP"
	case .Stamina:
		if r < 0.6 { return 25, "+25 max Stamina" }
		if r < 0.9 { return 10, "+10 max Stamina" }
		return 45, "+45 max Stamina"
	case .Attack_Speed:
		if r < 0.1 { return 0.25, "+25% Attack Speed" }
		if r < 0.9 { return 0.10, "+10% Attack Speed" }
		return 0.30, "+30% Attack Speed"
	case .Damage:
		if r < 0.6 { return 0.15, "+15% Damage" }
		if r < 0.9 { return 0.08, "+8% Damage" }
		return 0.40, "+40% Damage"
	case .Crit_Chance:
		if r < 0.6 { return 0.02, "+2% Crit Chance" }
		if r < 0.9 { return 0.01, "+1% Crit Chance" }
		return 0.05, "+5% Crit Chance"
	}
	return 0, ""
}

@(private = "file")
stat_title :: proc(k: Stat_Kind) -> string {
	switch k {
	case .HP:           return "HP"
	case .Stamina:      return "Stamina"
	case .Attack_Speed: return "Attack Speed"
	case .Damage:       return "Damage"
	case .Crit_Chance:  return "Crit Chance"
	}
	return ""
}

sample_stat_choices :: proc() -> [3]Stat_Upgrade {
	kinds := [5]Stat_Kind{.HP, .Stamina, .Attack_Speed, .Damage, .Crit_Chance}
	for i := 0; i < 3; i += 1 {
		j := i + int(rand.int31_max(i32(5 - i)))
		kinds[i], kinds[j] = kinds[j], kinds[i]
	}
	result: [3]Stat_Upgrade
	for i := 0; i < 3; i += 1 {
		amount, desc := sample_stat_variant(kinds[i])
		result[i] = Stat_Upgrade{
			kind   = kinds[i],
			amount = amount,
			title  = stat_title(kinds[i]),
			desc   = desc,
		}
	}
	return result
}

apply_stat_upgrade :: proc(p: ^Player, u: Stat_Upgrade) {
	if p.stats_capped && u.kind != .Stamina {
		return
	}
	switch u.kind {
	case .HP:
		p.max_hp += u.amount
		p.hp += u.amount
	case .Stamina:
		p.max_stamina += u.amount
		p.stamina += u.amount
	case .Attack_Speed:
		p.attack_speed_multiplier += u.amount
	case .Damage:
		p.damage_multiplier += u.amount
	case .Crit_Chance:
		p.crit_chance += u.amount
	}
}

weapon_title :: proc(k: Weapon_Kind) -> string {
	switch k {
	case .Double_Strike: return "Double Strike"
	case .Waveblade:     return "Waveblade"
	case .Orb:           return "Orb"
	case .Water_Twister: return "Water Twister"
	}
	return ""
}

weapon_desc :: proc(k: Weapon_Kind) -> string {
	switch k {
	case .Double_Strike: return "Your final attack has\na 13% chance to land twice"
	case .Waveblade:     return "You attack with a spinning\nwater-blade that deals\n30 base dmg"
	case .Orb:           return "Your special is a giant\norb that deals 40 base dmg,\nand has a chance to apply slow"
	case .Water_Twister: return "Your special is a deadly twister\ndealing 20 base dmg and +18%\nbackstab dmg. Press again to recall."
	}
	return ""
}

sample_weapon_choices :: proc(available: [Weapon_Kind]bool) -> (choices: [3]Weapon_Kind, count: int) {
	all_weapons := [WEAPON_COUNT]Weapon_Kind{.Double_Strike, .Waveblade, .Orb, .Water_Twister}
	pool: [WEAPON_COUNT]Weapon_Kind
	n := 0
	for k in all_weapons {
		if available[k] {
			pool[n] = k
			n += 1
		}
	}
	for i := 0; i < n; i += 1 {
		j := i + int(rand.int31_max(i32(n - i)))
		pool[i], pool[j] = pool[j], pool[i]
	}
	take := n
	if take > 3 {
		take = 3
	}
	for i := 0; i < take; i += 1 {
		choices[i] = pool[i]
	}
	return choices, take
}

apply_weapon_upgrade :: proc(p: ^Player, k: Weapon_Kind) {
	switch k {
	case .Double_Strike:
		p.has_double_strike = true
	case .Waveblade:
		p.x_weapon = .Waveblade
		p.waveblade_state = .Idle
		p.waveblade_frame = 0
		p.waveblade_anim_timer = 0
	case .Orb:
		p.y_weapon = .Orb
		p.orb_state = .Inactive
	case .Water_Twister:
		p.y_weapon = .Water_Twister
		p.twister_state = .Inactive
		p.twister_frame = 0
		p.twister_anim_timer = 0
	}
}

draw_choice_menu :: proc(title: cstring, titles: []string, descs: []string, count: int, selected: int) {
	raylib.DrawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, raylib.Color{0, 0, 0, 200})

	tw := raylib.MeasureText(title, 20)
	raylib.DrawText(title, SCREEN_WIDTH/2 - tw/2, 30, 20, raylib.WHITE)

	BOX_W :: i32(180)
	BOX_H :: i32(140)
	GAP   :: i32(15)
	c := i32(count)
	if c <= 0 {
		hint: cstring = "No upgrades available"
		hw := raylib.MeasureText(hint, 14)
		raylib.DrawText(hint, SCREEN_WIDTH/2 - hw/2, SCREEN_HEIGHT/2, 14, raylib.WHITE)
		return
	}
	total_w := c * BOX_W + (c - 1) * GAP
	start_x := (SCREEN_WIDTH - total_w) / 2
	y := i32(SCREEN_HEIGHT/2) - BOX_H/2

	for i in 0 ..< count {
		x := start_x + i32(i) * (BOX_W + GAP)
		is_selected := i == selected
		bg := raylib.Color{0x20, 0x20, 0x40, 240}
		if is_selected {
			bg = raylib.Color{0x40, 0x40, 0x70, 250}
		}
		raylib.DrawRectangle(x, y, BOX_W, BOX_H, bg)
		border_color := is_selected ? raylib.YELLOW : raylib.GRAY
		raylib.DrawRectangleLines(x, y, BOX_W, BOX_H, border_color)
		if is_selected {
			raylib.DrawRectangleLines(x - 1, y - 1, BOX_W + 2, BOX_H + 2, raylib.YELLOW)
			raylib.DrawRectangleLines(x - 2, y - 2, BOX_W + 4, BOX_H + 4, raylib.YELLOW)
		}

		key := fmt.ctprintf("%d", i + 1)
		raylib.DrawText(key, x + 8, y + 8, 20, raylib.YELLOW)

		t_c := strings.clone_to_cstring(titles[i], context.temp_allocator)
		raylib.DrawText(t_c, x + 8, y + 40, 14, raylib.WHITE)

		d_c := strings.clone_to_cstring(descs[i], context.temp_allocator)
		raylib.DrawText(d_c, x + 8, y + 64, 8, raylib.LIGHTGRAY)
	}

	hint: cstring = gamepad_active() \
		? "D-pad + A to confirm" \
		: "1/2/3 or Enter to confirm"
	hw := raylib.MeasureText(hint, 10)
	raylib.DrawText(hint, SCREEN_WIDTH/2 - hw/2, SCREEN_HEIGHT - 30, 10, raylib.WHITE)
}

input_choice_pressed :: proc() -> int {
	if raylib.IsKeyPressed(.ONE)   { return 1 }
	if raylib.IsKeyPressed(.TWO)   { return 2 }
	if raylib.IsKeyPressed(.THREE) { return 3 }
	return 0
}

input_menu_left :: proc() -> bool {
	if raylib.IsKeyPressed(.A) || raylib.IsKeyPressed(.LEFT) { return true }
	if gamepad_active() && raylib.IsGamepadButtonPressed(GAMEPAD_ID, .LEFT_FACE_LEFT) { return true }
	return false
}

input_menu_right :: proc() -> bool {
	if raylib.IsKeyPressed(.D) || raylib.IsKeyPressed(.RIGHT) { return true }
	if gamepad_active() && raylib.IsGamepadButtonPressed(GAMEPAD_ID, .LEFT_FACE_RIGHT) { return true }
	return false
}

input_menu_confirm :: proc() -> bool {
	if raylib.IsKeyPressed(.ENTER) || raylib.IsKeyPressed(.SPACE) { return true }
	if gamepad_active() && raylib.IsGamepadButtonPressed(GAMEPAD_ID, .RIGHT_FACE_DOWN) { return true }
	return false
}

input_menu_up :: proc() -> bool {
	if raylib.IsKeyPressed(.W) || raylib.IsKeyPressed(.UP) { return true }
	if gamepad_active() && raylib.IsGamepadButtonPressed(GAMEPAD_ID, .LEFT_FACE_UP) { return true }
	return false
}

input_menu_down :: proc() -> bool {
	if raylib.IsKeyPressed(.S) || raylib.IsKeyPressed(.DOWN) { return true }
	if gamepad_active() && raylib.IsGamepadButtonPressed(GAMEPAD_ID, .LEFT_FACE_DOWN) { return true }
	return false
}

input_menu_back :: proc() -> bool {
	if raylib.IsKeyPressed(.ESCAPE) { return true }
	if gamepad_active() && raylib.IsGamepadButtonPressed(GAMEPAD_ID, .RIGHT_FACE_RIGHT) { return true }
	return false
}
