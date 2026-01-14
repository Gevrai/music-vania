extends CharacterBody3D

@export var speed: float = 6.0
@export var jump_velocity: float = 10.0 
@export var sprint_multiplier: float = 1.7

@export var gravity: float = 24.0

@export var mouse_sensitivity: float = 0.15
@export_range( -89.0, 89.0 ) var max_pitch_deg: float = 89.0
@export var invert_y: bool = false

@onready var _camera_pivot: Node3D = %CameraPivot

var _yaw: float = 0.0
var _pitch: float = 0.0

func _ready() -> void:
	_yaw = rotation_degrees.y
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

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
	_yaw += delta.x
	_pitch += delta.y * -1.0 if invert_y else 1.0
	_pitch = clamp(_pitch, -max_pitch_deg, max_pitch_deg)
	rotation_degrees.y = _yaw
	_camera_pivot.rotation_degrees.x = _pitch

func _physics_process(delta: float) -> void:
	_process_movement(delta)

func _process_movement(delta: float) -> void:
	var input_vec = Input.get_vector("left", "right", "backward", "forward")
	var forward = -transform.basis.z
	var right = transform.basis.x
	var direction = (forward * input_vec.y) + (right * input_vec.x)
	direction.y = 0
	if direction.length() > 0:
		direction = direction.normalized() * speed
	else:
		direction = Vector3.ZERO

	if Input.is_action_pressed("sprint"):
		direction = direction * sprint_multiplier

	velocity.x = direction.x
	velocity.z = direction.z

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
		# Jump: check keyboard action or gamepad A
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity

	move_and_slide()
