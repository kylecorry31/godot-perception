class_name PerceptionComponent
extends Node3D

@export var vision_target_group: String = "target"
@export var sound_target_group: String = "target"
@export var touch_target_group: String = "target"
@export var target_group: String = "target"
@export var sound_detector_group: String = "sound_detector"
@export var vision_distance: float = 10.0
@export var vision_angle: float = 85.0
@export var hearing_distance: float = 25.0
@export var touch_distance: Vector3 = Vector3(1, 1, 1)
@export var sensor_update_frequency: float = 0.25
@export var auto_update_all_targets: bool = true

var vision_targets: Array[Node3D] = []
var touch_targets: Array[Node3D] = []
var targets: Array[Node3D] = []

var _available_vision_targets: Array[Node3D] = []
var _available_touch_targets: Array[Node3D] = []
var _vision_ray_cast: RayCast3D
var _update_timer: Timer

signal target_seen(target)
signal target_seen_lost(target)
signal target_heard(target, location)
signal target_touched(target)
signal target_touched_lost(target)
signal target_added(target)
signal target_lost(target)

func _ready():
	add_to_group(sound_detector_group)
	_vision_ray_cast = RayCast3D.new()
	_vision_ray_cast.target_position = Vector3(0.0, 0.0, -vision_distance)
	_update_timer = Timer.new()
	_update_timer.timeout.connect(update_senses)
	_update_timer.autostart = true
	_update_timer.wait_time = sensor_update_frequency
	add_child(_vision_ray_cast)
	add_child(_update_timer)
	update_all_targets()

func update_all_targets():
	var new_targets = _get_nodes(target_group)
	_emit_change(new_targets, targets, target_added, target_lost)
	targets = new_targets
	
	# Lost vision / touch targets will be reported on the next sensor update
	if vision_target_group == target_group:
		_available_vision_targets = targets
	else:
		_available_vision_targets = _get_nodes(vision_target_group)
	
	if touch_target_group == target_group:
		_available_touch_targets = targets
	else:
		_available_touch_targets = _get_nodes(touch_target_group)

func update_senses():
	if auto_update_all_targets:
		update_all_targets()
	update_vision()
	update_touch()

func update_touch():
	var new_targets: Array[Node3D] = []
	
	for target in _available_touch_targets:
		var distance = abs(target.global_position - global_position)
		if distance.x < touch_distance.x and distance.y < touch_distance.y and distance.z < touch_distance.z:
			new_targets.append(target)
	
	_emit_change(new_targets, touch_targets, target_touched, target_touched_lost)
	touch_targets = new_targets
	

func update_vision():
	var new_targets: Array[Node3D] = []
	
	_vision_ray_cast.target_position.z = -vision_distance
	
	for target in _available_vision_targets:
		var position = target.global_position
		_vision_ray_cast.look_at(target.global_position)
		
		if abs(_vision_ray_cast.rotation_degrees.y) > vision_angle:
			continue

		_vision_ray_cast.force_raycast_update()

		if _vision_ray_cast.is_colliding():
			var collider = _vision_ray_cast.get_collider()
			if collider.get_instance_id() == target.get_instance_id():
				new_targets.append(target)
	
	_emit_change(new_targets, vision_targets, target_seen, target_seen_lost)
	vision_targets = new_targets

func on_sound_detected(location: Vector3, radius: float, originator: Node3D):
	if not originator.is_in_group(sound_target_group):
		return
	
	var distance = global_position.distance_to(location)
	
	if distance <= (hearing_distance + radius):
		target_heard.emit(originator, location)

func _emit_change(new_targets: Array[Node3D], old_targets: Array[Node3D], added: Signal, lost: Signal):
	var old_target_ids = old_targets.map(func(it): return it.get_instance_id())
	var new_target_ids = new_targets.map(func(it): return it.get_instance_id())
	for target in old_targets:
		# if it was in old targets, but not in new targets, it was lost
		if not target.get_instance_id() in new_target_ids:
			lost.emit(target)
	for target in new_targets:
		# if it was not in old targets, but is in new targets, it was found
		if not target.get_instance_id() in old_target_ids:
			added.emit(target)

func _get_nodes(group: String) -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	var all_nodes = get_tree().get_nodes_in_group(group)
	for node in all_nodes:
		if node is Node3D:
			nodes.append(node)
	return nodes
