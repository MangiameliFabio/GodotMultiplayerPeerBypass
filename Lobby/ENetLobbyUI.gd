extends Control

const PORT = 7000
const VOIP_PORT = 7100
const DEFAULT_SERVER_IP = "127.0.0.1" # IPv4 localhost
const MAX_CONNECTIONS = 20

var voip_peer : ENetMultiplayerPeer

# Called when the node enters the scene tree for the first time.
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(0.2).timeout
	Global.ConnectionHandler.NewConnectionEstablishedAndInitialized.connect(_on_player_connected)
	Global.ConnectionHandler.ConnectionDisconnected.connect(_on_player_disconnected)
	Global.ConnectionHandler.ConnectFailed.connect(_on_connect_failed)
	Global.ConnectionHandler.DisconnectedFromServer.connect(_on_connect_failed)

func _on_player_connected(connection:MultiplayerConnection):
	if not is_visible_in_tree():
		return
	if connection.multiplayer_id == multiplayer.get_unique_id():
		if connection.multiplayer_id == 1:
			%MessageLabel.text = "Server created successfully\n"
			%StartGameButton.disabled = false
	else:
		%MessageLabel.text += "Player connected (id: %s)\n"%connection.multiplayer_id

func _on_player_disconnected(connection:MultiplayerConnection):
	if not is_visible_in_tree():
		return
	%MessageLabel.text += "Player disconnected (id: %s)\n"%connection.multiplayer_id

func _on_start_server_button_pressed():
	%StartServerButton.disabled = true
	%ConnectToServerButton.disabled = true
	%IPAddressLineEdit.editable = false
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CONNECTIONS)
	if error:
		%StartServerButton.disabled = false
		%ConnectToServerButton.disabled = false
		%IPAddressLineEdit.editable = true
		%MessageLabel.text = "Could not start server!"
	else:
		voip_peer = ENetMultiplayerPeer.new()
		voip_peer.create_server(VOIP_PORT, MAX_CONNECTIONS)
		Global.ConnectionHandler.create_game(peer, voip_peer)


func _on_connect_to_server_button_pressed():
	%StartServerButton.disabled = true
	%ConnectToServerButton.disabled = true
	%IPAddressLineEdit.editable = false
	var address : String = %IPAddressLineEdit.text
	if address.is_empty():
		address = DEFAULT_SERVER_IP
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error:
		_on_connect_failed()
	else:
		voip_peer = ENetMultiplayerPeer.new()
		voip_peer.create_client(address, VOIP_PORT)
		Global.ConnectionHandler.join_game(peer, voip_peer)


func _on_connect_failed():
	if not is_visible_in_tree():
		return
	%StartServerButton.disabled = false
	%ConnectToServerButton.disabled = false
	%IPAddressLineEdit.editable = true
	%MessageLabel.text = "Could not join server!"


func _on_start_game_button_pressed():
	if multiplayer.is_server():
		%StartGameButton.disabled = true
		Global.server_start_game_procedure()
