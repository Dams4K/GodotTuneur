extends LightmapGI
class_name RoomLightmapGI

func _ready() -> void:
	# Wait for the first frame to be drawn
	# We can assume (I hope, that lightmap gi has finished to do its work, so we can hide the other rooms)
	RenderingServer.frame_post_draw.connect(_on_first_frame, CONNECT_ONE_SHOT)

func _on_first_frame() -> void:
	hide_other_rooms.call_deferred()

func hide_other_rooms():
	for room in RoomManager.current().rooms.values():
		room.dissimulate()
