## A section of the map
## 
## Each Room registers itself with [method RoomManager.register] on [code]_ready[/code] and listens to its [member area]
## to notify [RoomManager] when the player enters or exits.[br]
## [br]
## Visibility is controlled exclusively through [method reveal] and [method peek] —
## never call [code]show()[/code] / [code]hide()[/code] directly on a Room.
##
## [codeblock]
## # In the scene tree, assign exports in the Inspector:
## # room_name  → "Kitchen"
## # mask       → MeshInstance3D (the room's mask geometry)
## # area       → Area3D (collision shape covering the room floor)
## # close_rooms → ["Hall", "Pantry"]
## [/codeblock]
## But everything is set up automatically when importing a model with [code]res://addons/tuneur/importer/tuneur_scene_post_import.gd[/code] as the post import script
extends Node3D
class_name Room

## Unique identifier used by [RoomManager] to look up this room.
## Must be non-empty and match any references in [member close_rooms] of other rooms.
@export var room_name: StringName

@export var instance: MeshInstance3D

## The 3D node whose visibility drives the mask shader.
## Shown by [method reveal], hidden by [method peek].
@export var mask: Node3D

## The trigger volume that detects player entry and exit.
## Must contain at least one [CollisionShape3D].
@export var boundaries: Area3D

## Names of directly adjacent rooms whose meshes should be visible through doorways.
## Each name must match the [member room_name] of a registered [Room].
@export var close_rooms: Array[StringName] = []

## Registers this room with [RoomManager] and hides it until the player enters.
func _register() -> void:
	if Engine.is_editor_hint(): return
	RoomManager.current().register(self)
	dissimulate()


func _ready() -> void:
	assert(not room_name.is_empty(), "Room name missing")
	assert(instance != null, "Room instance is missing")
	assert(mask != null, "Room mask missing for %s" % self)
	assert(boundaries != null, "Room boundaries missing")
	
	_register()
	boundaries.body_entered.connect(_on_player_entered)
	boundaries.body_exited.connect(_on_player_exited)


## Shows both the room geometry and its [member mask], making this room
## fully visible with the mask shader active.[br]
## Called by [RoomManager] when this room becomes the current room.
func reveal() -> void:
	mask.show()
	show_instance()

func dissimulate() -> void:
	hide_instance()
	mask.hide()

func hide_instance() -> void:
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

func show_instance() -> void:
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED

## Shows the room geometry but hides the [member mask], allowing meshes to
## render through doorways without activating the mask shader.[br]
## Called by [RoomManager] for rooms adjacent to the current room.
func peek() -> void:
	mask.hide()
	show_instance()

func _on_player_entered(body: Node3D) -> void:
	RoomManager.current().player_enter(self)

func _on_player_exited(body: Node3D) -> void:
	RoomManager.current().player_exit(self)
