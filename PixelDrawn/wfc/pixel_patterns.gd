class_name PixelPatterns
extends Node


var _color_indices: ColorIndex = ColorIndex.new()
var _pixel_patterns: Array[PixelPattern]
var _patterns_links: Array[PatternLink]

func _init(input_sample: Texture2D, rotations: bool = false, reflections: bool = false) -> void:

	_get_3x3_pixel_patterns(input_sample)
	
	# Optionally augment patterns with rotations
	if rotations:
		_strip_duplicate_patterns()
		_add_patterns_rotations()
	
	# Optionally augment patterns with reflections
	if reflections:
		_strip_duplicate_patterns()
		_add_patterns_reflections()
	
	# Strip any duplicate patterns
	_strip_duplicate_patterns()
	
	# Create pattern linking dictionaries
	_create_pattern_matching_connections()

#region data access

func pattern_count() -> int:
	return len(_pixel_patterns)

func get_pattern_color_index_by_pos_index(pixel_pattern_index: int, pos_index: int) -> int:
	return _get_pattern(pixel_pattern_index).get_pixel_color_index(pos_index)

func get_pattern_color_indices(pixel_pattern_index: int) -> Array[int]:
	return _get_pattern(pixel_pattern_index).get_color_indices()

func _get_pattern(pixel_pattern_index: int) -> PixelPattern:
	return _pixel_patterns[pixel_pattern_index]

func get_color_by_index(color_index: int) -> Color:
	return _color_indices.get_color(color_index)

func get_pattern_indices_in_direction(pixel_pattern_index: int, dir: Vector2i) -> Array[int]:
	return _patterns_links[pixel_pattern_index].links_as_pattern_indices(dir)

#endregion

#region pattern identification

func _get_3x3_pixel_patterns(sample: Texture2D) -> void:
	_pixel_patterns = []
	
	var image : Image = sample.get_image()
	for p_y in range(1, image.get_height() - 1):
		for p_x in range(1, image.get_width() - 1):
			var pattern: PixelPattern = _get_3x3_colors_centered_at(image, p_x, p_y)
			_pixel_patterns.append(pattern)

func _get_3x3_colors_centered_at(image: Image, p_x: int, p_y: int) -> PixelPattern:
	var pattern_color_indices: Array[int] = []
	for y in range(p_y - 1, p_y + 2):
		for x in range(p_x - 1, p_x + 2):
			var color_index: int = _color_indices.get_index_for_color(image.get_pixel(x, y))
			pattern_color_indices.append(color_index)
	
	return PixelPattern.new(pattern_color_indices)

#endregion

#region pattern set modification

func _strip_duplicate_patterns() -> void:
	"""Trim duplicates from _pixel_patterns, maintaining the order"""
	var unique_patterns: Array[PixelPattern] = []
	for index in range(len(_pixel_patterns)):
		var pattern: PixelPattern = _pixel_patterns.pop_back()
		
		# TODO: What are the chances this will work with custom classes?
		if not _pixel_patterns.any(
			func (p: PixelPattern) -> bool: return p._color_indices == pattern._color_indices
		):
			unique_patterns.insert(0, pattern)

	_pixel_patterns = unique_patterns

func _add_patterns_rotations() -> void:
	var rotation_patterns: Array[PixelPattern] = []
	for pixel_pattern in _pixel_patterns:
		rotation_patterns.append_array(_get_pattern_rotations(pixel_pattern))
	
	_pixel_patterns.append_array(rotation_patterns)

func _get_pattern_rotations(pixel_pattern: PixelPattern) -> Array[PixelPattern]:
	var pattern_rotations: Array[PixelPattern] = []
	pattern_rotations.append(pixel_pattern.rotate_90())
	pattern_rotations.append(pixel_pattern.rotate_180())
	pattern_rotations.append(pixel_pattern.rotate_270())
	
	return pattern_rotations

func _add_patterns_reflections() -> void:
	var reflection_patterns: Array[PixelPattern] = []
	for pixel_pattern in _pixel_patterns:
		reflection_patterns.append_array(_get_pattern_reflections(pixel_pattern))
	
	_pixel_patterns.append_array(reflection_patterns)

