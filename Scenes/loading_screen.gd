extends CanvasLayer


@export var player_loading_scene : PackedScene


func show_loading_screen():
	visible = true
	
	for child in %PlayersBox.get_children():
		child.queue_free()
	
	for player_id in Global.ConnectionHandler.multiplayer_connections:
		var player_loading_panel : LoadingPlayerConnectionUI = player_loading_scene.instantiate()
		%PlayersBox.add_child(player_loading_panel)
		player_loading_panel.initialize_with_player_ID(player_id)

func hide_loading_screen():
	visible = false
	for child in %PlayersBox.get_children():
		child.queue_free()
