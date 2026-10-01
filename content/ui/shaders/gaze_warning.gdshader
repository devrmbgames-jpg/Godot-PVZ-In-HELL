shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform bool reduced_motion = true;

void fragment() {
	vec2 uv = SCREEN_UV;
	if (!reduced_motion) {
		uv.x += sin(uv.y * 18.0 + TIME * 2.0) * 0.002 * strength;
	}
	vec3 scene = texture(screen_texture, uv).rgb;
	float edge = smoothstep(0.15, 0.7, length(SCREEN_UV - vec2(0.5)));
	vec3 warning_tint = vec3(0.12, 0.015, 0.02);
	COLOR = vec4(mix(scene, warning_tint, edge * 0.2 * strength), 1.0);
}
