class_name voip_info_tree extends Tree

@export var general_debug_info_label : Label

class PeerInfo:
	var VoipPeerIndex : int
	var IsSendingPeer : bool

var sending_peer_info : PeerInfo = PeerInfo.new()
var receiving_peer_infos : Dictionary

var peers_to_treeitems : Dictionary
var treeitems_to_peers : Dictionary
var selected_peer : PeerInfo
var currently_updating : bool = false

signal PeerSelected(peer_info:PeerInfo)

func _ready() -> void:
	item_selected.connect(on_selection_changed)
	while true:
		update_tree_with_current_nodes()
		await get_tree().create_timer(1).timeout

func on_selection_changed():
	if currently_updating:
		return
	var new_selected_treeitem : TreeItem = get_selected()
	if new_selected_treeitem == selected_peer:
		return
	if new_selected_treeitem:
		selected_peer = treeitems_to_peers[new_selected_treeitem]
		PeerSelected.emit(selected_peer)
	else:
		selected_peer = null
		PeerSelected.emit(null)

func update_tree_with_current_nodes() -> void:
	currently_updating = true
	clear()
	create_item() # (root. has to be created...)
	peers_to_treeitems.clear()
	treeitems_to_peers.clear()

	sending_peer_info.IsSendingPeer = true
	sending_peer_info.VoipPeerIndex = -1
	add_peer(sending_peer_info)

	for i in Global.ConnectionHandler.voip_connection.get_number_of_receiving_peers():
		var recv_peer : PeerInfo = receiving_peer_infos.get(i)
		if not recv_peer:
			recv_peer = PeerInfo.new()
			recv_peer.IsSendingPeer = false
			recv_peer.VoipPeerIndex = i
			receiving_peer_infos[i] = recv_peer
		add_peer(recv_peer)
	if general_debug_info_label: general_debug_info_label.text = \
		"%sb/s received  %sb/s sent   sendthread: %dms/s  recvthread: %dms/s" % [
			Global.ConnectionHandler.voip_connection.get_receiving_bandwidth(),
			Global.ConnectionHandler.voip_connection.get_sending_bandwidth(),
			Global.ConnectionHandler.voip_connection.get_send_thread_iteration_duration(),
			Global.ConnectionHandler.voip_connection.get_receive_thread_iteration_duration()]
	currently_updating = false

func add_peer(peer_info:PeerInfo) -> TreeItem:
	var peer_treeitem : TreeItem = get_root().create_child()
	peers_to_treeitems[peer_info] = peer_treeitem
	treeitems_to_peers[peer_treeitem] = peer_info
	peer_treeitem.set_text(0, "Sending Peer" if peer_info.IsSendingPeer else "Receiving Peer %d"%peer_info.VoipPeerIndex)
	if peer_info == selected_peer:
		peer_treeitem.select(0)
	return peer_treeitem
