shader_type canvas_item;

// Center of the player's visible sprite in world space. This is intentionally
// separate from the player's Y-sort origin, which is usually at their feet.
uniform vec2 player_reveal_position;

// Radius of the transparency circle around player
uniform float reveal_radius : hint_range(0.0, 500.0) = 80.0;

// How soft the edge of the transparency circle should be
uniform float reveal_softness : hint_range(0.0, 100.0) = 10.0;

// Minimum alpha for objects (0.0 = fully transparent, 1.0 = fully opaque)
// Keep this at zero by default so overlapping revealable sprites do not build
// back up into an opaque patch over the player.
uniform float min_alpha : hint_range(0.0, 1.0) = 0.0;

// Whether this shader is enabled
uniform bool enabled = true;

// Varying to pass world position from vertex to fragment
varying vec2 world_position;

void vertex() {
	// Calculate world position by transforming local vertex position
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	if (!enabled || tex_color.a < 0.01) {
		COLOR = tex_color;
	} else {
		// Apply the circle per fragment. Y-sorting already determines whether a
		// sprite is rendered in front of the player; gating the entire material by
		// its node origin incorrectly removes portions of the reveal area.
		float dist = distance(world_position, player_reveal_position);
		float alpha_factor = smoothstep(reveal_radius - reveal_softness, reveal_radius, dist);
		float final_alpha = mix(min_alpha * tex_color.a, tex_color.a, alpha_factor);

		COLOR = vec4(tex_color.rgb, final_alpha);
	}
}
