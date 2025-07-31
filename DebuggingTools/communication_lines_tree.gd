extends Tree

@export var general_debug_info_label : Label

var lines_to_treeitems : Dictionary
var treeitems_to_lines : Dictionary
var selected_line : CommunicationLine
var currently_updating : bool = false
var total_recv_bytes : int
var total_sent_bytes : int

signal CommunicationLineSelected(cl:CommunicationLine)

func _ready() -> void:
	item_selected.connect(on_selection_changed)
	while true:
		update_tree_with_current_nodes()
		await get_tree().create_timer(1).timeout

func on_selection_changed():
	if currently_updating:
		return
	var new_selected_treeitem : TreeItem = get_selected()
	if new_selected_treeitem == selected_line:
		return
	if new_selected_treeitem:
		selected_line = treeitems_to_lines[new_selected_treeitem]
		CommunicationLineSelected.emit(selected_line)
	else:
		selected_line = null
		CommunicationLineSelected.emit(null)

func update_tree_with_current_nodes() -> void:
	currently_updating = true
	clear()
	create_item() # (root. has to be created...)
	lines_to_treeitems.clear()
	treeitems_to_lines.clear()
	total_recv_bytes = 0
	total_sent_bytes = 0
	
	for i in Global.Coms.get_number_of_communication_lines():
		var cl : CommunicationLine = Global.Coms.get_communication_line(i)
		if cl in lines_to_treeitems:
			continue
		add_communicationline(cl)
	if general_debug_info_label: general_debug_info_label.text = \
		"%sb/s received  %sb/s sent" % [total_recv_bytes, total_sent_bytes]
	currently_updating = false

func add_communicationline(cl:CommunicationLine) -> TreeItem:
	var cl_treeitem : TreeItem = get_root().create_child()
	lines_to_treeitems[cl] = cl_treeitem
	treeitems_to_lines[cl_treeitem] = cl
	var recv_bytes : int = cl.get_num_bytes_received_last_second()
	var sent_bytes : int = cl.get_num_bytes_sent_last_second()
	cl_treeitem.set_text(0, "CommunicationLine %s (d:%sb/s u:%sb/s)"%[cl.get_string_id(), recv_bytes, sent_bytes])
	total_recv_bytes += recv_bytes
	total_sent_bytes += sent_bytes
	if cl == selected_line:
		cl_treeitem.select(0)
	return cl_treeitem
