extends CompositeNodeModule

@export var LookSpeedH : float = 0.004
@export var LookSpeedV : float = 0.004
@export var AngleCapV : Vector2 = Vector2(-80, 80)

var _current_interaction_mode : CompositeNodeValue
var _forward_dir : CompositeNodeValue
var _movement : CompositeNodeValue
var _navigation : CompositeNodeValue
var _jump_down : CompositeNodeValue
var _sprint_down : CompositeNodeValue
var _crouch_down : CompositeNodeValue
var _pick_up_down : CompositeNodeValue
var _occupy_down : CompositeNodeValue
var _primary_action_down : CompositeNodeValue
var _interact_holding_down : CompositeNodeValue
var _throw_down : CompositeNodeValue
var _zoom_in_down : CompositeNodeValue
var _vehicle_movement : CompositeNodeValue
var _change_observation_target : CompositeNodeValue
var _interacting_with_interactable : CompositeNodeValue
var _interacting_with_composite : CompositeNodeValue

func _ready_composite_node() -> void:
	register_function("ResetForwardDirection", ResetForwardDirection)
	register_callback("CorrectGlobalDirections", CorrectGlobalDirections)

	_navigation = create_non_synchronized_value("NavigationInput", Vector2.ZERO)
	_pick_up_down = create_non_synchronized_value("PickUpInput", false)
	_occupy_down = create_non_synchronized_value("OccupyInput", false)
	_primary_action_down = create_non_synchronized_value("PrimaryActionInput", false)
	_interact_holding_down = create_non_synchronized_value("SecondaryActionInput", false)
	_throw_down = create_non_synchronized_value("ThrowInput", false)
	_zoom_in_down = create_non_synchronized_value("ZoomInput", false)
	_vehicle_movement = create_non_synchronized_value("VehicleInput", Vector2.ZERO)
	_change_observation_target = create_non_synchronized_value("ObservationTargetChanged", 0.0)

	_interacting_with_interactable = create_non_synchronized_value(&"InteractingInteractableID", null)
	_interacting_with_composite = create_non_synchronized_value(&"InteractingCompositeID", null)
	_forward_dir = create_synchronized_value("ForwardDirection", Vector3.FORWARD,
		CompositeNode.DataSynchronizationMode.OnChange,
		CompositeNode.DataSynchronizationType.Vector3Type)
	_movement = create_synchronized_value("MovementInput", Vector2.ZERO,
		CompositeNode.DataSynchronizationMode.OnChange,
		CompositeNode.DataSynchronizationType.Vector2Type)
	_jump_down = create_synchronized_value("JumpInput", false,
		CompositeNode.DataSynchronizationMode.OnChange,
		CompositeNode.DataSynchronizationType.U8)
	_sprint_down = create_synchronized_value("SprintInput", false,
		CompositeNode.DataSynchronizationMode.OnChange,
		CompositeNode.DataSynchronizationType.U8)
	_crouch_down = create_synchronized_value("CrouchInput", false,
		CompositeNode.DataSynchronizationMode.OnChange,
		CompositeNode.DataSynchronizationType.U8)
	_current_interaction_mode = create_synchronized_value("PlayerInteractionMode", E.PlayerInteractionMode.FirstPerson,
		CompositeNode.DataSynchronizationMode.OnChange,
		CompositeNode.DataSynchronizationType.U8)
	_current_interaction_mode.ValueChanged.connect(PlayerInteractionModeChanged)

func CorrectGlobalDirections(with_quaternion:Quaternion):
	_forward_dir.value = with_quaternion * _forward_dir.value

func ResetForwardDirection(new_forward:Vector3):
	_forward_dir.value = new_forward


func PlayerInteractionModeChanged(newMode:E.PlayerInteractionMode):
	if not _composite_node.IsAuthority():
		return

	if newMode != E.PlayerInteractionMode.FirstPerson:
		_movement.value = Vector2.ZERO
		_jump_down.value = false
		_sprint_down.value = false
		_crouch_down.value = false
		_pick_up_down.value = false
		_interact_holding_down.value = false
		_throw_down.value = false

	if newMode == E.PlayerInteractionMode.InMenus:
		_primary_action_down.value = false
		_occupy_down.value = false

	if newMode != E.PlayerInteractionMode.Vehicle:
		_vehicle_movement.value = Vector2.ZERO


func _process(_delta: float) -> void:
	if not _composite_node.IsAuthority():
		return

	# this is a weird godot quirk, but InputEventAction can't be handled in the _input function
	# and doesn't have any corresponding signal in general!
	update_first_person_inputs()
	update_interaction_inputs()
	update_vehicle_inputs()
	update_spectator_inputs()


func update_first_person_inputs():
	if _current_interaction_mode.value != E.PlayerInteractionMode.FirstPerson:
		return
	var new_movement := Vector2(Input.get_axis("strafe_left", "strafe_right"), Input.get_axis("move_backward", "move_forward"))
	var vec_len := new_movement.length_squared()
	if vec_len > 1: new_movement = new_movement.normalized()
	_movement.value = new_movement
	_jump_down.value = Input.is_action_pressed("jump")
	_sprint_down.value = Input.is_action_pressed("sprint")
	_crouch_down.value = Input.is_action_pressed("crouch")

func update_interaction_inputs():
	if _current_interaction_mode.value == E.PlayerInteractionMode.InMenus:
		return

func update_vehicle_inputs():
	if _current_interaction_mode.value != E.PlayerInteractionMode.Vehicle:
		return
		
func update_spectator_inputs():
	if _current_interaction_mode.value != E.PlayerInteractionMode.Incapacitated:
		return

func _input(event: InputEvent):
	if _current_interaction_mode.value != E.PlayerInteractionMode.FirstPerson or \
		Global.StateMachine.IsStateSet(Global.State.MainMenu):
		return
	if not _composite_node.IsAuthority():
		return

	if event is InputEventMouseMotion:
		var f_dir : Vector3 = _forward_dir.value
		if event.relative.x != 0:
			f_dir = Quaternion(Vector3.UP, event.relative.x * -LookSpeedH) * f_dir
		if event.relative.y != 0:
			var degrees_to_horizontal := 90.0 - rad_to_deg(f_dir.angle_to(Vector3.UP))
			var offset_in_degrees = rad_to_deg(event.relative.y * -LookSpeedV)
			if degrees_to_horizontal + offset_in_degrees > AngleCapV.y:
				offset_in_degrees = AngleCapV.y - degrees_to_horizontal
			elif degrees_to_horizontal + offset_in_degrees < AngleCapV.x:
				offset_in_degrees = AngleCapV.x - degrees_to_horizontal
			f_dir = Quaternion(Vector3.DOWN.cross(f_dir).normalized(), deg_to_rad(offset_in_degrees)) * f_dir
		_forward_dir.value = f_dir.normalized()


func select_slot(slot_index : int):
	if _current_interaction_mode.value == E.PlayerInteractionMode.FirstPerson:
		var current_inventory_slot = _composite_node.GetData(&"SelectedInventorySlot")
		if current_inventory_slot != slot_index:
			_composite_node.SetData(&"SelectedInventorySlot", slot_index)
		else:
			_composite_node.SetData(&"SelectedInventorySlot", -1)
	#elif _current_interaction_mode.value == E.PlayerInteractionMode.ChartInteraction:
		#UI.HUD_set_tool_mode(slot_index)
