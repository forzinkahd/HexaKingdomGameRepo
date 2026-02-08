shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 ghost_color : source_color = vec4(0.2, 0.6, 1.0, 0.4);
uniform float emission_strength = 0.3;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	ALBEDO = ghost_color.rgb;
	ALPHA = ghost_color.a;
	
	EMISSION = ghost_color.rgb * emission_strength;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
