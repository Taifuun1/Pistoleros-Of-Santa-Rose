shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D noise : repeat_enable;
uniform float distortion_strength : hint_range(-1, 1) = 0.2;
uniform vec4 tone_color : source_color;
uniform vec4 top_color : source_color;
uniform float light_start : hint_range(0.0, 1.0) = 0.275;
uniform float light_end : hint_range(0.0, 1.0) = 0.4;

void fragment() {
	vec4 noise_col = texture(noise, UV);
	vec4 screen_col = texture(
		screen_texture,
		SCREEN_UV + distortion_strength * noise_col.rr
	);
	vec4 top_light = smoothstep(light_start, light_end, noise_col) * top_color;
	COLOR = screen_col * tone_color + top_light;
//	COLOR.a = 1.0;
}
