shader_type canvas_item;

// Slight background defocus for the Darkest-Dungeon style act focus
// (Docs/System Design/Shootout/Shootout UI.md): while an act plays, the
// shootout background blurs and dims a little so the zoomed-in fighters read
// clearly. A 9-tap box blur in texture-pixel steps keeps the pixel-art look —
// "amount" is in texture pixels, so 0.0 draws the untouched background.
uniform float amount : hint_range(0.0, 4.0) = 0.0;
uniform float dim : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	if (amount > 0.0) {
		vec2 step = TEXTURE_PIXEL_SIZE * amount;
		color = (
			color
			+ texture(TEXTURE, UV + vec2(step.x, 0.0))
			+ texture(TEXTURE, UV - vec2(step.x, 0.0))
			+ texture(TEXTURE, UV + vec2(0.0, step.y))
			+ texture(TEXTURE, UV - vec2(0.0, step.y))
			+ texture(TEXTURE, UV + step)
			+ texture(TEXTURE, UV - step)
			+ texture(TEXTURE, UV + vec2(step.x, -step.y))
			+ texture(TEXTURE, UV + vec2(-step.x, step.y))
		) / 9.0;
	}
	COLOR = vec4(color.rgb * (1.0 - dim), color.a);
}