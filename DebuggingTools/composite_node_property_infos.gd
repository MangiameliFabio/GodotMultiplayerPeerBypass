extends RichTextLabel

var composite_node : CompositeNode
var data_value_name : String
var callback_name : String
var function_name : String

func _ready() -> void:
	while true:
		await get_tree().create_timer(0.1).timeout
		update_text()
		
func update_text():
	text = ""
	if not composite_node:
		return
	var t : String = ""
	if data_value_name:
		t = composite_node.get_data_value_debug_string(data_value_name)
	elif callback_name:
		t = composite_node.get_callback_debug_string(callback_name)
	elif function_name:
		t = composite_node.get_function_debug_string(function_name)
		
	text = t

func datavalue_selected(cn:CompositeNode, dv:String):
	callback_name = ""
	function_name = ""
	data_value_name = dv
	composite_node = cn
	update_text()

func callback_selected(cn:CompositeNode, c:String):
	callback_name = c
	function_name = ""
	data_value_name = ""
	composite_node = cn
	update_text()

func function_selected(cn:CompositeNode, f:String):
	callback_name = ""
	function_name = f
	data_value_name = ""
	composite_node = cn
	update_text()
