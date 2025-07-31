extends Tree

var nodes_to_treeitems : Dictionary
var treeitems_to_nodes : Dictionary
var selected_node : CompositeNode
var currently_updating : bool = false

signal CompositeNodeSelected(cn:CompositeNode)

func _ready() -> void:
	item_selected.connect(on_selection_changed)
	while true:
		update_tree_with_current_nodes()
		await get_tree().create_timer(1).timeout

func on_selection_changed():
	if currently_updating:
		return
	var new_selected_treeitem : TreeItem = get_selected()
	if new_selected_treeitem == selected_node:
		return
	if new_selected_treeitem:
		selected_node = treeitems_to_nodes[new_selected_treeitem]
		CompositeNodeSelected.emit(selected_node)
	else:
		selected_node = null
		CompositeNodeSelected.emit(null)

func update_tree_with_current_nodes() -> void:
	currently_updating = true
	clear()
	create_item() # (root. has to be created...)
	nodes_to_treeitems.clear()
	treeitems_to_nodes.clear()

	for i in CompositeNode.GetNumberOfExistingCompositeNodes():
		var cn := CompositeNode.GetExistingCompositeNode(i)
		if cn in nodes_to_treeitems:
			continue
		add_compositenode(cn)
	currently_updating = false

func add_compositenode(cn:CompositeNode) -> TreeItem:
	var cn_treeitem : TreeItem
	if cn.ParentCompositeNode:
		var parent_treeitem : TreeItem
		var parent_node : CompositeNode = cn.get_node_or_null(cn.ParentCompositeNode)
		if nodes_to_treeitems.has(parent_node):
			parent_treeitem = nodes_to_treeitems[parent_node]
		else:
			parent_treeitem = add_compositenode(parent_node)
		cn_treeitem = parent_treeitem.create_child()
	else:
		cn_treeitem = get_root().create_child()
	nodes_to_treeitems[cn] = cn_treeitem
	treeitems_to_nodes[cn_treeitem] = cn
	cn_treeitem.set_text(0, "[%s] %s"%[cn.CompositeID, cn.name])
	if cn == selected_node:
		cn_treeitem.select(0)
	return cn_treeitem


func _on_button_pressed() -> void:
	pass # Replace with function body.
