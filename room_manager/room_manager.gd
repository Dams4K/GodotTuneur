extends Node

const HIDE_ANIMATION := "hide"
const SHOW_ANIMATION := "show"

var previous_room: Room = null
var current_room: Room = null

var rooms: Dictionary[String, Room] = {}

@onready var mask_rect: ColorRect = %MaskRect
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sub_viewport: SubViewport = $SubViewport
@onready var camera_3d: Camera3D = $SubViewport/Camera3D

func _ready() -> void:
	_init_mask_viewport(sub_viewport.get_texture())
	
	get_viewport().size_changed.connect(_on_main_viewport_size_changed)
	_on_main_viewport_size_changed()

func _process(delta: float) -> void:
	_update_mask_camera()

func _update_mask_camera() -> void:
	var current_camera_3d := get_viewport().get_camera_3d()
	if current_camera_3d == null: return
	
	camera_3d.global_position = current_camera_3d.global_position
	camera_3d.size = current_camera_3d.size

func _on_main_viewport_size_changed():
	sub_viewport.size = get_viewport().get_visible_rect().size

func _init_mask_viewport(viewport_texture: ViewportTexture) -> void:
	var shader_material: ShaderMaterial = mask_rect.material
	shader_material.set_shader_parameter("mask_texture", viewport_texture)
	shader_material.set_shader_parameter("transparency", 1.0)

func register(room: Room) -> void:
	assert(not rooms.has(room.room_name), "A room named {0} already exists".format([room.room_name]))
	rooms[room.room_name] = room

func player_enter(room: Room) -> void:
	previous_room = current_room
	current_room = room
	animation_player.play(HIDE_ANIMATION)

func switch_room() -> void:
	if current_room == null: return
	
	if previous_room != null:
		previous_room.hide()
	
	current_room.reveal()
	_peek_close_rooms(current_room)
	
	animation_player.play(SHOW_ANIMATION)

func player_exit(room: Room) -> void:
	if room != current_room: return
	if previous_room == null or previous_room == current_room: return
	player_enter(previous_room)

func _peek_close_rooms(room: Room) -> void:
	for close_room_name: String in room.close_rooms:
		var close_room: Room = rooms.get(close_room_name, null)
		if close_room == null:
			push_error("Room called ", close_room_name, " not found")
			continue
		close_room.peek()
