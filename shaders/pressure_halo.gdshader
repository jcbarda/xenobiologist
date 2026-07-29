shader_type canvas_item;
// Contact bloom: a negative radial burned into the pressure layer where a finger
// pressed. Crude by design -- design-doc 8 allows exactly one shader and this is
// it. No distortion, no noise: an inversion and a soft edge.
//
// The inversion is deliberately literal. The player must be able to see that the
// dead area on the glass is the same shape as the mark, or the refused press
// reads as a bug rather than as the device.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

// xy = centre in screen UV, z = radius in UV-y units, w = strength (0 = unused).
uniform vec4 halos[8];
// x = viewport width / height, y = 1.0. Keeps the blooms circular.
uniform vec2 aspect = vec2(1.0, 1.0);

void fragment() {
	vec3 base = texture(screen_tex, SCREEN_UV).rgb;

	float bloom = 0.0;
	// Constant bound: GLSL ES 2.0 on the web target will not take a dynamic one.
	// Unused slots carry w = 0 and contribute nothing.
	for (int i = 0; i < 8; i++) {
		vec4 halo = halos[i];
		float d = length((SCREEN_UV - halo.xy) * aspect);
		// Solid through the middle, softening at the rim, so the dead zone reads
		// as an area rather than an outline.
		float mask = 1.0 - smoothstep(halo.z * 0.72, halo.z, d);
		bloom = max(bloom, mask * halo.w);
	}

	COLOR = vec4(mix(base, vec3(1.0) - base, bloom), 1.0);
}
