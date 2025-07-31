extends RichTextLabel

var peer_info : voip_info_tree.PeerInfo

func _ready() -> void:
	while true:
		await get_tree().create_timer(0.1).timeout
		update_text()
		
func update_text():
	text = ""
	if peer_info and peer_info.IsSendingPeer:
		text = Global.ConnectionHandler.voip_connection.get_sending_debug_string()
	elif peer_info:
		text = Global.ConnectionHandler.voip_connection.get_receiving_peer_debug_string(peer_info.VoipPeerIndex)

func peer_selected(peer_info_param:voip_info_tree.PeerInfo):
	peer_info = peer_info_param
	update_text()
