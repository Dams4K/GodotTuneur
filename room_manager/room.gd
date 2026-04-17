extends Node3D
class_name Room

@export var room_name: String
@export var mask: Node3D
@export var area: Area3D
@export var close_rooms: Array[String] = []

func _register() -> void:
	RoomManager.register(self)
	hide()

func _ready() -> void:
	assert(not room_name.is_empty(), "Room name missing")
	assert(mask != null, "Room mask missing")
	assert(area != null, "Room area missing")
	
	_register()
	area.body_entered.connect(_on_player_entered)
	area.body_exited.connect(_on_player_exited)

func _on_player_entered(body: Node3D) -> void:
	RoomManager.player_enter(self)

func _on_player_exited(body: Node3D) -> void:
	RoomManager.player_exit(self)

func reveal() -> void:
	mask.show()
	show()

func peek() -> void:
	mask.hide()
	show()
