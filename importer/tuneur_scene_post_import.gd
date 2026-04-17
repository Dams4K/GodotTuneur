@tool
extends GoBlendScenePostImport
class_name TuneurPostSceneImport

const TU_METADATA_NAME = "tuneur"

const TU_MASK_DISCRIMINATOR = "-mask"

const TU_TYPE = "type"
const TU_CLOSE_ROOMS = "close_rooms"

const TU_CLOSE_ROOMS_TARGET = "target"
const TU_CLOSE_ROOMS_TARGET_NAME = "name"

enum ObjectType {
	NONE,
	ROOM,
	MASK
}

func _get_tuneur(node: Node) -> Dictionary:
	var tuneur: Dictionary = node.get_meta(V_EXTRAS, {}).get(TU_METADATA_NAME, {})
	return tuneur

func iterate_node_collisions(node3d: Node3D, goblend_data: Dictionary) -> void:
	var tuneur_data: Dictionary = _get_tuneur(node3d)
	if tuneur_data.is_empty(): return super.iterate_node_collisions(node3d, goblend_data)
	
	var type: int = tuneur_data.get(TU_TYPE, {}).get(TU_TYPE, 0)
	if type != ObjectType.ROOM: return super.iterate_node_collisions(node3d, goblend_data)
	
	if not node3d is MeshInstance3D: return super.iterate_node_collisions(node3d, goblend_data)
	var instance := node3d as MeshInstance3D
	
	create_room(instance, goblend_data, tuneur_data)

func create_room(instance: MeshInstance3D, goblend_data: Dictionary, tuneur_data: Dictionary) -> void:
	var collisions: Array = goblend_data.get(V_LIST, [])
	var node_name: String = instance.name
	
	# Create room object
	var room := Room.new()
	room.name = "{0}Room".format([node_name])
	room.room_name = node_name # Name used by other rooms for "close rooms"
	
	var close_rooms: Array = tuneur_data.get(TU_CLOSE_ROOMS, {}).get(V_LIST, [])
	for close_room: Dictionary in close_rooms:
		var close_room_name: String = close_room.get(TU_CLOSE_ROOMS_TARGET, {}).get(TU_CLOSE_ROOMS_TARGET_NAME, "")
		if close_room_name.is_empty(): continue
		room.close_rooms.append(close_room_name)
	
	_replace_root_node(room, instance)
	
	_create_and_link_collision_objects(collisions, room, instance)
	_link_mask_to_room(instance, room)

func _create_and_link_collision_objects(collisions: Array, room: Room, instance: MeshInstance3D) -> void:
	var node_name: String = instance.name
	
	for col_idx in range(collisions.size()):
		var collision_data: Dictionary = collisions[col_idx]
		
		var collision_node := _create_collision_object(collision_data, room, instance.mesh)
		_name_collision(collision_node, collision_data, node_name)
		
		if room.area == null and collision_node is Area3D:
			room.area = collision_node

func _link_mask_to_room(instance: MeshInstance3D, room: Room) -> void:
	for child in instance.get_children():
		if not child is MeshInstance3D: continue
		var mask_instance: MeshInstance3D = child
		
		var mask_tuneur_data := _get_tuneur(mask_instance)
		if mask_tuneur_data.is_empty(): continue
		
		var child_type: int = mask_tuneur_data.get(TU_TYPE, {}).get(TU_TYPE, 0)
		if child_type != ObjectType.MASK: continue
		
		room.mask = mask_instance
		mask_instance.name = "Mask"
		break
