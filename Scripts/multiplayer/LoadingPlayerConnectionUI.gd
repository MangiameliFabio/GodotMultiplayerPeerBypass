extends Control

class_name LoadingPlayerConnectionUI

func initialize_with_player_ID(playerID):
	%PlayerName.text = str(playerID)
	
	while true:
		if not Global.ConnectionHandler.multiplayer_connections.has(playerID):
			%PlayerState.text = "no connection"
		else:
			var mp_conn : MultiplayerConnection = Global.ConnectionHandler.multiplayer_connections[playerID]
			if mp_conn._state == MultiplayerConnection.States.Loading:
				%PlayerState.text = "loading..."
			elif mp_conn._state == MultiplayerConnection.States.InitializingGame:
				%PlayerState.text = "Initializing Game..."
			elif mp_conn._state == MultiplayerConnection.States.Waiting:
				%PlayerState.text = "Waiting..."
			elif mp_conn._state == MultiplayerConnection.States.InGame:
				%PlayerState.text = "In Game..."
		await Global.get_tree().process_frame
