extends Node

class_name MultiplayerConnection

var multiplayer_id : int
var connected : bool = true
var authority_initialized_locally : bool = false
var authority_initialized_remotely : Array
var communication_line : CommunicationLine

var _state : int
enum States {
	Loading,
	InitializingGame,
	Waiting,
	InGame
}
func _ready() -> void:
	communication_line = CommunicationLineSystem.get_global_communication_line_system().grab_communication_line(get_path().get_concatenated_names())
	communication_line.add_function_definition(
		&"set_state",
		set_state,
		[CommunicationLine.U32],
		CommunicationLine.None,
		MultiplayerPeer.TRANSFER_MODE_RELIABLE
	)
	
	communication_line.add_function_definition(
		&"async_process_remote",
		async_process_remote,
		[CommunicationLine.StringType, CommunicationLine.S32],
		CommunicationLine.None,
		MultiplayerPeer.TRANSFER_MODE_RELIABLE
	)
	
	communication_line.add_function_definition(
		&"async_process_done",
		async_process_done,
		[CommunicationLine.S32],
		CommunicationLine.None,
		MultiplayerPeer.TRANSFER_MODE_RELIABLE
	)
	communication_line.finish_initialization_and_open_line();

func init_connection(player_id:int):
	multiplayer_id = player_id
	
	if player_id == communication_line.get_local_multiplayer_id():
		communication_line.set_local_peer_bits(1) #If the player id is our local muliplayer id we will give it authority

func set_voip_peer_id(id:int):
	$Voip._voip_peer_id = id


func get_voip() -> PlayerVoip:
	return $Voip


func set_state(_sender_id:int, new_state:States):
	_state = new_state

#################### Async Processes #####################
var next_process_id : int = 1
signal _async_process_done_signal(process_id:int)
func run_async_process(resource_path:String) -> SignalHolder:
	
	var trigger_signal : SignalHolder = SignalHolder.new()
	if communication_line.get_local_peer_bits() == 1: #We are the authority so we can call async_process_remote locally
		async_process_remote(-1, resource_path, next_process_id)
	else:
		communication_line.call_function_on_peers(&"async_process_remote", [resource_path, next_process_id], 1) #Function will only be called on authority
	await_async_answer(next_process_id, trigger_signal)
	next_process_id += 1
	return trigger_signal

func await_async_answer(process_id:int, trigger_signal:SignalHolder):
	while true:
		var _done_process_id = await _async_process_done_signal
		if _done_process_id == process_id:
			trigger_signal.TriggerSignal()
			return

func async_process_remote(_sender_id: int, resource_path:String, process_id:int):
	var async_process = load(resource_path)
	await async_process.RunProcess()
	#async_process_done.rpc_id(1, process_id)
	if communication_line.is_server():
		async_process_done(-1, process_id) #We are the server so we can call async_process_done locally
	else:
		communication_line.call_function_on_peer(&"async_process_done", [process_id], 1) #We are the client so we need to notify the server that we are finished

func async_process_done(_sender_id: int, process_id:int):
	_async_process_done_signal.emit(process_id)
