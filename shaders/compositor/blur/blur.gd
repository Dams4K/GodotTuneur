@tool
extends CompositorEffect
class_name Blur

enum Direction {
	HORIZONTAL,
	VERTICAL
}

@export_range(0, 25, 1, "or_greater") var radius = 2

var rd: RenderingDevice

var shader: RID
var pipeline: RID

var temp: RID
## used to check if the texture have the correct size. If so, there is no need to recreate them
var buffer_size := Vector2i.ZERO

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()
	_load_shaders()


func _load_shaders() -> void:
	if rd == null: return
	
	var file := preload("res://addons/tuneur/shaders/compositor/blur/linear_blur.glsl")
	
	shader  = rd.shader_create_from_spirv(file.get_spirv())
	pipeline  = rd.compute_pipeline_create(shader)

func _ensure_buffers(size: Vector2i) -> void:
	if buffer_size == size and temp.is_valid():
		return # Don't rebuild the txtures when they have the correct size
	
	if temp.is_valid():
		rd.free_rid(temp)
	
	var tf := RDTextureFormat.new()
	tf.width      = size.x
	tf.height     = size.y
	tf.format     = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	tf.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	)
	
	temp = rd.texture_create(tf, RDTextureView.new(), [])
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
		
		_dispatch(color_image, temp, size, Direction.HORIZONTAL, xg, yg)
		_dispatch(temp, color_image, size, Direction.VERTICAL, xg, yg)


func _dispatch(input: RID, output: RID, size: Vector2i, direction: Direction, xg: int, yg: int) -> void:
	var push := PackedByteArray()
	push.resize(16)
	push.encode_float(0, size.x)
	push.encode_float(4, size.y)
	push.encode_s32(8, radius)
	push.encode_s32(12, 0 if direction == Direction.HORIZONTAL else 1)
	
	var uset := UniformSetCacheRD.get_cache(shader, 0, [
		_uniform(input, 0),
		_uniform(output, 1),
	])
	
	var cl := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, pipeline)
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
	if rid.is_valid(): rd.free_rid(rid)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_free_rid(temp)
		_free_rid(shader)
