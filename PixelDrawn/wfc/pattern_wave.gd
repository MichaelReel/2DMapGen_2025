class_name PatternWave
extends Node


const ORDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
	Vector2i.UP + Vector2i.LEFT, Vector2i.UP + Vector2i.RIGHT,
	Vector2i.DOWN + Vector2i.LEFT, Vector2i.DOWN + Vector2i.RIGHT,
]
const MAX_PROPAGATION_DEPTH: int = 50

var _pixel_patterns: PixelPatterns
var _image_size: Vector2i
var _cells: Array[ImageCell]
var _updated_cells: Array[Vector2i]
var _wave_front: Array[Vector2i]
var _max_propagation_depth: int

func _init(
	image_size: Vector2i,
	pixel_patterns: PixelPatterns,
	max_propagation_depth: int = MAX_PROPAGATION_DEPTH,
) -> void:
	_image_size = image_size
	_pixel_patterns = pixel_patterns
	_max_propagation_depth = max_propagation_depth
	_prepare_image_wave_as_a_pattern_index_array()

func _prepare_image_wave_as_a_pattern_index_array() -> void:
	"""prepare the workspace for potential patterns at each cell"""
	var template_pattern_list: Array[int] = []
	for index in _pixel_patterns.pattern_count():
		template_pattern_list.append(index)
	
	_cells = []
	for _index in range(_image_size.x * _image_size.y):
		_cells.append(ImageCell.new(template_pattern_list))

func _propagate_cell_changes(pos: Vector2i, max_depth: int = _max_propagation_depth) -> void:
	if max_depth <= 0:
		return
	# Firstly, make sure this cell has been added to the next drawn
	_updated_cells.append(pos)
	
	#var indent: String = ""
	#for _i in (_max_propagation_depth - max_depth):
		#indent += "    "
	
	# Get the superset of all viable patterns in each direction
	var restrictions_by_direction: Dictionary = _get_pattern_restrictions_to_neighbour_cells(pos)
	#print(indent, pos, "(", max_depth ,") -> ", restrictions_by_direction)
	
	for dir in restrictions_by_direction:
		#print(indent, dir, " -> ", pos + dir, ": ", restrictions_by_direction[dir])
		_restrict_patterns_at_cell(pos + dir, restrictions_by_direction[dir], max_depth)
	
	if max_depth == _max_propagation_depth:
		# This should be teh updates dones for this run
		_update_wavefront_from_updated_cells()

func _update_wavefront_from_updated_cells() -> void:
	#print("updated cells: ", _updated_cells)
	var cell_to_pattern_count_mapping: Dictionary = {}
	for updated_cell in _updated_cells:
		cell_to_pattern_count_mapping[updated_cell] = len(
			get_remaining_patterns_in_cell(updated_cell)
		)
	#print("cell patterns: ", cell_to_pattern_count_mapping)
	
	# Get a sorted list of new cells for the wave_front list
	var updated_wave_front_cells: Array[Vector2i]
	updated_wave_front_cells.assign(cell_to_pattern_count_mapping.keys())
	updated_wave_front_cells.sort_custom(
		func (a: Vector2i, b: Vector2i) -> bool:
			return cell_to_pattern_count_mapping[a] < cell_to_pattern_count_mapping[b]
	)
	#print("updated_wave_front_cells: ", updated_wave_front_cells)
	
	# Insert/Update cells in wave_front
	for pos in updated_wave_front_cells:
		# Skip cells that are completed
		if cell_is_complete(pos):
			continue
		
		if pos in _wave_front:
			_wave_front.erase(pos)
		
		var insertion_point: int = _wave_front.bsearch_custom(pos, 
			func (a: Vector2i, b: Vector2i) -> bool:
				var a_len: int = len(get_remaining_patterns_in_cell(a))
				var b_len: int = len(get_remaining_patterns_in_cell(b))
				return a_len < b_len
		)
		_wave_front.insert(insertion_point, pos)
	#print("_wave_front: ", _wave_front)

func _get_pattern_restrictions_to_neighbour_cells(pos: Vector2i) -> Dictionary:
	"""For each cell around `pos` get what each cell should be limited to"""
	var neighbour_restrictions: Dictionary = {}
	
	# We don't need to include every direction if:
	# 1) The direction is upto the edge of the image
	# 2) The destination cell is already "complete"
	# 3) The set of restrictions is `all` patterns? Not sure it could be.
	for dir in ORDINAL_DIRECTIONS:
		var neighbour_pos: Vector2i = pos + dir
		
		# Check for and skip edge tiles/pixels
		if neighbour_pos.x < 1: continue
		if neighbour_pos.y < 1: continue
		if neighbour_pos.x >= _image_size.x - 1: continue
		if neighbour_pos.y >= _image_size.y - 1: continue
		
		# Check if neighhour has already been completed
		if cell_is_complete(neighbour_pos):
			continue
		
		var pattern_restrictions: Array[int] = (
			_get_pattern_restrictions_to_neighbour_cell(pos, dir)
		)
		
		# If the restrictions are the full pattern set, then don't worry about it
		if len(pattern_restrictions) == _pixel_patterns.pattern_count():
			continue
		
		neighbour_restrictions[dir] = pattern_restrictions
	
	return neighbour_restrictions

func _get_pattern_restrictions_to_neighbour_cell(pos: Vector2i, dir: Vector2i) -> Array[int]:
	"""Get what restrictions this cell at `pos` will impose on the cell in direction `dir`"""
	# Get the list of patterns left at pos
	var pattern_restrictions: Array[int] = []
	var patterns: Array[int] = get_remaining_patterns_in_cell(pos)
	
	# For each pattern, get the links in dir
	for pattern_index: int in patterns:
		var link_pattern_ids: Array[int] = (
			_pixel_patterns.get_pattern_indices_in_direction(pattern_index, dir)
		)
		merge_pattern_index_arrays_into_superset(pattern_restrictions, link_pattern_ids)
		
	return pattern_restrictions

