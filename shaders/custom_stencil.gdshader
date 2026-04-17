shader_type canvas_item;

uniform sampler2D mask_texture;
uniform float transparency = 1.0;

void vertex() {
}

void fragment() {
	vec4 mask = texture(mask_texture, UV);
	
	COLOR.a = 1.0 - mask.r * transparency;
}
