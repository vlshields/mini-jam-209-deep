package game

import "core:strings"
import "vendor:raylib"

@(private = "file")
HITFLASH_FS_DESKTOP :: `#version 330
in vec2 fragTexCoord;
in vec4 fragColor;
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float flashAmount;
out vec4 finalColor;
void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);
    vec4 baseColor = texelColor * colDiffuse * fragColor;
    float a = clamp(flashAmount, 0.0, 1.0);
    vec3 flashed = mix(baseColor.rgb, vec3(1.0), a);
    finalColor = vec4(flashed, baseColor.a);
}
`

@(private = "file")
HITFLASH_FS_WEB :: `#version 100
precision mediump float;
varying vec2 fragTexCoord;
varying vec4 fragColor;
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float flashAmount;
void main() {
    vec4 texelColor = texture2D(texture0, fragTexCoord);
    vec4 baseColor = texelColor * colDiffuse * fragColor;
    float a = clamp(flashAmount, 0.0, 1.0);
    vec3 flashed = mix(baseColor.rgb, vec3(1.0), a);
    gl_FragColor = vec4(flashed, baseColor.a);
}
`

@(private = "file")
hitflash_shader: raylib.Shader

@(private = "file")
hitflash_amount_loc: i32

@(private = "file")
hitflash_loaded: bool

init_hitflash_shader :: proc() {
	src: string
	when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
		src = HITFLASH_FS_WEB
	} else {
		src = HITFLASH_FS_DESKTOP
	}
	cs := strings.clone_to_cstring(src)
	defer delete(cs)
	hitflash_shader = raylib.LoadShaderFromMemory(nil, cs)
	hitflash_amount_loc = raylib.GetShaderLocation(hitflash_shader, "flashAmount")
	hitflash_loaded = hitflash_shader.id != 0
}

unload_hitflash_shader :: proc() {
	if !hitflash_loaded {
		return
	}
	raylib.UnloadShader(hitflash_shader)
	hitflash_loaded = false
}

begin_hitflash :: proc(amount: f32) {
	if !hitflash_loaded {
		return
	}
	a := clamp(amount, 0, 1)
	raylib.SetShaderValue(hitflash_shader, hitflash_amount_loc, &a, .FLOAT)
	raylib.BeginShaderMode(hitflash_shader)
}

end_hitflash :: proc() {
	if !hitflash_loaded {
		return
	}
	raylib.EndShaderMode()
}
