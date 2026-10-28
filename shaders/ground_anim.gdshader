shader_type spatial;
// Animated tile top (water / lava). `strip` holds `frames` square frames
// side by side; the shader steps through them at `fps`.

uniform sampler2D strip : source_color, filter_nearest_mipmap, repeat_disable;
uniform int frames = 5;
uniform float fps = 5.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float glow = 0.0;

void fragment() {
	float f = mod(floor(TIME * fps), float(frames));
	vec2 uv = vec2((clamp(UV.x, 0.002, 0.998) + f) / float(frames), UV.y);
	vec3 c = texture(strip, uv).rgb * tint;
	ALBEDO = c;
	ROUGHNESS = 0.55;
	EMISSION = c * glow;
}
