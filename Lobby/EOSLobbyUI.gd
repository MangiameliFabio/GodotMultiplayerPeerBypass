extends Control

const product_id: String = "8a60a3308aab4f4d9853d719b2946bbd"
const sandbox_id: String = "236058128610414a89b2df274651e937"
const deployment_id: String = "c1a3bca1987e4b8eacdd60490cb88b56"
const client_id: String = "xyza78919hRQE7JfpxAHpWZgGkXHizPN"
const client_secret: String = "8ub30YmgRJ8iqSPvgz5Sg0bIchWBdRiT1OKiMXNnTyQ"
const encryption_key: String = "" 

const MAX_CONNECTIONS = 20

@onready var your_client_id_input : LineEdit = $ClientIDHBox/ClientIDInput_readonly

var main_peer : EOSGMultiplayerPeer
var voip_peer : EOSGMultiplayerPeer

enum State {
	NotInitialized,
	Initializing,
	InitializedAndLoggedIn,
	CreatingServer,
	ServerCreated,
	JoiningServer,
	ServerJoined
}
var current_state : State = State.NotInitialized


# Called when the node enters the scene tree for the first time.
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(0.2).timeout
	Global.ConnectionHandler.NewConnectionEstablishedAndInitialized.connect(_on_player_connected)
	Global.ConnectionHandler.ConnectionDisconnected.connect(_on_player_disconnected)
	Global.ConnectionHandler.ConnectFailed.connect(_on_connect_failed)
	Global.ConnectionHandler.DisconnectedFromServer.connect(_on_connect_failed)
	set_state(State.NotInitialized)

func set_state(new_state:State):
	$StartUpEOSButton.disabled = new_state != State.NotInitialized
	$StartServerButton.disabled = new_state != State.InitializedAndLoggedIn
	$ConnectHBox/ConnectToServerButton.disabled = new_state != State.InitializedAndLoggedIn
	$ConnectHBox/JoinClientIDInput.editable = new_state == State.InitializedAndLoggedIn
	$StartGameButton.disabled = new_state != State.ServerCreated
	current_state = new_state


func _on_init_EOS_clicked():
	set_state(State.Initializing)
	# Initialize the SDK
	var init_options = EOS.Platform.InitializeOptions.new()
	init_options.product_name = "Codename Frozen Bulgur"
	init_options.product_version = "1.0"

	var init_result := EOS.Platform.PlatformInterface.initialize(init_options)
	if init_result != EOS.Result.Success:
		print("Failed to initialize EOS SDK: ", EOS.result_str(init_result))
		$MessageLabel.text = "Failed to initialize EOS SDK: %s\n" % EOS.result_str(init_result)
		set_state(State.NotInitialized)
		return
	$MessageLabel.text = "Initialized EOS Platform\n"

	# Create platform
	var create_options = EOS.Platform.CreateOptions.new()
	create_options.product_id = product_id
	create_options.sandbox_id = sandbox_id
	create_options.deployment_id = deployment_id
	create_options.client_id = client_id
	create_options.client_secret = client_secret
	create_options.encryption_key = encryption_key
	
	EOS.Platform.PlatformInterface.create(create_options)
		
	$MessageLabel.text += "EOS Platform Created\n"

	# Setup Logs from EOS
	EOS.get_instance().logging_interface_callback.connect(_on_logging_interface_callback)
	var res := EOS.Logging.set_log_level(EOS.Logging.LogCategory.AllCategories, EOS.Logging.LogLevel.Info)
	if res != EOS.Result.Success:
		$MessageLabel.text += "Failed to set log level: %s\n" % EOS.result_str(res)
	
	EOS.get_instance().connect_interface_login_callback.connect(_on_connect_login_callback)

	await get_tree().process_frame
	_anon_login()

func _on_logging_interface_callback(msg) -> void:
	msg = EOS.Logging.LogMessage.from(msg) as EOS.Logging.LogMessage
	print("SDK %s | %s" % [msg.category, msg.message])

func _anon_login() -> void:
	# Login using Device ID (no user interaction/credentials required)
	var opts = EOS.Connect.CreateDeviceIdOptions.new()
	opts.device_model = OS.get_name() + " " + OS.get_model_name()
	EOS.Connect.ConnectInterface.create_device_id(opts)
	await EOS.get_instance().connect_interface_create_device_id_callback

	var credentials = EOS.Connect.Credentials.new()
	credentials.token = null
	credentials.type = EOS.ExternalCredentialType.DeviceidAccessToken

	var login_options = EOS.Connect.LoginOptions.new()
	login_options.credentials = credentials
	var user_login_info = EOS.Connect.UserLoginInfo.new()
	user_login_info.display_name = "User"
	login_options.user_login_info = user_login_info
	EOS.Connect.ConnectInterface.login(login_options)

