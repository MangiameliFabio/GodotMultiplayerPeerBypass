extends Tree

var current_node : CompositeNode
var values_tree_item : TreeItem
var callbacks_tree_item : TreeItem
var functions_tree_item : TreeItem

signal DataValueSelected(cn:CompositeNode, dv:String)
signal CallbackSelected(cn:CompositeNode, cb:String)
signal FunctionSelected(cn:CompositeNode, fn:String)

func _ready() -> void:
	item_selected.connect(on_selection_changed)
	while true:
		await get_tree().create_timer(1).timeout
		if current_node:
			for dv_treeitem in values_tree_item.get_children():
				dv_treeitem.set_text(1, str(current_node.GetData(dv_treeitem.get_text(0))))

func on_selection_changed():
	var new_selected_treeitem : TreeItem = get_selected()
	if new_selected_treeitem:
		if new_selected_treeitem in values_tree_item.get_children():
			DataValueSelected.emit(current_node, new_selected_treeitem.get_text(0))
			return
		if new_selected_treeitem in callbacks_tree_item.get_children():
			CallbackSelected.emit(current_node, new_selected_treeitem.get_text(0))
			return
		if new_selected_treeitem in functions_tree_item.get_children():
			FunctionSelected.emit(current_node, new_selected_treeitem.get_text(0))
			return
	DataValueSelected.emit(null, "")

func _on_composite_nodes_tree_composite_node_selected(cn: CompositeNode) -> void:
	current_node = cn
	clear()
	if not cn:
		return
	var root := create_item()
	
	values_tree_item = root.create_child()
	values_tree_item.set_text(0, "Values")
	values_tree_item.set_selectable(0, false)
	for dv_name in cn.get_data_value_names():
		var dv_treeitem := values_tree_item.create_child()
		dv_treeitem.set_text(0, dv_name)
		dv_treeitem.set_text(1, str(cn.GetData(dv_name)))
	
	callbacks_tree_item = root.create_child()
	callbacks_tree_item.set_text(0, "Callbacks")
	callbacks_tree_item.set_selectable(0, false)
	for cb_name in cn.get_callback_names():
		var cb_treeitem := callbacks_tree_item.create_child()
		cb_treeitem.set_text(0, cb_name)
	
	functions_tree_item = root.create_child()
	functions_tree_item.set_text(0, "Functions")
	functions_tree_item.set_selectable(0, false)
	for f_name in cn.get_function_names():
		var f_treeitem := functions_tree_item.create_child()
		f_treeitem.set_text(0, f_name)

func _sort_entries_alphabetic():
	clear()
	if not current_node:
		return
	var root := create_item()
	
	values_tree_item = root.create_child()
	values_tree_item.set_text(0, "Values")
	values_tree_item.set_selectable(0, false)
	
	var sorted_list = current_node.get_data_value_names()
	sorted_list.sort()
	
	for dv_name in sorted_list:
		var dv_treeitem := values_tree_item.create_child()
		dv_treeitem.set_text(0, dv_name)
		dv_treeitem.set_text(1, str(current_node.GetData(dv_name)))
	
	callbacks_tree_item = root.create_child()
	callbacks_tree_item.set_text(0, "Callbacks")
	callbacks_tree_item.set_selectable(0, false)
	
	sorted_list = current_node.get_callback_names()
	sorted_list.sort()
	
	for cb_name in sorted_list:
		var cb_treeitem := callbacks_tree_item.create_child()
		cb_treeitem.set_text(0, cb_name)
	
	functions_tree_item = root.create_child()
	functions_tree_item.set_text(0, "Functions")
	functions_tree_item.set_selectable(0, false)
	
	sorted_list = current_node.get_function_names()
	sorted_list.sort()
	
	for f_name in sorted_list:
		var f_treeitem := functions_tree_item.create_child()
		f_treeitem.set_text(0, f_name)
	
func _sort_entries_by_init():
	clear()
	if not current_node:
		return
	var root := create_item()
	
	values_tree_item = root.create_child()
	values_tree_item.set_text(0, "Values")
	values_tree_item.set_selectable(0, false)
	for dv_name in current_node.get_data_value_names():
		var dv_treeitem := values_tree_item.create_child()
		dv_treeitem.set_text(0, dv_name)
		dv_treeitem.set_text(1, str(current_node.GetData(dv_name)))
	
	callbacks_tree_item = root.create_child()
	callbacks_tree_item.set_text(0, "Callbacks")
	callbacks_tree_item.set_selectable(0, false)
	for cb_name in current_node.get_callback_names():
		var cb_treeitem := callbacks_tree_item.create_child()
		cb_treeitem.set_text(0, cb_name)
	
	functions_tree_item = root.create_child()
	functions_tree_item.set_text(0, "Functions")
	functions_tree_item.set_selectable(0, false)
	for f_name in current_node.get_function_names():
		var f_treeitem := functions_tree_item.create_child()
		f_treeitem.set_text(0, f_name)
