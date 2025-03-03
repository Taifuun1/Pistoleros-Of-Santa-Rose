shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	COLOR = texture(TEXTURE, UV) * vec4(COLOR.r, COLOR.g, COLOR.b, 0.1);

	//clamp(TIME, 1.0, 0.1)
	//COLOR.a = smoothstep(0.0, 0.5, TIME);
	// Called for every pixel the material is visible on.
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
