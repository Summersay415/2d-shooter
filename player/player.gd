class_name Player
extends CharacterBody2D


signal health_changed(old_value: int, new_value: int)
signal killed(who: int, by: int)
signal died(who: int)
signal weapon_changed(type: ItemsDB.Item)
signal ammo_text_updated(text: String)
@export var SPEED := 640.0
# Sync on start
var player := 1:
	set(id):
		player = id
		$PlayerInput.set_multiplayer_authority(id)
var team := 0
var player_name := "Колобок"
var weapons_data: Array
# State variables
var can_control := true
var current_health := 100
var max_health := 100
var speed_multiplier := 1.0
var weapon_locked := false
var _going_to_die := false
var _current_weapon: Weapon
# VFX
var _hurt_vfx: PackedScene = preload("uid://bp6v2plelkof8")
var _death_vfx: PackedScene = preload("uid://ctqgs3w1llfuf")
@onready var remote_transform: RemoteTransform2D = $RemoteTransform
@onready var player_input: PlayerInput = $PlayerInput
@onready var _visual: Node2D = $Visual
@onready var _blood: GPUParticles2D = $Blood
@onready var _weapon_timer: Timer = $WeaponTimer
@onready var _weapons: Node2D = $Visual/Weapons
@onready var _vfx_parent: Node2D = get_tree().get_first_node_in_group("VFXParent")


func _ready() -> void:
	($Name/Label as Label).text = player_name
	($Name/Label as Label).self_modulate = Game.TEAM_COLORS[team]
	if player == multiplayer.get_unique_id():
		(get_tree().current_scene as Shooter).game.set_local_player(self)
		($ControlIndicator as Node2D).show()
		($ControlIndicator as Node2D).self_modulate = Game.TEAM_COLORS[team]


func _physics_process(_delta: float) -> void:
	velocity = player_input.direction.normalized() * SPEED * speed_multiplier * int(can_control)
	if velocity.x != 0:
		_visual.scale.x = -1 if velocity.x < 0 else 1
	move_and_slide()


@rpc("call_local", "reliable", "authority", 1)
func set_health(health: int) -> void:
	if _going_to_die:
		return
	if health == current_health:
		return
	if health <= 0:
		died.emit(player)
		if multiplayer.is_server():
			queue_free()
		_going_to_die = true
		var death_vfx: Node2D = _death_vfx.instantiate()
		death_vfx.position = position
		_vfx_parent.add_child(death_vfx)
		return
	health_changed.emit(current_health, health)
	if health < current_health:
		var hurt_vfx: Node2D = _hurt_vfx.instantiate()
		hurt_vfx.position = position
		_vfx_parent.add_child(hurt_vfx)
	else:
		pass
	current_health = health
	if current_health < max_health * 0.33:
		_blood.emitting = true
	else:
		_blood.emitting = false
	if current_health > max_health:
		max_health = current_health


func damage(amount: int, by: int) -> void:
	if not multiplayer.is_server():
		return
	var new_health := clampi(current_health - amount, 0, max_health)
	if new_health <= 0:
		killed.emit(player, by)
	set_health.rpc(new_health)


func heal(amount: int) -> void:
	if not multiplayer.is_server():
		return
	var new_health := clampi(current_health + amount, 0, max_health)
	set_health.rpc(new_health)
