extends Node
class_name SignalingServer

class SignalingServerPeer:
	var mesh_id: int
	var address: String
	var port: int

	func _init(_mesh_id: int = 0, _address: String = "", _port: int = 0) -> void:
		mesh_id = _mesh_id
		address = _address
		port = _port
	
const SIGNALING_SERVER_PORT = 7100
const DEFAULT_SERVER_IP = "127.0.0.1" # IPv4 localhost
const MAX_CONNECTIONS = 20

var CLS : CommunicationLineSystem
var communication_line : CommunicationLine
var multiplayer_peer : ENetMultiplayerPeer

var connected_peers = {}
var current_port : int = 7000
var next_mesh_id : int = 0

var host_buffer = {}

var peer_states : Dictionary

signal peer_connected_to_signaling_server(peer: int)
signal peer_disconected_from_signaling_server(peer: int)

var connected_to_server = false
var signal_server_authority : int = 0

func _ready() -> void:
	CLS = CommunicationLineSystem.new()
	CLS.peer_connected.connect(on_peer_connected)
	add_child(CLS)
	
	communication_line = CLS.grab_communication_line(&"SignalingServer")
	communication_line.add_function_definition(
		&"sync_connected_peers",
		sync_connected_peers,
		[CommunicationLine.S32, CommunicationLine.S32, CommunicationLine.StringType, CommunicationLine.U16],
		CommunicationLine.None,
		MultiplayerPeer.TRANSFER_MODE_RELIABLE
	)
	communication_line.add_function_definition(
		&"sync_next_mesh_id",
		sync_next_mesh_id,
		[CommunicationLine.S32],
		CommunicationLine.None,
		MultiplayerPeer.TRANSFER_MODE_RELIABLE
	)
	communication_line.add_function_definition(
		&"set_peer_connected",
		set_peer_connected,
		[CommunicationLine.U8],
		CommunicationLine.None,
		MultiplayerPeer.TRANSFER_MODE_RELIABLE
	)
	communication_line.add_function_definition(
		&"sync_authority_id",
		sync_authority_id,
		[CommunicationLine.S32],
		CommunicationLine.None,
		MultiplayerPeer.TRANSFER_MODE_RELIABLE
	)
	communication_line.finish_initialization_and_open_line();
	communication_line.PeerCommunicationStateChanged.connect(_on_peer_state_change)

func start_signaling_server() -> Error:
	multiplayer_peer = ENetMultiplayerPeer.new()
	connected_to_server = true
	
	var error = multiplayer_peer.create_server(SIGNALING_SERVER_PORT, MAX_CONNECTIONS)
	if error: return error
		
	CLS.set_multiplayer_peer(multiplayer_peer)
	genereate_next_mesh_id()
	return error

func connect_to_signaling_server(address : String = "") -> Error:
	if address.is_empty():
		address = DEFAULT_SERVER_IP
	
	multiplayer_peer = ENetMultiplayerPeer.new()
	var error = multiplayer_peer.create_client(address, SIGNALING_SERVER_PORT)
	if error: return error
	
	print("Created client and connected to: ", address, ":", SIGNALING_SERVER_PORT)
	CLS.set_multiplayer_peer(multiplayer_peer)
	return error

func on_peer_connected(new_peer_id: int) -> void:
	if not communication_line.is_server(): return
	
	peer_states[new_peer_id] = communication_line.get_peer_state(new_peer_id)
	
	while peer_states[new_peer_id] != 3: #Check if Peer Communication State is ConnectedOpen:3
		await get_tree().process_frame
	
	for id in connected_peers:
		#Sync already connected peers with the newly connected on
		communication_line.call_function_on_peer(&"sync_connected_peers", [id, connected_peers[id].mesh_id, connected_peers[id].address, connected_peers[id].port], new_peer_id)
	
	var _new_peer = add_peer_to_signaling_server(new_peer_id)
	
	if connected_peers.size() == 1: #Our first connection will be the authority, all other clients will try to connect to this client first
		signal_server_authority = new_peer_id
	
	communication_line.call_function_on_peers(&"sync_connected_peers", [new_peer_id, _new_peer.mesh_id, _new_peer.address, _new_peer.port])
	communication_line.call_function_on_peers(&"sync_next_mesh_id", [next_mesh_id])
	communication_line.call_function_on_peers(&"sync_authority_id", [signal_server_authority])

	communication_line.call_function_on_peer(&"set_peer_connected", [true], new_peer_id)
	
	
func add_peer_to_signaling_server(new_peer_id: int) -> SignalingServerPeer:
	if not multiplayer_peer: 
		printerr("Signaling server is using invalid multiplayer peer")
		return
	
	var remote_peer = multiplayer_peer.get_peer(new_peer_id)
	if not remote_peer: return
	
	var new_peer = SignalingServerPeer.new()
	new_peer.mesh_id = next_mesh_id
	new_peer.address = remote_peer.get_remote_address()
	new_peer.port = get_next_port()
	
	genereate_next_mesh_id()
	
	connected_peers[new_peer_id] = new_peer
	print("New peer added to signaling server: ", new_peer_id)
	
	return new_peer

func get_next_port() -> int:
	current_port += 1
	
	return current_port

func genereate_next_mesh_id() -> void:
	if not communication_line.is_server():
		printerr("Only the Server should genereate new mesh ids")
		return
	print("Next mesh id: ", next_mesh_id)
	next_mesh_id = multiplayer_peer.generate_unique_id()
	
	communication_line.call_function_on_peers(&"sync_next_mesh_id", [next_mesh_id])

func sync_connected_peers(_sender_id: int, _peer_id: int, new_mesh_id: int, address: String, port: int):
	if connected_peers.has(_peer_id): 
		printerr("Trying to synch an already connected peer")
	
	var new_peer := SignalingServerPeer.new(new_mesh_id, address, port)
	connected_peers[_peer_id] = new_peer
	
	peer_connected_to_signaling_server.emit(_peer_id)

func sync_next_mesh_id(_sender_id: int, new_mesh_id: int):
	next_mesh_id = new_mesh_id

func sync_authority_id(_sender_id: int, authority_id: int):
	signal_server_authority = authority_id

func set_peer_connected(_sender_id: int, connected: bool):
	connected_to_server = connected

func get_connected_peers_as_string() -> String:
	var string : String = ""
	string += "------ Connected peers on signaling Server -----\n"
	for id in connected_peers:
		string += str(id, "\n")
		string += str(" mesh_id: ", connected_peers[id].mesh_id, "\n")
		string += str(" address: ", connected_peers[id].address, "\n")
		string += str(" port: ", connected_peers[id].port, "\n")
	string += "------------------------------------------------\n"
	
	return string
	
func _on_peer_state_change(peer_multiplayer_id: int, new_state: int):
	peer_states[peer_multiplayer_id] = new_state

func get_signal_peer(peer_id: int) -> SignalingServerPeer:
	if not connected_peers.has(peer_id):
		return null
	return connected_peers[peer_id]

func get_own_signal_peer() -> SignalingServerPeer:
	if not connected_peers.has(multiplayer_peer.get_unique_id()):
		return null
	return connected_peers[multiplayer_peer.get_unique_id()]

func get_list_all_peers() -> Array[SignalingServerPeer]:
	var arr : Array[SignalingServerPeer] = []
	
	for id in connected_peers:
		var peer = SignalingServerPeer.new()
		peer.mesh_id = connected_peers[id].mesh_id
		peer.address = connected_peers[id].address
		peer.port = connected_peers[id].port
		
		arr.append(peer)
	
	return arr