func get_and_clear_updated_cells() -> Array[Vector2i]:
	"""Return any updated cells since the last time this function was called and clear the buffer"""
	var ret_cells = _updated_cells.duplicate()
	_updated_cells.clear()
	return ret_cells

func get_remaining_patterns_in_cell(pos: Vector2i) -> Array[int]:
	"""Get the patterns available at the x, y position"""
	var cell_index: int = pos.x + (pos.y * _image_size.x)
	return _cells[cell_index].get_remaining_patterns()

func set_specific_pattern_at_cell(pos: Vector2i, pattern_index: int) -> void:
	"""Set a pattern at the given cell position"""
	#print("Setting pattern ", pattern_index, " at pos ", pos)
	
	var cell_index: int = pos.x + (pos.y * _image_size.x)
	_cells[cell_index].set_specific_pattern(pattern_index)
	
	# Need to deal with the consequences
	_propagate_cell_changes(pos)

func cell_is_complete(pos: Vector2i) -> bool:
	var cell_index: int = pos.x + (pos.y * _image_size.x)
	return _cells[cell_index].is_complete()

func _restrict_patterns_at_cell(
	pos: Vector2i, pattern_indices: Array[int], max_depth: int
) -> void:
	var cell_index: int = pos.x + (pos.y * _image_size.x)
	var existing_pattern_count: int = len(_cells[cell_index].get_remaining_patterns())
	
	#var indent: String = ""
	#for _i in (_max_propagation_depth - max_depth):
		#indent += "    "
	
	#print(indent, "pos", pos, " = cell.", cell_index)
	#print(indent, "init pattern count: ", existing_pattern_count)
	_cells[cell_index].restrict_to_patterns(pattern_indices)
	#print(indent, " new pattern count: ", len(_cells[cell_index].get_remaining_patterns()))
	
	# Need to deal with the consequences, if changes were made
	if existing_pattern_count != len(_cells[cell_index].get_remaining_patterns()):
		_propagate_cell_changes(pos, max_depth - 1)
	else:
		# Still want to record that this cell has changes?
		_updated_cells.append(pos)

func put_random_pattern_at_random_position() -> void:
	var pos: Vector2i = Vector2i(
		randi_range(1, _image_size.x - 2),
		randi_range(1, _image_size.y - 2),
	)
	var available_pattern_indices: Array[int] = get_remaining_patterns_in_cell(pos)
	var pattern_index: int = available_pattern_indices[
		randi_range(0, len(available_pattern_indices) - 1)
	]
	
	set_specific_pattern_at_cell(pos, pattern_index)

func put_pattern_at_edge_position(edge_dir: Vector2i, pattern_index: int) -> void:
	# Which position to mess with? First, default to center:
	var pos: Vector2i = _image_size / 2
	# Then, modify to move the pos to the left or right edge
	if edge_dir.x == -1:
		pos.x = 1
	elif edge_dir.x == 1:
		pos.x = _image_size.x - 2
	
	# Then, modify to move the the top or bottom edge
	if edge_dir.y == -1:
		pos.y = 1
	elif edge_dir.y == 1:
		pos.y = _image_size.y - 2
	
	set_specific_pattern_at_cell(pos, pattern_index)

func collapse_next_wave_front_cell() -> void:
	if _wave_front.is_empty():
		return
	
	var pos: Vector2i = _wave_front.pop_front()
	var patterns: Array[int] = get_remaining_patterns_in_cell(pos)
	
	if len(patterns) == 0:
		printerr("Cell at ", pos, " has no viable patterns")
		return
	
	# If only 1 pattern, use it
	var pattern: int = patterns[0]
	# If more than 1 pattern, pick a random one
	if len(patterns) > 1:
		pattern = patterns[randi_range(0, len(patterns) - 1)]
	
	set_specific_pattern_at_cell(pos, pattern)

static func merge_pattern_index_arrays_into_superset(
	target: Array[int], source: Array[int]
) -> void:
	"""Update target to include all target ints, plus any extra ints in source"""
	if target.is_empty():
		source.sort()
		target.append_array(source)
		return
	
	target.sort() # TODO: Might not be necessary
	for pattern_index: int in source:
		var insert_point: int = target.bsearch(pattern_index)
		if insert_point >= len(target):
			target.append(pattern_index)
		elif target[insert_point] != pattern_index:
			target.insert(insert_point, pattern_index)

static func mask_pattern_index_arrays_into_subset(target: Array[int], mask: Array[int]) -> void:
	"""Update target to only include ints that are both in target and mask"""
	var target_values: Array[int] = target.duplicate()
	for value in target_values:
		if value not in mask:
			target.erase(value)

class ImageCell:
	var _possible_pattern_indices: Array[int]
	var _cell_complete: bool = false
	
	func _init(template_pattern_list: Array[int]) -> void:
		_possible_pattern_indices = template_pattern_list.duplicate()
	
	func get_remaining_patterns() -> Array[int]:
		return _possible_pattern_indices
	
	func set_specific_pattern(pattern_index: int) -> void:
		_possible_pattern_indices.clear()
		_possible_pattern_indices.append(pattern_index)
		_cell_complete = true
	
	func restrict_to_patterns(pattern_indices: Array[int]) -> void:
		PatternWave.mask_pattern_index_arrays_into_subset(
			_possible_pattern_indices, pattern_indices
		)
	
	func is_complete() -> bool:
		return _cell_complete