func _on_connect_login_callback(data: Dictionary) -> void:
	if not data.success:
		print("Login failed")
		EOS.print_result(data)
		$MessageLabel.text += "Login Failed\n"
		set_state(State.NotInitialized)
		return
	
	your_client_id_input.text = data.local_user_id
	print_rich("[b]Login successfull[/b]: local_user_id=", data.local_user_id)
	set_state(State.InitializedAndLoggedIn)


func _on_player_connected(connection:MultiplayerConnection):
	if not is_visible_in_tree():
		return
	if connection.multiplayer_id == multiplayer.get_unique_id():
		if connection.multiplayer_id == 1:
			$MessageLabel.text += "Server created successfully\n"
			set_state(State.ServerCreated)
	else:
		$MessageLabel.text += "Player connected (id: %s)\n"%connection.multiplayer_id

func _on_player_disconnected(connection:MultiplayerConnection):
	if not is_visible_in_tree():
		return
	$MessageLabel.text += "Player disconnected (id: %s)\n"%connection.multiplayer_id


func _on_start_server_button_pressed():
	set_state(State.CreatingServer)
	var peer = EOSGMultiplayerPeer.new()
	var error = peer.create_server("main")
	if error != OK:
		set_state(State.InitializedAndLoggedIn)		
		$MessageLabel.text += "Could not start server!\n"
	else:
		main_peer = peer
		voip_peer = EOSGMultiplayerPeer.new()
		voip_peer.create_mesh("voip")
		main_peer.peer_connected.connect(eos_peer_connection_established)
		Global.ConnectionHandler.create_game(main_peer, voip_peer)


func _on_connect_to_server_button_pressed():
	var address : String = $ConnectHBox/JoinClientIDInput.text
	if address.is_empty():
		$MessageLabel.text += "EOS needs a peer id (local connection not possible)"
		return
	
	set_state(State.JoiningServer)
	var peer := EOSGMultiplayerPeer.new()
	var error = peer.create_client("main", address)
	if error:
		_on_connect_failed()
	else:
		main_peer = peer
		voip_peer = EOSGMultiplayerPeer.new()
		voip_peer.create_mesh("voip")
		Global.ConnectionHandler.join_game(main_peer, voip_peer)
		set_state(State.ServerJoined)


func eos_peer_connection_established(peer_id:int):
	if voip_peer:
		# let's wait a frame, because "peer_id" is not yet available, when we
		# want to call ...rpc_id(peer_id...
		await get_tree().process_frame
		
		var eos_peer_id := main_peer.get_peer_user_id(peer_id)
		# we connect our voip to this new peer ourselves
		Global.ConnectionHandler.voip_connection.lock_multiplayer_peer()
		voip_peer.add_mesh_peer(eos_peer_id)
		Global.ConnectionHandler.voip_connection.unlock_multiplayer_peer()
		# tell the new peer to connect to us as well
		add_eos_peer_to_mesh.rpc_id(peer_id, EOSGMultiplayerPeer.get_local_user_id())
		
		# and tell all other peers to connect to the new peer and the
		# new peer to them. (it seems like this has to be done manually in
		# a mesh network...)
		for other_peer_id in main_peer.get_all_peers():
			if other_peer_id != peer_id:
				add_eos_peer_to_mesh.rpc_id(other_peer_id, eos_peer_id)
				add_eos_peer_to_mesh.rpc_id(peer_id, main_peer.get_peer_user_id(other_peer_id))
		

@rpc("any_peer", "call_remote", "reliable")
func add_eos_peer_to_mesh(peer_id:String):
	if not Global.ConnectionHandler.voip_connection or not voip_peer:
		return
	Global.ConnectionHandler.voip_connection.lock_multiplayer_peer()
	voip_peer.add_mesh_peer(peer_id)
	Global.ConnectionHandler.voip_connection.unlock_multiplayer_peer()

func _on_connect_failed():
	if not is_visible_in_tree():
		return
	set_state(State.InitializedAndLoggedIn)
	$MessageLabel.text += "Could not join server!\n"


func _on_start_game_button_pressed():
	if multiplayer.is_server():
		$StartGameButton.disabled = true
		Global.server_start_game_procedure()
