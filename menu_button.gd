extends MenuButton

const CATEGORIES := {
	"Pixel Drawn" : "res://PixelDrawn",
	"Vector Drawn" : "res://VectorDrawn",
	"Shader Drawn" : "res://ShaderDrawn",
	"Compute Drawn" : "res://ComputeDrawn",
}

@onready var display_node := %DisplayControl

var menu_selections : Dictionary = {}

func _ready() -> void:
	var popup := get_popup()
	popup.set_allow_search(true)
	var _err : Error = popup.connect("id_pressed", _popup_menu_selected)
	
	var id: int = 0
	for category in CATEGORIES.keys():
		var path : String = CATEGORIES[category]
		
		# Get list from path and add to menu
		var dir := DirAccess.open(path)
		if dir:
			popup.add_item(category, id)
			popup.set_item_disabled(id, true)
			id += 1
			
			_err = dir.list_dir_begin()
			var file_name : String = dir.get_next()
			while file_name != "":
				if file_name.match("*.*scn"):
					var scene_name : String = file_name.rsplit(".", true, 1)[0]
					var scene_path : String = path + "/" + file_name
					popup.add_item(scene_name, id)
					menu_selections[id] = scene_path
					id += 1
				file_name = dir.get_next()
			dir.list_dir_end()
		else:
			printerr("Couldn't read directory: " + path)


func _popup_menu_selected(id : int) -> void:
	var scene_path : String = menu_selections[id]
	var scene_resource : Resource = load(scene_path)
	var scene = scene_resource.instantiate()
	_clear_free_children(display_node)
	display_node.add_child(scene)


func _clear_free_children(node : Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
