extends Node

class_name MultiplayerConnection

var multiplayer_id : int
var connected : bool = true
var authority_initialized_locally : bool = false
var authority_initialized_remotely : Array

var _state : int
enum States {
	Loading,
	InitializingGame,
	Waiting,
	InGame
}

@rpc("authority", "call_local", "reliable")
func init_authority(player_id:int):
	set_multiplayer_authority(player_id)
	multiplayer_id = player_id
	authority_initialized_locally = true
	authority_was_initialized.rpc(multiplayer.get_unique_id())
	Global.ConnectionHandler.multiplayer_connection_initialized(self)


@rpc("any_peer", "call_local", "reliable")
func authority_was_initialized(on_player:int):
	if on_player not in authority_initialized_remotely:
		authority_initialized_remotely.append(on_player)

func set_voip_peer_id(id:int):
	$Voip._voip_peer_id = id


func get_voip() -> PlayerVoip:
	return $Voip

@rpc("authority", "call_local", "reliable")
func set_state(new_state:States):
	_state = new_state

#################### Async Processes #####################
var next_process_id : int = 1
signal _async_process_done_signal(process_id:int)
func run_async_process(resource_path:String) -> SignalHolder:
	var trigger_signal : SignalHolder = SignalHolder.new()
	_run_async_process_remote.rpc_id(get_multiplayer_authority(), resource_path, next_process_id)
	await_async_answer(next_process_id, trigger_signal)
	next_process_id += 1
	return trigger_signal

func await_async_answer(process_id:int, trigger_signal:SignalHolder):
	while true:
		var _done_process_id = await _async_process_done_signal
		if _done_process_id == process_id:
			trigger_signal.TriggerSignal()
			return

@rpc("any_peer", "call_local", "reliable")
func _run_async_process_remote(resource_path:String, process_id:int):
	var async_process = load(resource_path)
	await async_process.RunProcess()
	_async_process_done.rpc_id(1, process_id)

@rpc("any_peer", "call_local", "reliable")
func _async_process_done(process_id:int):
	_async_process_done_signal.emit(process_id)
