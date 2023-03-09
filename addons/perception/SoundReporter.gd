class_name SoundReporter

static func report(location: Vector3, radius: float, originator: Node3D, group: String = "sound_detector"):
	originator.get_tree().call_group(group, "on_sound_detected", location, radius, originator)
