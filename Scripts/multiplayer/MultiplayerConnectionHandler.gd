extends Node

class_name MultiplayerConnectionHandler

var multiplayer_connection_spawner : Node
@onready
var multiplayer_connection_scene : PackedScene = load("res://Scenes/multiplayer/multiplayer_connection.tscn")

var multiplayer_connections : Dictionary
var refuse_connection : bool = false
var voip_connection : VoIPConnection
var voip_multiplayer_peer_id : int

signal ConnectFailed
signal NewConnectionEstablishedAndInitialized(MultiplayerConnection)
signal ConnectionDisconnected(MultiplayerConnection)
signal DisconnectedFromServer

func _ready():
	multiplayer_connection_spawner = load("res://Scenes/multiplayer/MultiplayerConnectionSpawner.tscn").instantiate()
	add_child(multiplayer_connection_spawner)
	
	voip_connection = VoIPConnection.new()
	add_child(voip_connection)
	
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func refuse_new_connections():
	refuse_connection = true


func allow_new_connections():
	refuse_connection = false


func join_game(peer:MultiplayerPeer, voip_peer:MultiplayerPeer):
	multiplayer.multiplayer_peer = peer
	voip_connection.initialize(voip_peer)
	voip_multiplayer_peer_id = voip_peer.get_unique_id()
	return true


func create_game(peer:MultiplayerPeer, voip_peer:MultiplayerPeer):
	multiplayer.multiplayer_peer = peer
	voip_connection.initialize(voip_peer)
	voip_multiplayer_peer_id = voip_peer.get_unique_id()
	_on_player_connected(1)
	return true


func close_game():
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	for c in multiplayer_connection_spawner.get_children():
		c.queue_free()
	multiplayer_connections.clear()


func get_my_connection() -> MultiplayerConnection:
	var my_id := multiplayer.get_unique_id()
	for connection_id in multiplayer_connections:
		if connection_id == my_id:
			return multiplayer_connections[connection_id]
	return null


# will be called by the local MultiplayerConnection, when its init_authority was rpc called
func multiplayer_connection_initialized(multiplayer_connection:MultiplayerConnection):
	multiplayer_connections[multiplayer_connection.multiplayer_id] = multiplayer_connection
	NewConnectionEstablishedAndInitialized.emit(multiplayer_connection)


func _on_player_connected(newly_connected_id):
	if multiplayer.is_server():
		if refuse_connection:
			multiplayer.multiplayer_peer.disconnect_peer(newly_connected_id)
			return
		# first we'll set the authority on every pre-existing multiplayer connection
		# on this newly connected player
		for preexisting_id in multiplayer_connections:
			multiplayer_connections[preexisting_id].rpc_id.call_deferred(newly_connected_id, "init_authority", preexisting_id)
		
		# then we'll create a new connection for this player and call the inity_authority
		# for everyone.
		var multiplayer_connection = multiplayer_connection_scene.instantiate()
		multiplayer_connection_spawner.add_child(multiplayer_connection, true)
		# init_authority should in turn call multiplayer_connection_initialized on every peer
		multiplayer_connection.rpc.call_deferred("init_authority", newly_connected_id)
	
	if newly_connected_id != multiplayer.get_unique_id():
		# every peer should tell the new peer its voip_id!
		set_voip_peer_id_rpc.rpc_id(newly_connected_id, voip_multiplayer_peer_id)
	else:
		# tell all other already connected peers my own voip id
		set_voip_peer_id_rpc.rpc(voip_multiplayer_peer_id)

@rpc("any_peer", "call_remote", "reliable")
func set_voip_peer_id_rpc(id:int):
	var sender_id := multiplayer.get_remote_sender_id()
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
	multiplayer.multiplayer_peer = null
	ConnectFailed.emit()


func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	for connection_id in multiplayer_connections:
		if is_instance_valid(multiplayer_connections[connection_id]):
			multiplayer_connections[connection_id].queue_free()
	multiplayer_connections.clear()
	DisconnectedFromServer.emit()
