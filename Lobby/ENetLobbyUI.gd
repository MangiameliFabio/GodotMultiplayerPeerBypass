extends Control

const PORT = 7000
const VOIP_PORT = 7100
const DEFAULT_SERVER_IP = "127.0.0.1" # IPv4 localhost
const MAX_CONNECTIONS = 20

var voip_peer : ENetMultiplayerPeer
var multiplayer_peer : ENetMultiplayerPeer
var communication_line : CommunicationLine
var client_signaling_server : SignalingServer

enum ConnectionType {
	LISTENING,
	CONNECTING
}

var host_buffer: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(0.2).timeout
	Global.ConnectionHandler.NewConnectionEstablishedAndInitialized.connect(_on_player_connected)
	Global.ConnectionHandler.ConnectionDisconnected.connect(_on_player_disconnected)
	Global.ConnectionHandler.ConnectFailed.connect(_on_connect_failed)
	Global.ConnectionHandler.DisconnectedFromServer.connect(_on_connect_failed)
	
	client_signaling_server = SignalingServer.new()
	client_signaling_server.name = "ClientSignalingServer"
	client_signaling_server.peer_connected_to_signaling_server.connect(_on_player_connected_to_signaling_server)
	get_tree().root.add_child(client_signaling_server)
	
	communication_line = CommunicationLineSystem.get_global_communication_line_system().grab_communication_line(get_path().get_concatenated_names())
	communication_line.finish_initialization_and_open_line();
	
func _on_player_connected(connection:MultiplayerConnection):
	if connection.multiplayer_id == communication_line.get_local_multiplayer_id():
		if connection.multiplayer_id == 1:
			%MessageLabel.text = "Server created successfully\n"
			%StartGameButton.disabled = false
	else:
		%MessageLabel.text += "Player connected (id: %s)\n"%connection.multiplayer_id

func _on_player_connected_to_signaling_server(_new_peer : int):
	if not is_visible_in_tree():
		return

	%SignalingServer.text = client_signaling_server.get_connected_peers_as_string()

func _on_player_disconnected(connection:MultiplayerConnection):
	if not is_visible_in_tree():
		return
	%MessageLabel.text += "Player disconnected (id: %s)\n"%connection.multiplayer_id

func _on_start_server_button_pressed():
	%StartServerButton.disabled = true
	%ConnectToServerButton.disabled = true
	%IPAddressLineEdit.editable = false
	
	var signaling_server := SignalingServer.new()
	signaling_server.name = "SignalingServer"
	get_tree().root.add_child(signaling_server)
	var error = signaling_server.start_signaling_server()
	if error:
		%MessageLabel.text = "Could not signaling server!\n"
		return
	
	%MessageLabel.text = "Created signaling server!\n"
	client_signaling_server.connect_to_signaling_server()
	
	while not client_signaling_server.connected_to_server:
		await get_tree().process_frame
	
	CommunicationLineSystem.get_global_communication_line_system().set_mesh_authority(client_signaling_server.signal_server_authority)
	
	var signaling_peer = client_signaling_server.get_own_signal_peer()
	
	multiplayer_peer = ENetMultiplayerPeer.new()
	multiplayer_peer.create_mesh(signaling_peer.mesh_id)
	
	Global.ConnectionHandler.create_game(multiplayer_peer, voip_peer)
	Global.ConnectionHandler._on_player_connected(signaling_peer.mesh_id) #TODO: Dont call on_player_connected from outside
	
	var conn :=  ENetConnection.new()
	error = conn.create_host_bound("*", signaling_peer.port , MAX_CONNECTIONS)
	if error:
		printerr("cant create host: ", error_string(error))
	host_buffer[client_signaling_server.next_mesh_id] = {
		"type": ConnectionType.LISTENING,
		"connection": conn
	}

func _on_connect_to_server_button_pressed():
	%StartServerButton.disabled = true
	%ConnectToServerButton.disabled = true
	%IPAddressLineEdit.editable = false
	
	var address : String = %IPAddressLineEdit.text
	if address.is_empty():
		address = DEFAULT_SERVER_IP
	
	var error = client_signaling_server.connect_to_signaling_server(address)
	if error:
		%MessageLabel.text = "Could not connect to signaling server!\n"
		return
	
	while not client_signaling_server.connected_to_server:
		await get_tree().process_frame
	
	CommunicationLineSystem.get_global_communication_line_system().set_mesh_authority(client_signaling_server.signal_server_authority)
	
	var signaling_peer = client_signaling_server.get_own_signal_peer()
	
	multiplayer_peer = ENetMultiplayerPeer.new()
	multiplayer_peer.create_mesh(signaling_peer.mesh_id)
	
	Global.ConnectionHandler.join_game(multiplayer_peer, voip_peer)
	
	for peer in client_signaling_server.get_list_all_peers():
		if signaling_peer.mesh_id == peer.mesh_id: #This is our own peer we dont need to connect!
			continue
		_connect_to_host(peer.address, peer.port, peer.mesh_id)
	
	var conn :=  ENetConnection.new()
	error = conn.create_host_bound("*", signaling_peer.port , MAX_CONNECTIONS)
	if error:
		printerr("cant create host: ", error_string(error))
	host_buffer[client_signaling_server.next_mesh_id] = {
		"type": ConnectionType.LISTENING,
		"connection": conn
	}
	
func _on_connect_failed():
	if not is_visible_in_tree():
		return
	%StartServerButton.disabled = false
	%ConnectToServerButton.disabled = false
	%IPAddressLineEdit.editable = true
	%MessageLabel.text = "Could not join server!\n"

func _on_start_game_button_pressed():
	if communication_line.is_server():
		%StartGameButton.disabled = true
		Global.server_start_game_procedure()

func _connect_to_host(host_ip: String, host_port: int, host_id: int):
	var conn := ENetConnection.new()
	conn.create_host(MAX_CONNECTIONS)
	conn.connect_to_host(host_ip, host_port)
	host_buffer[host_id] = {
		"type": ConnectionType.CONNECTING,
		"connection": conn
	}

func _change_next_host(host_id : int, host: ENetConnection):
	host_buffer[client_signaling_server.next_mesh_id] = {
		"type": ConnectionType.LISTENING,
		"connection": host
	}
	host_buffer.erase(host_id)

func _process(_delta):
	if multiplayer_peer:
		for host_id in host_buffer:
			var host : ENetConnection = host_buffer[host_id]["connection"]
			var event = host.service()
			if event[0] == host.EVENT_CONNECT:
				# Add host peer
				multiplayer_peer.add_mesh_peer(int(host_id), host)
				
				if host_buffer[host_id]["type"] == ConnectionType.CONNECTING:
					host_buffer.erase(host_id)
					continue
					
				_change_next_host(host_id, host)
				
		multiplayer_peer.mesh_poll()