func _get_pattern_reflections(pixel_pattern: PixelPattern) -> Array[PixelPattern]:
	var pattern_reflections: Array[PixelPattern] = []
	pattern_reflections.append(pixel_pattern.flip_hortz())
	pattern_reflections.append(pixel_pattern.flip_vert())
	
	return pattern_reflections

#endregion

#region link mapping

func _create_pattern_matching_connections() -> void:
	"""Create a mapping from each pattern to patterns that will fit in each direction"""
	_patterns_links = []
	for pattern_index in range(len(_pixel_patterns)):
		_patterns_links.append(PatternLink.new(_pixel_patterns, pattern_index))

func find_edge_only_linked_pattern_indices() -> Dictionary:
	var edge_only_pattern_indices: Dictionary = {
		Vector2i.UP + Vector2i.LEFT: [],
		Vector2i.UP + Vector2i.RIGHT: [],
		Vector2i.DOWN + Vector2i.LEFT: [],
		Vector2i.DOWN + Vector2i.RIGHT: [],
		Vector2i.UP: [],
		Vector2i.LEFT: [],
		Vector2i.RIGHT: [],
		Vector2i.DOWN: [],
	}
	
	for pattern_index in range(len(_pixel_patterns)):
		var link: PatternLink = _patterns_links[pattern_index]
		
		# We want to find full sides or corners that indicate this tile has to
		# be on the edge or in a corner
		
		for dir in edge_only_pattern_indices.keys():
			if link.is_on_edge_or_in_corner(dir):
				edge_only_pattern_indices[dir].append(pattern_index)
	
	return edge_only_pattern_indices

#endregion

#region debug functions

func print_color_indices_to_stdout() -> void:
	var color_debug_str: String = ""
	for color_index in range(_color_indices.color_count()):
		color_debug_str += "{color_index}: {color}\n".format(
			{"color_index": color_index, "color": _color_indices.get_color(color_index)}
		)
	print(color_debug_str)

func create_and_save_debug_pattern_image() -> void:
	# Create an image big enough to hold the patterns
	var buffer_size: int = 1
	var pattern_grid_side: int = int(ceil(sqrt(pattern_count())))
	var image_side: int = pattern_grid_side * (3 + buffer_size) + buffer_size
	var pattern_image: Image = Image.create(image_side, image_side, false, Image.FORMAT_RGBA8)
	
	# Insert each pattern into the image
	for pattern_index: int in range(pattern_count()):
		var pattern_x: int = pattern_index % pattern_grid_side
		var pattern_y: int = pattern_index / pattern_grid_side
		var start_x: int = pattern_x * (3 + buffer_size)
		var start_y: int = pattern_y * (3 + buffer_size)
		for pixel_index: int in range(9):
			var color_index: int = _pixel_patterns[pattern_index].get_pixel_color_index(pixel_index)
			var color: Color = _color_indices.get_color(color_index)
			var x: int = start_x + (pixel_index % 3) + buffer_size
			var y: int = start_y + (pixel_index / 3) + buffer_size
			pattern_image.set_pixel(x, y, color)
	
	# save the image to a PNG
	pattern_image.save_png("res://PixelDrawn/wfc/samples/test_patterns.png")

func create_and_save_debug_linkage_table() -> void:
	var linkage_table_str: String = ""
	for pattern_index: int in range(len(_pixel_patterns)):
		var link: PatternLink = _patterns_links[pattern_index]
		
		linkage_table_str += "{index}:\n".format({"index": pattern_index})
		for link_vector in [
			Vector2i.UP + Vector2i.LEFT,
			Vector2i.UP,
			Vector2i.UP + Vector2i.RIGHT,
			Vector2i.LEFT,
			Vector2i.RIGHT,
			Vector2i.DOWN + Vector2i.LEFT,
			Vector2i.DOWN,
			Vector2i.DOWN + Vector2i.RIGHT,
		]:
			linkage_table_str += "    {vector}: {pattern_indices}\n".format(
				{
					"vector": link_vector,
					"pattern_indices": link.links_as_pattern_indices(link_vector),
				}
			)
		linkage_table_str += "\n"
	
	var file = FileAccess.open("res://PixelDrawn/wfc/samples/test_links.txt", FileAccess.WRITE)
	file.store_string(linkage_table_str)

