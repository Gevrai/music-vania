extends CharacterBody3D

@export var speed: float = 6.0
@export var mouse_sensitivity: float = 0.15
@export var controller_sensitivity: float = 120.0
@export var invert_y: bool = false
@export var jump_velocity: float = 4.5
@export var gravity: float = 24.0
@export_range( -89.0, 89.0 ) var max_pitch_deg: float = 89.0

var _velocity: Vector3 = Vector3.ZERO
var _yaw: float = 0.0
var _pitch: float = 0.0

var _camera: Camera3D
var _camera_pivot: Node3D

var _prev_space_pressed: bool = false

func _ready() -> void:
	_find_camera_nodes()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _find_camera_nodes() -> void:
	# Find the first Camera3D in this node's subtree. Prefer a pivot parent for pitch rotation.
	_camera = null
	for c in get_children():
		if c is Camera3D:
			_camera = c
			break
	if _camera == null:
		# recursive search
		var cameras = get_tree().get_nodes_in_group("Camera3D")
		for cam in cameras:
			if cam is Camera3D and is_instance_valid(cam) and cam.is_a_parent_of(self) == false:
				# skip cameras not belonging to this character; fall back to any camera in children
				continue
	if _camera == null:
		# fallback: find any Camera3D in children recursively
		_camera = _find_child_camera(self)
	if _camera:
		var p = _camera.get_parent()
		if p and p is Node3D:
			_camera_pivot = p
		else:
			_camera_pivot = _camera
	else:
		_camera_pivot = self

func _find_child_camera(node: Node) -> Camera3D:
	for child in node.get_children():
		if child is Camera3D:
			return child
		var found = _find_child_camera(child)
		if found:
			return found
	return null

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# toggle mouse capture with right click
			if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_apply_look(Vector2(-event.relative.x, -event.relative.y) * mouse_sensitivity)

func _apply_look(delta: Vector2) -> void:
	# delta.x: horizontal, delta.y: vertical (positive is up because we negated above)
	_yaw += delta.x
	var inv = -1.0 if invert_y else 1.0
	_pitch += delta.y * inv
	_pitch = clamp(_pitch, -max_pitch_deg, max_pitch_deg)
	rotation_degrees.y = _yaw
	if _camera_pivot:
		_camera_pivot.rotation_degrees.x = _pitch

func _physics_process(delta: float) -> void:
	_process_movement(delta)

func _process_look_controller(delta: float) -> void:
	# No-op: controller look removed (mouse-only)
	pass

func _process_movement(delta: float) -> void:
	# Build input vector from keyboard (WASD / arrows) and gamepad left stick
	var input_vec = Input.get_vector("left", "right", "backward", "forward")

	# Add left stick (gamepad) input if connected
	# (gamepad left stick removed) keyboard-only here

	if input_vec.length() > 1.0:
		input_vec = input_vec.normalized()

	var forward = -transform.basis.z
	var right = transform.basis.x
	var direction = (forward * input_vec.y) + (right * input_vec.x)
	direction.y = 0
	if direction.length() > 0:
		direction = direction.normalized() * speed
	else:
		direction = Vector3.ZERO

	_velocity.x = direction.x
	_velocity.z = direction.z

	if not is_on_floor():
		_velocity.y -= gravity * delta
	else:
		_velocity.y = 0.0
		# Jump: check keyboard action or gamepad A
		var space_pressed = Input.is_key_pressed(KEY_SPACE)
		# detect edge (just pressed)
		if space_pressed and not _prev_space_pressed:
			_velocity.y = jump_velocity
		_prev_space_pressed = space_pressed

	# Use CharacterBody3D velocity API: assign, call, then read back
	velocity = _velocity
	move_and_slide()
	_velocity = velocity
