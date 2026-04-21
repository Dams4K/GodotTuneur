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
	MASK,
	BOUNDARIES
}

## Get tuneur metadata
func _get_tuneur(node: Node) -> Dictionary:
	var tuneur: Dictionary = node.get_meta(V_EXTRAS, {}).get(TU_METADATA_NAME, {})
	return tuneur

func iterate_node(node: Node):
	var tuneur_data: Dictionary = _get_tuneur(node)
	var type: int = tuneur_data.get(TU_TYPE, {}).get(TU_TYPE, 0)
	if type == ObjectType.BOUNDARIES: return
	super.iterate_node(node)

## Custom iterate node collisions.[br]
## If the node is a room, the node should be handled differently. Else fall back to the default iterate
func iterate_node_collisions(node3d: Node3D, goblend_data: Dictionary) -> void:
	var tuneur_data: Dictionary = _get_tuneur(node3d)
	if tuneur_data.is_empty(): return super.iterate_node_collisions(node3d, goblend_data)
	
	var type: int = tuneur_data.get(TU_TYPE, {}).get(TU_TYPE, 0)
	if type == ObjectType.BOUNDARIES: return
	if type != ObjectType.ROOM: return super.iterate_node_collisions(node3d, goblend_data)
	
	if not node3d is MeshInstance3D: return super.iterate_node_collisions(node3d, goblend_data)
	var instance := node3d as MeshInstance3D
	super.iterate_node_collisions(instance, goblend_data)
	
	create_room(instance, goblend_data, tuneur_data)

func blender_name_to_godot(name: String) -> String:
	return name \
		.replace(".", "_") \
		.replace(":", "_") \
		.replace("@", "_") \
		.replace("/", "_") \
		.replace('"', "_") \
		.replace("%", "_")

## Create room node, and set it up.
func create_room(instance: MeshInstance3D, goblend_data: Dictionary, tuneur_data: Dictionary) -> void:
	var collisions: Array = goblend_data.get(V_LIST, [])
	var node_name: String = instance.name
	
	# Create room object
	var room := Room.new()
	room.name = "{0}Room".format([node_name])
	room.room_name = node_name # Name used by other rooms for "close rooms"
	room.instance = instance
	
	var close_rooms: Array = tuneur_data.get(TU_CLOSE_ROOMS, {}).get(V_LIST, [])
	for close_room: Dictionary in close_rooms:
		var close_room_name: String = close_room.get(TU_CLOSE_ROOMS_TARGET, {}).get(TU_CLOSE_ROOMS_TARGET_NAME, "")
		if close_room_name.is_empty(): continue
		room.close_rooms.append(blender_name_to_godot(close_room_name))
	
	_replace_root_node(room, instance)
	
	_link_boudaries_to_room(instance, room)
	_link_mask_to_room(instance, room)


## Link the room's area
func _link_boudaries_to_room(instance: MeshInstance3D, room: Room) -> void:
	for child in instance.get_children():
		if not child is MeshInstance3D: continue
		var boundaries_instance: MeshInstance3D = child
		
		var boundaries_tuneur_data := _get_tuneur(boundaries_instance)
		if boundaries_tuneur_data.is_empty(): continue
		
		var child_type: int = boundaries_tuneur_data.get(TU_TYPE, {}).get(TU_TYPE, 0)
		if child_type != ObjectType.BOUNDARIES: continue
		
		super.iterate_node_collisions(boundaries_instance, _get_goblend(boundaries_instance).get("collisions",  {}))
		var _boundaries_areas: Array = boundaries_instance.find_children("*", "Area3D", false, true)
		if _boundaries_areas.is_empty():
			push_error("No boundaries found for %s" % boundaries_instance)
			return
		var boundaries_area = _boundaries_areas[0]
		boundaries_instance.remove_child(boundaries_area)
		boundaries_area.owner = null
		room.add_child(boundaries_area)
		boundaries_area.owner = room.owner
		
		room.boundaries = boundaries_area
		boundaries_area.name = "Boundaries"
		
		boundaries_instance.queue_free()
		break


## Link the room's mask
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
