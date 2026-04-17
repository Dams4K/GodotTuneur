@tool
extends CompositorEffect
class_name GrowBlack

enum Direction {
	HORIZONTAL,
	VERTICAL
}

@export_range(0, 25, 1, "or_greater") var radius = 2

var rd: RenderingDevice

var shader_linear: RID
var shader_combine: RID

var pipeline_linear: RID
var pipeline_combine: RID

## H grow result
var temp_h: RID
## V grow result
var temp_v: RID
## used to check if the texture have the correct size. If so, there is no need to recreate them
var buffer_size := Vector2i.ZERO


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()
	_load_shaders()


func _load_shaders() -> void:
	if rd == null: return
	
	#TODO: check comment faire ça automatiquement
	var file_linear  := preload("res://addons/tuneur/shaders/compositor/grow/grow_black_linear.glsl")
	var file_combine := preload("res://addons/tuneur/shaders/compositor/grow/grow_black_combine.glsl")
	
	shader_linear  = rd.shader_create_from_spirv(file_linear.get_spirv())
	shader_combine = rd.shader_create_from_spirv(file_combine.get_spirv())
	
	pipeline_linear  = rd.compute_pipeline_create(shader_linear)
	pipeline_combine = rd.compute_pipeline_create(shader_combine)


func _ensure_buffers(size: Vector2i) -> void:
	if buffer_size == size and temp_h.is_valid() and temp_v.is_valid():
		return # Don't rebuild the txtures when they have the correct size
	
	for buf: RID in [temp_h, temp_v]:
		if buf.is_valid():
			rd.free_rid(buf)
	
	var tf := RDTextureFormat.new()
	tf.width      = size.x
	tf.height     = size.y
	tf.format     = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	tf.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	)
	
	temp_h = rd.texture_create(tf, RDTextureView.new(), [])
	temp_v = rd.texture_create(tf, RDTextureView.new(), [])
	buffer_size = size


func _render_callback(p_effect_callback_type: int, p_render_data: RenderData) -> void:
	if not rd: return
	if p_effect_callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT: return
	if radius <= 0: return
	
	var render_scene_buffer: RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
	if not render_scene_buffer: return
	
	var size = render_scene_buffer.get_internal_size()
	if size.x == 0 and size.y == 0: return
	
	_ensure_buffers(size)
	
	var xg = (size.x - 1) / 8+1
	var yg = (size.y - 1) / 8+1
	
	for view in range(render_scene_buffer.get_view_count()):
		var color_image: RID = render_scene_buffer.get_color_layer(view)
		
		_dispatch_grow(color_image, temp_h, size, Direction.HORIZONTAL, xg, yg)
		_dispatch_grow(color_image, temp_v, size, Direction.VERTICAL  , xg, yg)
		
		#WARNING: we write directly in the color_image buffer, maybe one day it will not be possible.
		# Then use another buffer and do: rd.texture_copy(...)
		_dispatch_combine(temp_h, temp_v, color_image, size, xg, yg)

func _dispatch_grow(input: RID, output: RID, size: Vector2i, direction: Direction, xg: int, yg: int) -> void:
	var push := PackedByteArray()
	push.resize(16)
	push.encode_float(0, size.x)
	push.encode_float(4, size.y)
	push.encode_s32(8, radius)
	push.encode_s32(12, 0 if direction == Direction.HORIZONTAL else 1)
	
	var uset := UniformSetCacheRD.get_cache(shader_linear, 0, [
		_uniform(input, 0),
		_uniform(output, 1),
	])
	
	var cl := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, pipeline_linear)
	rd.compute_list_bind_uniform_set(cl, uset, 0)
	rd.compute_list_set_push_constant(cl, push, push.size())
	rd.compute_list_dispatch(cl, xg, yg, 1)
	rd.compute_list_end()

func _dispatch_combine(h: RID, v: RID, output: RID, size: Vector2i, xg: int, yg: int) -> void:
	var push_constant := PackedFloat32Array()
	push_constant.push_back(size.x)
	push_constant.push_back(size.y)
	push_constant.push_back(0.0)
	push_constant.push_back(0.0)
	var push := push_constant.to_byte_array()
	
	var uset := UniformSetCacheRD.get_cache(shader_combine, 0, [
		_uniform(h,      0),
		_uniform(v,      1),
		_uniform(output, 2),
	])
	
	var cl := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, pipeline_combine)
	rd.compute_list_bind_uniform_set(cl, uset, 0)
	rd.compute_list_set_push_constant(cl, push, push.size())
	rd.compute_list_dispatch(cl, xg, yg, 1)
	rd.compute_list_end()

func _uniform(rid: RID, binding: int) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(rid)
	return u

func _free_rid(rid: RID) -> void:
	if rid == null: return
	if rid.is_valid(): rd.free_rid(rid)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_free_rid(temp_h)
		_free_rid(temp_v)
		_free_rid(shader_linear)
		_free_rid(shader_combine)
