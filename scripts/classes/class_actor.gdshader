shader_type canvas_item;
render_mode unshaded;

// Runtime cutout rendering only; original PNG alpha/RGB remain untouched.
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.5;
uniform bool cutout_enabled = true;
uniform float hurt_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 hurt_color : source_color = vec4(1.0, 0.76, 0.78, 1.0);
uniform float actor_opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	if (cutout_enabled && texel.a < alpha_cutoff) {
		discard;
	}
	COLOR = vec4(mix(texel.rgb, hurt_color.rgb, hurt_strength), actor_opacity * (cutout_enabled ? 1.0 : texel.a));
}
