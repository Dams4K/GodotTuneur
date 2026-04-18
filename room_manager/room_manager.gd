## Manages room transitions and room display using a mask-based system.
##
## This node coordinates room visibility, transition animations, and a secondary
## camera that drives the mask shader. Rooms register themselves via [method register],
## and the active room is changed through [method player_enter].[br]
## [br]
## Heavily inspired by the game Tunic.[br]
## [br]
## Typical setup:
## [codeblock]
## room_manager.register(kitchen_room)
## room_manager.register(hall_room)
## room_manager.player_enter(kitchen_room)
## [/codeblock]
extends Node
class_name _RoomManager

## Animation name played when hiding the current room before a transition.
const HIDE_ANIMATION := "hide"
## Animation name played when revealing the next room after a transition.
const SHOW_ANIMATION := "show"

## The room the player was in before the current transition. [code]null[/code] at startup.
var previous_room: Room = null

## The room the player is currently in (or transitioning to).
var current_room: Room = null

## All registered rooms, keyed by [member Room.room_name].
var rooms: Dictionary[StringName, Room] = {}

@onready var _mask_rect: ColorRect = %MaskRect
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _sub_viewport: SubViewport = $SubViewport
@onready var _camera_3d: Camera3D = $SubViewport/Camera3D

func _ready() -> void:
	_init_mask_viewport(_sub_viewport.get_texture())
	
	get_viewport().size_changed.connect(_on_main_viewport_size_changed)
	_on_main_viewport_size_changed()

func _process(delta: float) -> void:
	_update_mask_camera()

## Mirrors the active [Camera3D] into the sub-viewport so the mask shader
## always aligns with the main scene camera.
func _update_mask_camera() -> void:
	var current_camera_3d := get_viewport().get_camera_3d()
	if current_camera_3d == null: return
	
	_camera_3d.global_position = current_camera_3d.global_position
	_camera_3d.size            = current_camera_3d.size
	_camera_3d.h_offset        = current_camera_3d.h_offset
	_camera_3d.v_offset        = current_camera_3d.v_offset

## Resizes the sub-viewport to match the main viewport whenever the window is resized.t
func _on_main_viewport_size_changed():
	_sub_viewport.size = get_viewport().get_visible_rect().size

## Passes the sub-viewport texture to the mask shader and sets initial transparency.
func _init_mask_viewport(viewport_texture: ViewportTexture) -> void:
	var shader_material: ShaderMaterial = _mask_rect.material
	shader_material.set_shader_parameter("mask_texture", viewport_texture)
	shader_material.set_shader_parameter("transparency", 1.0)

## Registers [param room] so it can be referenced by name in transitions.[br]
## Call this from each room's [code]_ready[/code].[br]
## [br]
## Emits an assertion error if a room with the same [member Room.room_name] is
## already registered.
func register(room: Room) -> void:
	assert(not rooms.has(room.room_name), "A room named {0} already exists".format([room.room_name]))
	rooms[room.room_name] = room

## Starts a transition into [param room].[br]
## [br]
## Plays [constant HIDE_ANIMATION]; [method _switch_room] is called automatically
## at the end of that animation to swap visibility and start [constant SHOW_ANIMATION].[br]
## [br]
## Safe to call even if [param room] is already [member current_room].animation
func player_enter(room: Room) -> void:
	previous_room = current_room
	current_room = room
	_animation_player.play(HIDE_ANIMATION)

## Swaps room visibility at the midpoint of the transition animation.[br]
## [br]
## Called by [AnimationPlayer] at the end of [constant HIDE_ANIMATION].
## Hides [member previous_room], reveals [member current_room], peeks at
## adjacent rooms, then plays [constant SHOW_ANIMATION].N].
func _switch_room() -> void:
	if current_room == null: return
	
	if previous_room != null:
		previous_room.hide()
	
	current_room.reveal()
	_peek_close_rooms(current_room)
	
	_animation_player.play(SHOW_ANIMATION)

## Handles the player leaving [param room].[br]
## [br]
## If [param room] is the [member current_room], triggers a transition back to
## [member previous_room]. Does nothing if [param room] is not current, or if
## there is no valid previous room to return to.
func player_exit(room: Room) -> void:
	if room != current_room: return
	if previous_room == null or previous_room == current_room: return
	player_enter(previous_room)

## Makes adjacent rooms visible without showing the mask, allowing
## their meshes to render through doorways.[br]
## [br]
## Logs an error for any room name listed in [member Room.close_rooms] that
## has not been registered.
func _peek_close_rooms(room: Room) -> void:
	for close_room_name: String in room.close_rooms:
		var close_room: Room = rooms.get(close_room_name, null)
		if close_room == null:
			push_error("Room called ", close_room_name, " not found")
			continue
		close_room.peek()
