#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform readonly image2D horizontal_image;
layout(rgba16f, set = 0, binding = 1) uniform readonly image2D vertical_image;
layout(rgba16f, set = 0, binding = 2) uniform writeonly image2D result_image;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	vec2 _pad;
} params;

void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);

	if (uv.x >= size.x || uv.y >= size.y) return;

    float h = imageLoad(horizontal_image,   uv).r;
    float v = imageLoad(vertical_image,     uv).r;

    float val = min(h, v);

    imageStore(result_image, uv, vec4(val, val, val, 1.0));
}