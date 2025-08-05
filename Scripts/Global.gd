extends Node

var ConnectionHandler : MultiplayerConnectionHandler
var GameInstance : Game
var StateMachine : MultiStateMachine
var Coms : CommunicationLineSystem
var communication_line : CommunicationLine

enum State {
	InLobby,
	Loading,
	InGame,
	MainMenu,

	NumberOfStates
}

var LoadingScreen
var LobbyOutputActivation : MultiStateMachine.StateAction
var CurrentlyInGame : MultiStateMachine.StateAction

func _ready():
	var args = OS.get_cmdline_args()
	print("Command-line arguments:", args)
		
	var initialize_response: Dictionary = Steam.steamInitEx(3653700)
	print("Steam initialization result: %s " % initialize_response)
	
	Coms = CommunicationLineSystem.new()
	CommunicationLineSystem.set_global_communication_line_system(Coms)
	add_child(Coms)
	StateMachine = MultiStateMachine.new()
	StateMachine.Initialize(State.NumberOfStates)
	StateMachine.ResetStates([State.InLobby])
	
	communication_line = Coms.grab_communication_line(get_path().get_concatenated_names())
	communication_line.add_function_definition(
		&"loading_finished",
		loading_finished,
		[CommunicationLine.None],
		CommunicationLine.None,
		MultiplayerPeer.TRANSFER_MODE_RELIABLE
	)
	communication_line.finish_initialization_and_open_line()

	LobbyOutputActivation = StateMachine.AddStatesAction(self,
		[], [], [State.InLobby, State.Loading],
		activate_all_lobby_voip,
		deactivate_all_lobby_voip,
		false)

	CurrentlyInGame = StateMachine.AddStatesAction(self,
		[State.InGame], [State.Loading], [],
		func(): print("INGAME!"),
		func(): print("NOT INGAME!"),
		false)

	LoadingScreen = load("res://Scenes/loading_screen.tscn").instantiate()
	add_child(LoadingScreen)
	ConnectionHandler = MultiplayerConnectionHandler.new()
	add_child(ConnectionHandler)
	ConnectionHandler.NewConnectionEstablishedAndInitialized.connect(on_new_connection)
	ConnectionHandler.ConnectionDisconnected.connect(on_connection_dropped)
	ConnectionHandler.DisconnectedFromServer.connect(on_disconnected_from_server)
	process_mode = Node.PROCESS_MODE_ALWAYS

	StateMachine.AddStatesAction(self,
		[State.Loading], [], [],
		ConnectionHandler.refuse_new_connections,
		ConnectionHandler.allow_new_connections,
		false)
	StateMachine.AddStatesAction(self,
		[State.Loading], [], [],
		LoadingScreen.show_loading_screen,
		LoadingScreen.hide_loading_screen,
		false)
	
	await get_tree().create_timer(0.5).timeout

	if "--client" in args:
		DisplayServer.window_set_title("Client")

func activate_all_lobby_voip():
	for multiplayer_id in ConnectionHandler.multiplayer_connections:
		ConnectionHandler.multiplayer_connections[multiplayer_id].get_voip().activate_lobby_output()

func deactivate_all_lobby_voip():
	for multiplayer_id in ConnectionHandler.multiplayer_connections:
		ConnectionHandler.multiplayer_connections[multiplayer_id].get_voip().deactivate_lobby_output()

func on_new_connection(multiplayer_connection:MultiplayerConnection):
	if LobbyOutputActivation.CurrentlyActive:
		multiplayer_connection.get_voip().activate_lobby_output()
	if CurrentlyInGame.CurrentlyActive and Coms.is_server():
		# we are already in game, this has to be a late joiner!
		# let's get them ready, first, load the level
		var async_process_signal : SignalHolder = multiplayer_connection\
			.run_async_process("res://Resources/start_network_test.tres")
		await async_process_signal.AwaitSignal()
		# then sync all the already spawned things and spawn the new player
		GameInstance.player_connected(multiplayer_connection)
		# and finally set the state of the new player correctly
		communication_line.call_function_on_peer(&"loading_finished", [], multiplayer_connection.multiplayer_id)

func on_connection_dropped(multiplayer_connection:MultiplayerConnection):
	if CurrentlyInGame.CurrentlyActive and Coms.is_server():
		GameInstance.player_disconnected(multiplayer_connection)

# handling of the F11 key to show the CompositeNode info window.
# can also be moved to a different place, maybe a debugging autoload,
# that can be disabled in non-debugging builds...
var f11_down : bool = false
var composite_debugger_window : Window
func _process(_delta: float) -> void:
	Steam.run_callbacks()
	var f11_down_now : bool = Input.is_key_pressed(KEY_F11)
	if not f11_down and f11_down_now:
		if composite_debugger_window:
			composite_debugger_window.queue_free()
			composite_debugger_window = null
		else:
			composite_debugger_window = load("res://DebuggingTools/CompositeNodeDebugger.tscn").instantiate()
			get_tree().root.add_child(composite_debugger_window)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			composite_debugger_window.show()
			composite_debugger_window.close_requested.connect(func():
				composite_debugger_window.queue_free()
				composite_debugger_window = null)
	f11_down = f11_down_now

func on_disconnected_from_server():
	if not StateMachine.IsStateSet(State.InLobby):
		StateMachine.ResetStates([State.InLobby])
		get_tree().change_scene_to_file("res://Lobby/StartScreen.tscn")
	ConnectionHandler.close_game()


func server_start_game_procedure():
	var start_game_processes : Array[SignalHolder]
	for multiplayer_id in ConnectionHandler.multiplayer_connections:
		var async_process_signal : SignalHolder = ConnectionHandler.multiplayer_connections[multiplayer_id]\
			.run_async_process("res://Resources/start_network_test.tres")
		start_game_processes.append(async_process_signal)

	# TODO: if a connection drops while loading, this will never finish!
	for signal_holder in start_game_processes:
		await signal_holder.AwaitSignal()

	# this will spawn the players and the cruiser on all clients:
	GameInstance.start_game()
	# this will resume the game and hide the loading screen:
	await get_tree().create_timer(2).timeout
	communication_line.call_function_on_peers(&"loading_finished", [CommunicationLine.None])
	loading_finished(999)

func loading_finished(_sender_id: int):
	await get_tree().create_timer(0.25).timeout
	StateMachine.SetUnsetStates([State.InGame], [State.Loading])
	get_tree().paused = false

	var local_connection := Global.ConnectionHandler.get_my_connection()
	local_connection.communication_line.call_function_on_peers(&"set_state", [MultiplayerConnection.States.InGame])
	local_connection.set_state(999, MultiplayerConnection.States.InGame)

func await_composite_node_by_id(compositeID:int) -> CompositeNode:
	var composite_node := CompositeNode.GetCompositeNodeByID(compositeID)
	while not composite_node:
		await get_tree().process_frame
		composite_node = CompositeNode.GetCompositeNodeByID(compositeID)
	return composite_node