#endregion


class ColorIndex:
	var _colors: Array[Color]
	
	func get_index_for_color(color: Color) -> int:
		var index = _colors.find(color)
		if index >= 0:
			return index
		
		_colors.append(color)
		return _colors.size() - 1
	
	func get_color(color_index: int) -> Color:
		return _colors[color_index]
	
	func color_count() -> int:
		return len(_colors)

class PixelPattern:
	var _color_indices: Array[int]
	
	func _init(color_indices: Array[int]) -> void:
		_color_indices = color_indices
	
	func get_color_indices() -> Array[int]:
		return _color_indices
	
	func get_pixel_color_index(pixel_index: int) -> int:
		return get_color_indices()[pixel_index]
	
	#region pattern translation
	
	func rotate_270() -> PixelPattern:
		return PixelPattern.new(
			[
				_color_indices[2], _color_indices[5], _color_indices[8],
				_color_indices[1], _color_indices[4], _color_indices[7],
				_color_indices[0], _color_indices[3], _color_indices[6],
			]
		)
	
	func rotate_180() -> PixelPattern:
		return PixelPattern.new(
			[
				_color_indices[8], _color_indices[7], _color_indices[6],
				_color_indices[5], _color_indices[4], _color_indices[3],
				_color_indices[2], _color_indices[1], _color_indices[0],
			]
		)
	
	func rotate_90() -> PixelPattern:
		return PixelPattern.new(
			[
				_color_indices[6], _color_indices[3], _color_indices[0],
				_color_indices[7], _color_indices[4], _color_indices[1],
				_color_indices[8], _color_indices[5], _color_indices[2],
			]
		)
	
	func flip_hortz() -> PixelPattern:
		return PixelPattern.new(
			[
				_color_indices[2], _color_indices[1], _color_indices[0],
				_color_indices[5], _color_indices[4], _color_indices[3],
				_color_indices[8], _color_indices[7], _color_indices[6],
			]
		)
	
	func flip_vert() -> PixelPattern:
		return PixelPattern.new(
			[
				_color_indices[6], _color_indices[7], _color_indices[8],
				_color_indices[3], _color_indices[4], _color_indices[5],
				_color_indices[0], _color_indices[1], _color_indices[2],
			]
		)
	
	#endregion
	
	#region pattern matching
	
	func up_left_match(other: PixelPattern) -> bool:
		return [
			other._color_indices[4], other._color_indices[5],
			other._color_indices[7], other._color_indices[8],
		] == [
			_color_indices[0], _color_indices[1],
			_color_indices[3], _color_indices[4],
		]
	
	func up_match(other: PixelPattern) -> bool:
		return [
			other._color_indices[3], other._color_indices[4], other._color_indices[5],
			other._color_indices[6], other._color_indices[7], other._color_indices[8],
		] == [
			_color_indices[0], _color_indices[1], _color_indices[2],
			_color_indices[3], _color_indices[4], _color_indices[5],
		]
	
	func up_right_match(other: PixelPattern) -> bool:
		return [
			other._color_indices[3], other._color_indices[4],
			other._color_indices[6], other._color_indices[7],
		] == [
			_color_indices[1], _color_indices[2],
			_color_indices[4], _color_indices[5],
		]
	
	func left_match(other: PixelPattern) -> bool:
		return [
			other._color_indices[1], other._color_indices[2],
			other._color_indices[4], other._color_indices[5],
			other._color_indices[7], other._color_indices[8],
		] == [
			_color_indices[0], _color_indices[1],
			_color_indices[3], _color_indices[4],
			_color_indices[6], _color_indices[7],
		]
	
	func right_match(other: PixelPattern) -> bool:
		return [
			other._color_indices[0], other._color_indices[1],
			other._color_indices[3], other._color_indices[4],
			other._color_indices[6], other._color_indices[7],
		] == [
			_color_indices[1], _color_indices[2],
			_color_indices[4], _color_indices[5],
			_color_indices[7], _color_indices[8],
		]
	
	func down_left_match(other: PixelPattern) -> bool:
		return [
			other._color_indices[1], other._color_indices[2],
			other._color_indices[4], other._color_indices[5],
		] == [
			_color_indices[3], _color_indices[4],
			_color_indices[6], _color_indices[7],
		]
	
	func down_match(other: PixelPattern) -> bool:
		return [
			other._color_indices[0], other._color_indices[1], other._color_indices[2],
			other._color_indices[3], other._color_indices[4], other._color_indices[5],
		] == [
			_color_indices[3], _color_indices[4], _color_indices[5],
			_color_indices[6], _color_indices[7], _color_indices[8],
		]
	
	func down_right_match(other: PixelPattern) -> bool:
		return [
			other._color_indices[0], other._color_indices[1],
			other._color_indices[3], other._color_indices[4],
		] == [
			_color_indices[4], _color_indices[5],
			_color_indices[7], _color_indices[8],
		]
	
	#endregion

