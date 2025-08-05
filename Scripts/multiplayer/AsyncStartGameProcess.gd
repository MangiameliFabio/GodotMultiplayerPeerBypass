class_name AsyncStartGameProcess extends Resource

@export_file("*.tscn") var GameScenePath : String

func RunProcess():
	Global.StateMachine.SetUnsetStates([Global.State.Loading], [Global.State.InLobby, Global.State.InGame])
	Global.get_tree().paused = true
	ResourceLoaderQueue.queueResource(GameScenePath)
	var local_connection := Global.ConnectionHandler.get_my_connection()
	local_connection.set_state(999, MultiplayerConnection.States.Loading)
	local_connection.communication_line.call_function_on_peers(&"set_state", [MultiplayerConnection.States.Loading])
	await ResourceLoaderQueue.waitForLoadingFinished()

	local_connection.set_state(999, MultiplayerConnection.States.InitializingGame)
	local_connection.communication_line.call_function_on_peers(&"set_state", [MultiplayerConnection.States.InitializingGame])
	var game : Game = ResourceLoaderQueue.getCachedResource(GameScenePath).instantiate()
	# the whole tree.current_scene functionality 
	# should probably not even be used...
	if Global.get_tree().current_scene != null:
		Global.get_tree().current_scene.queue_free()
	Global.get_tree().root.add_child(game)
	Global.get_tree().current_scene = game
	await game.initialize_game()

	local_connection.set_state(999, MultiplayerConnection.States.Waiting)
	local_connection.communication_line.call_function_on_peers(&"set_state", [MultiplayerConnection.States.Waiting])
