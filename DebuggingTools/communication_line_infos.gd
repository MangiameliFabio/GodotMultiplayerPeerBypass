extends RichTextLabel

var communication_line : CommunicationLine

func _ready() -> void:
	while true:
		await get_tree().create_timer(0.1).timeout
		update_text()
		
func update_text():
	text = ""
	if not communication_line:
		return
	var t : String = "String Identifier: %s\nInt Identifier: %s\nOwn Multiplayer ID: %s\n%sb/s received  %sb/s sent\n"%[
		communication_line.get_string_id(),
		communication_line.get_int_id(),
		communication_line.get_local_multiplayer_id(),
		communication_line.get_num_bytes_received_last_second(),
		communication_line.get_num_bytes_sent_last_second()
	]
	t += "Own State: %s\n\n"%(communication_line.get_local_peer_state())
	t += "Own Bits: %s\n\n"%(String.num_uint64(communication_line.get_local_peer_bits(), 2))
	
	#for p in multiplayer.get_peers():
		#t += "Peer %s state: %s  bits: %s\n"%[p, communication_line.get_peer_state(p), String.num_uint64(communication_line.get_peer_bits(p), 2)]
		
	text = t

func communication_line_selected(cl:CommunicationLine):
	communication_line = cl
	update_text()