class PatternLink:
	var _pattern_index: int
	var _pattern: PixelPattern
	var _pattern_link_lists: Dictionary = {
		Vector2i.UP + Vector2i.LEFT: [],
		Vector2i.UP: [],
		Vector2i.UP + Vector2i.RIGHT: [],
		Vector2i.LEFT: [],
		Vector2i.RIGHT: [],
		Vector2i.DOWN + Vector2i.LEFT: [],
		Vector2i.DOWN: [],
		Vector2i.DOWN + Vector2i.RIGHT: [],
	}
	
	func _init(pixel_patterns: Array[PixelPattern], pattern_index: int) -> void:
		_pattern_index = pattern_index
		_pattern = pixel_patterns[pattern_index]
		_find_links_in_each_direction(pixel_patterns)
	
	func _to_string() -> String:
		return "{index}: {links}".format(
			{"index": _pattern_index, "links": _pattern_link_lists}
		)
	
	func _find_links_in_each_direction(pixel_patterns: Array[PixelPattern]) -> void:
		# Find the patterns that match in each direction and append them to them to the appropriate lists
		# Can include all patterns in each direction, including this pattern
		for pixel_pattern_index in range(len(pixel_patterns)):
			var possible_neighbour: PixelPattern = pixel_patterns[pixel_pattern_index]
			# In each direction check that each 4 or 6 pixels overlap exactly
			
			if _pattern.up_left_match(possible_neighbour):
				_pattern_link_lists[Vector2i.UP + Vector2i.LEFT].append(pixel_pattern_index)
			if _pattern.up_match(possible_neighbour):
				_pattern_link_lists[Vector2i.UP].append(pixel_pattern_index)
			if _pattern.up_right_match(possible_neighbour):
				_pattern_link_lists[Vector2i.UP + Vector2i.RIGHT].append(pixel_pattern_index)
			if _pattern.left_match(possible_neighbour):
				_pattern_link_lists[Vector2i.LEFT].append(pixel_pattern_index)
			if _pattern.right_match(possible_neighbour):
				_pattern_link_lists[Vector2i.RIGHT].append(pixel_pattern_index)
			if _pattern.down_left_match(possible_neighbour):
				_pattern_link_lists[Vector2i.DOWN + Vector2i.LEFT].append(pixel_pattern_index)
			if _pattern.down_match(possible_neighbour):
				_pattern_link_lists[Vector2i.DOWN].append(pixel_pattern_index)
			if _pattern.down_right_match(possible_neighbour):
				_pattern_link_lists[Vector2i.DOWN + Vector2i.RIGHT].append(pixel_pattern_index)
	
	func links_as_pattern_indices(direction: Vector2i) -> Array[int]:
		# Not a big fun of this way to ensure types, but it is a godot limitation
		var link_patterns: Array[int] = []
		link_patterns.assign(_pattern_link_lists[direction])
		return link_patterns
	
	func is_on_edge_or_in_corner(direction: Vector2i) -> bool:
		"""Pattern is on this edge/corner if all links in that direction have no patterns"""
		var all_patterns_in_given_direction: Array[int] = []
		for link_list_dir: Vector2i in _pattern_link_lists.keys():
			if (
				(link_list_dir.x == direction.x and direction.x != 0)
				or
				(link_list_dir.y == direction.y and direction.y != 0)
			):
				all_patterns_in_given_direction.append_array(_pattern_link_lists[link_list_dir])
		
		return all_patterns_in_given_direction.is_empty()
