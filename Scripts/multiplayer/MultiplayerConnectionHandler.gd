extends Node

class_name MultiplayerConnectionHandler

#var multiplayer_connection_spawner : Node
@onready
var multiplayer_connection_scene : PackedScene = load("res://Scenes/multiplayer/multiplayer_connection.tscn")

var multiplayer_connections : Dictionary
var peer_states : Dictionary
var refuse_connection : bool = false
var voip_connection : VoIPConnection
var voip_multiplayer_peer_id : int
var communication_line : CommunicationLine

signal ConnectFailed
signal NewConnectionEstablishedAndInitialized(MultiplayerConnection)
signal ConnectionDisconnected(MultiplayerConnection)
signal DisconnectedFromServer

func _ready():
	#multiplayer_connection_spawner = load("res://Scenes/multiplayer/MultiplayerConnectionSpawner.tscn").instantiate()
	#add_child(multiplayer_connection_spawner)
	
	voip_connection = VoIPConnection.new()
	add_child(voip_connection)
	
	CommunicationLineSystem.get_global_communication_line_system().peer_connected.connect(_on_player_connected)
	CommunicationLineSystem.get_global_communication_line_system().peer_disconnected.connect(_on_player_disconnected)
	CommunicationLineSystem.get_global_communication_line_system().connection_failed.connect(_on_connected_fail)
	CommunicationLineSystem.get_global_communication_line_system().server_disconnected.connect(_on_server_disconnected)
	
	communication_line = CommunicationLineSystem.get_global_communication_line_system().grab_communication_line(get_path().get_concatenated_names())

	communication_line.add_function_definition(
		&"create_new_multiplayer_connection",
		create_new_multiplayer_connection,
		[CommunicationLine.U32],
		CommunicationLine.None,
		MultiplayerPeer.TRANSFER_MODE_RELIABLE
	)
	
	communication_line.add_function_definition(
		&"set_voip_peer_id",
		set_voip_peer_id,
		[CommunicationLine.U32],
		CommunicationLine.None,
		MultiplayerPeer.TRANSFER_MODE_RELIABLE
	)
	
	communication_line.finish_initialization_and_open_line();
	communication_line.PeerCommunicationStateChanged.connect(_on_peer_state_change)

func refuse_new_connections():
	refuse_connection = true


func allow_new_connections():
	refuse_connection = false


func join_game(peer:MultiplayerPeer, voip_peer:MultiplayerPeer):
	CommunicationLineSystem.get_global_communication_line_system().initialize(peer)
	voip_connection.initialize(voip_peer)
	voip_multiplayer_peer_id = voip_peer.get_unique_id()
	return true


func create_game(peer:MultiplayerPeer, voip_peer:MultiplayerPeer):
	CommunicationLineSystem.get_global_communication_line_system().initialize(peer)
	voip_connection.initialize(voip_peer)
	voip_multiplayer_peer_id = voip_peer.get_unique_id()
	_on_player_connected(1)
	return true


func close_game():
	if communication_line.get_multiplayer_peer():
		communication_line.get_multiplayer_peer().close()
	for c in get_children():
		if c is MultiplayerConnection:
			c.queue_free()
	multiplayer_connections.clear()


func get_my_connection() -> MultiplayerConnection:
	var my_id := communication_line.get_local_multiplayer_id()
	for connection_id in multiplayer_connections:
		if connection_id == my_id:
			return multiplayer_connections[connection_id]
	return null

func _on_player_connected(newly_connected_id):
	#We only need to wait for the peer if its not ourself
	if newly_connected_id !=  communication_line.get_local_multiplayer_id():
		peer_states[newly_connected_id] = communication_line.get_peer_state(newly_connected_id)
		
		while peer_states[newly_connected_id] != 3: #Check if Peer Communication State is ConnectedOpen:3
			await get_tree().process_frame
	
	if communication_line.is_server():
		if refuse_connection:
			communication_line.get_multiplayer_peer().disconnect_peer(newly_connected_id)
			return
		
		for connection in multiplayer_connections: #We need to create the existing connections on the client
			communication_line.call_function_on_peer(&"create_new_multiplayer_connection", [connection], newly_connected_id)
		
		create_new_multiplayer_connection(999, newly_connected_id)
		communication_line.call_function_on_peers(&"create_new_multiplayer_connection", [newly_connected_id])
	
	if newly_connected_id != communication_line.get_local_multiplayer_id():
		# every peer should tell the new peer its voip_id!
		communication_line.call_function_on_peer(&"set_voip_peer_id", [voip_multiplayer_peer_id], newly_connected_id)
	else:
		# tell all other already connected peers my own voip id
		communication_line.call_function_on_peers(&"set_voip_peer_id", [voip_multiplayer_peer_id])

func create_new_multiplayer_connection(_sender_id: int, newly_connected_id: int):
	var multiplayer_connection = multiplayer_connection_scene.instantiate()
	add_child(multiplayer_connection)
	multiplayer_connection.init_connection(newly_connected_id)
	multiplayer_connections[multiplayer_connection.multiplayer_id] = multiplayer_connection
	NewConnectionEstablishedAndInitialized.emit(multiplayer_connection)
	communication_line = CommunicationLineSystem.get_global_communication_line_system().grab_communication_line(get_path().get_concatenated_names())

func set_voip_peer_id(sender_id: int, id:int):
	#var sender_id := CommunicationLineSystem.get_global_communication_line_system().get_remote_sender_id()
	# the outer for loop with the await at the end is neccessary, because
	# it is highly likely that the connection is not yet initialized
	for _x in 10:
		for peer_id in multiplayer_connections:
			if peer_id == sender_id:
				multiplayer_connections[peer_id].set_voip_peer_id(id)
				return
		await get_tree().create_timer(1).timeout

func _on_player_disconnected(id):
	if id in multiplayer_connections:
		var disconnected_connection = multiplayer_connections[id]
		multiplayer_connections.erase(id)
		ConnectionDisconnected.emit(disconnected_connection)


func _on_connected_fail():
	CommunicationLineSystem.get_global_communication_line_system().clear()
	ConnectFailed.emit()


func _on_server_disconnected():
	CommunicationLineSystem.get_global_communication_line_system().clear()
	for connection_id in multiplayer_connections:
		if is_instance_valid(multiplayer_connections[connection_id]):
			multiplayer_connections[connection_id].queue_free()
	multiplayer_connections.clear()
	DisconnectedFromServer.emit()

func _on_peer_state_change(peer_multiplayer_id: int, new_state: int):
	peer_states[peer_multiplayer_id] = new_state
