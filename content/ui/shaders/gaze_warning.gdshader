shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform bool reduced_motion = true;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.85;
uniform float injury_strength : hint_range(0.0, 1.0) = 0.0;
uniform float hunger_strength : hint_range(0.0, 1.0) = 0.0;
uniform float status_opacity : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec2 uv = SCREEN_UV;
	if (!reduced_motion) {
		uv.x += sin(uv.y * 18.0 + TIME * 2.0) * 0.002 * strength;
	}
	vec3 scene = texture(screen_texture, uv).rgb;
	float edge = smoothstep(0.15, 0.7, length(SCREEN_UV - vec2(0.5)));
	vec3 hunger_tint = vec3(0.28, 0.17, 0.025);
	vec3 injury_tint = vec3(0.4, 0.025, 0.025);
	vec3 warning_tint = vec3(0.14, 0.015, 0.22);
	vec3 feedback = mix(scene, hunger_tint, edge * status_opacity * hunger_strength);
	feedback = mix(feedback, injury_tint, edge * status_opacity * injury_strength);
	COLOR = vec4(mix(feedback, warning_tint, edge * vignette_opacity * strength), 1.0);
}
