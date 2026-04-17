#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform readonly image2D input_image;
layout(rgba16f, set = 0, binding = 1) uniform writeonly image2D output_image;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	int radius;
	int dir; // 0 horizontal, 1 vertical
} params;

void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);
	if (uv.x >= size.x || uv.y >= size.y) return;

	int radius = params.radius;
	ivec2 direction = ivec2(1 - params.dir, params.dir);

    vec4 sum = vec4(0.0);
	for (int i = -radius; i <= radius; i++) {
		ivec2 sample_uv = clamp(uv + i * direction, ivec2(0), size-1);
        sum += imageLoad(input_image, sample_uv);
    }
    sum /= radius*2.0 + 1.0;

    imageStore(output_image, uv, sum);
}