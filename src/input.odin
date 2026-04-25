package game

import raylib "vendor:raylib"

GAMEPAD_ID     :: 0
STICK_DEADZONE :: f32(0.25)

gamepad_active :: proc() -> bool {
	return raylib.IsGamepadAvailable(GAMEPAD_ID)
}

input_move_left :: proc() -> bool {
	if raylib.IsKeyDown(.A) || raylib.IsKeyDown(.LEFT) {
		return true
	}
	if gamepad_active() && raylib.GetGamepadAxisMovement(GAMEPAD_ID, .LEFT_X) < -STICK_DEADZONE {
		return true
	}
	return false
}

input_move_right :: proc() -> bool {
	if raylib.IsKeyDown(.D) || raylib.IsKeyDown(.RIGHT) {
		return true
	}
	if gamepad_active() && raylib.GetGamepadAxisMovement(GAMEPAD_ID, .LEFT_X) > STICK_DEADZONE {
		return true
	}
	return false
}

input_move_down :: proc() -> bool {
	if raylib.IsKeyDown(.S) || raylib.IsKeyDown(.DOWN) {
		return true
	}
	if gamepad_active() && raylib.GetGamepadAxisMovement(GAMEPAD_ID, .LEFT_Y) > STICK_DEADZONE {
		return true
	}
	return false
}

input_jump :: proc() -> bool {
	if raylib.IsKeyPressed(.W) || raylib.IsKeyPressed(.UP) || raylib.IsKeyPressed(.SPACE) {
		return true
	}
	if gamepad_active() && raylib.IsGamepadButtonPressed(GAMEPAD_ID, .RIGHT_FACE_DOWN) {
		return true
	}
	return false
}

input_attack :: proc() -> bool {
	if raylib.IsKeyPressed(.J) || raylib.IsMouseButtonPressed(.LEFT) {
		return true
	}
	if gamepad_active() && raylib.IsGamepadButtonPressed(GAMEPAD_ID, .RIGHT_FACE_LEFT) {
		return true
	}
	return false
}

input_projectile :: proc() -> bool {
	if raylib.IsKeyPressed(.K) || raylib.IsMouseButtonPressed(.RIGHT) {
		return true
	}
	if gamepad_active() && raylib.IsGamepadButtonPressed(GAMEPAD_ID, .RIGHT_FACE_UP) {
		return true
	}
	return false
}

input_dash :: proc() -> bool {
	if raylib.IsKeyPressed(.LEFT_SHIFT) || raylib.IsKeyPressed(.RIGHT_SHIFT) {
		return true
	}
	if gamepad_active() && raylib.IsGamepadButtonPressed(GAMEPAD_ID, .RIGHT_FACE_RIGHT) {
		return true
	}
	return false
}

input_pause :: proc() -> bool {
	if raylib.IsKeyPressed(.ESCAPE) {
		return true
	}
	if gamepad_active() && raylib.IsGamepadButtonPressed(GAMEPAD_ID, .MIDDLE_RIGHT) {
		return true
	}
	return false
}
