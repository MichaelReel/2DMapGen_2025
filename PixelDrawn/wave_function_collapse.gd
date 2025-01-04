extends TextureRect

const MID_PATTERN_PIXEL: int = 4

@export var input_sample: Texture2D
@export var rotations: bool = false
@export var reflections: bool = false

@onready var output: Texture2D = texture

var color_indices: Array[Color] = []

var pixel_patterns: Array[Array]
var image_wave: Array[Array]
var output_image: Image
var wave_front: Array[int] = []
var final_print: bool = false


#region doc
# Algorithm
# ---------
#     1. Read the input bitmap and count NxN patterns.
#         i. (optional) Augment pattern data with rotations and reflections.
#     2. Create an array with the dimensions of the output (called "wave" in the source). 
#        Each element of this array represents a state of an NxN region in the output. 
#        A state of an NxN region is a superposition of NxN patterns of the input with boolean 
#        coefficients (so a state of a pixel in the output is a superposition of input colors with 
#        real coefficients). False coefficient means that the corresponding pattern is forbidden,
#        true coefficient means that the corresponding pattern is not yet forbidden.
#     3. Initialize the wave in the completely unobserved state, i.e. with all the boolean
#        coefficients being true.
#     4. Repeat the following steps:
#         i. Observation:
#             a. Find a wave element with the minimal nonzero entropy. If there is no such elements
#                (if all elements have zero or undefined entropy) then break the cycle (4) and go 
#                to step (5).
#             b. Collapse this element into a definite state according to its coefficients and the
#                distribution of NxN patterns in the input.
#         ii. Propagation: propagate information gained on the previous observation step.
#     5. By now all the wave elements are either in a completely observed state (all the
#        coefficients except one being zero) or in the contradictory state (all the coefficients
#        being zero). In the first case return the output. In the second case finish the work
#        without returning anything.
#endregion

func _ready() -> void:
	if not input_sample:
		printerr("input_sample required")
	
	# create the 3x3 pixel patterns from the input_sample
	pixel_patterns = _get_3x3_pixel_patterns(input_sample)
	
	# Optionally augment patterns with rotations
	if rotations:
		pixel_patterns = _strip_duplicate_patterns(pixel_patterns)
		pixel_patterns.append_array(_get_patterns_rotations(pixel_patterns))
	
	# Optionally augment patterns with reflections
	if reflections:
		pixel_patterns = _strip_duplicate_patterns(pixel_patterns)
		pixel_patterns.append_array(_get_patterns_reflections(pixel_patterns))
	
	# Strip any duplicate patterns
	pixel_patterns = _strip_duplicate_patterns(pixel_patterns)
	
	print(color_indices)
	#print(len(pixel_patterns), " pixel patterns")
	print(pixel_patterns)
	
	# Prepare the output
	var template_cell: Array[int] = []
	for index in len(pixel_patterns):
		template_cell.append(index)
	
	image_wave = []
	for _index in range(texture.get_width() * texture.get_height()):
		image_wave.append(template_cell.duplicate())
	
	#print(len(image_wave))
	output_image = Image.create_empty(texture.get_width(), texture.get_height(), false, input_sample.get_image().get_format())
	
	# Setup an initial front
	var random_wave_index: int = randi_range(0, len(image_wave))
	# Collapse element to a definite state
	#print(random_wave_index)
	_collapse_by_wave_index(random_wave_index)
	
	#print(wave_front)

func _process(delta: float) -> void:
	var a_t: float = Time.get_unix_time_from_system()
	if len(wave_front) <= 0:
		# some debug from the last run
		if not final_print:
			#print(image_wave.map(func (pattern_list: Array[int]) -> int: return len(pattern_list)))
			#print(image_wave.map(func (pattern_list: Array[int]) -> int: return -1 if pattern_list.is_empty() else pattern_list[0]))
			#print(image_wave.map(
				#func (pattern_list: Array[int]) -> int:
					#return -1 if pattern_list.is_empty() else (
						#pixel_patterns[pattern_list[0]][MID_PATTERN_PIXEL]
					#) 
			#))
			final_print = true
			
		return
	
	var next_image_wave_index: int = wave_front.front()
	
	#print(next_image_wave_index)
	
	_collapse_by_wave_index(next_image_wave_index)
	#print(wave_front)
	
	var b_t: float = Time.get_unix_time_from_system()
	
	# Set image output by current wave potentials
	# TODO: Only update the changed pixel!
	var y: int = next_image_wave_index / output_image.get_width()
	var x: int = next_image_wave_index % output_image.get_width()
	var pixel_pattern_array: Array[int] = image_wave[next_image_wave_index]
	output_image.set_pixel(x, y, _get_potential_color_result(pixel_pattern_array))
	
	#for y in output_image.get_height():
		#for x in output_image.get_width():
			#var wave_index: int = y * output_image.get_width() + x
			#var pixel_pattern_array: Array[int] = image_wave[wave_index]
			#output_image.set_pixel(x, y, _get_potential_color_result(pixel_pattern_array))
	
	var c_t: float = Time.get_unix_time_from_system()
	
	texture = ImageTexture.create_from_image(output_image)
	
	var d_t: float = Time.get_unix_time_from_system()
	
	#print("a: ", (b_t - a_t), ", b: ", (c_t - b_t), ", c: ", (d_t - c_t), ", delta: ", delta)

func _get_3x3_pixel_patterns(sample: Texture2D) -> Array[Array]:
	var patterns: Array[Array] = []
	
	var image : Image = sample.get_image()
	for p_y in range(1, image.get_height() - 1):
		for p_x in range(1, image.get_width() - 1):
			var pattern: Array[int] = _get_3x3_colors_centered_at(image, p_x, p_y)
			patterns.append(pattern)
	
	return patterns

func _get_3x3_colors_centered_at(image: Image, p_x: int, p_y: int) -> Array[int]:
	var pattern: Array[int] = []
	for y in range(p_y - 1, p_y + 2):
		for x in range(p_x - 1, p_x + 2):
			var color_index: int = _get_indexed_color(image.get_pixel(x, y))
			pattern.append(color_index)
	
	return pattern

func _get_indexed_color(color: Color) -> int:
	var index = color_indices.find(color)
	if index >= 0:
		return index
	
	color_indices.append(color)
	return color_indices.size() - 1

func _strip_duplicate_patterns(patterns) -> Array[Array]:
	var unique_patterns: Array[Array] = []
	for index in range(len(patterns)):
		if patterns.find(patterns[index]) == index:
			unique_patterns.append(patterns[index])
	
	return unique_patterns

func _get_patterns_rotations(patterns) -> Array[Array]:
	var rotation_patterns: Array[Array] = []
	for pixel_pattern in patterns:
		rotation_patterns.append_array(_get_pattern_rotations(pixel_pattern))
	
	return rotation_patterns

func _get_pattern_rotations(pixel_pattern: Array[int]) -> Array[Array]:
	var pattern_rotations: Array[Array] = []
	pattern_rotations.append(_rotate_90(pixel_pattern))
	pattern_rotations.append(_rotate_180(pixel_pattern))
	pattern_rotations.append(_rotate_270(pixel_pattern))
	
	return pattern_rotations

func _rotate_270(pixel_pattern: Array[int]) -> Array[int]:
	return [
		pixel_pattern[2], pixel_pattern[5], pixel_pattern[8],
		pixel_pattern[1], pixel_pattern[4], pixel_pattern[7],
		pixel_pattern[0], pixel_pattern[3], pixel_pattern[6],
	]

func _rotate_180(pixel_pattern: Array[int]) -> Array[int]:
	return [
		pixel_pattern[8], pixel_pattern[7], pixel_pattern[6],
		pixel_pattern[5], pixel_pattern[4], pixel_pattern[3],
		pixel_pattern[2], pixel_pattern[1], pixel_pattern[0],
	]

func _rotate_90(pixel_pattern: Array[int]) -> Array[int]:
	return [
		pixel_pattern[6], pixel_pattern[3], pixel_pattern[0],
		pixel_pattern[7], pixel_pattern[4], pixel_pattern[1],
		pixel_pattern[8], pixel_pattern[5], pixel_pattern[2],
	]

func _get_patterns_reflections(patterns) -> Array[Array]:
	var rotation_patterns: Array[Array] = []
	for pixel_pattern in patterns:
		rotation_patterns.append_array(_get_pattern_reflections(pixel_pattern))
	
	return rotation_patterns

func _get_pattern_reflections(pixel_pattern: Array[int]) -> Array[Array]:
	var pattern_reflections: Array[Array] = []
	pattern_reflections.append(_flip_hortz(pixel_pattern))
	pattern_reflections.append(_flip_vert(pixel_pattern))
	
	return pattern_reflections

func _flip_hortz(pixel_pattern: Array[int]) -> Array[int]:
	return [
		pixel_pattern[2], pixel_pattern[1], pixel_pattern[0],
		pixel_pattern[5], pixel_pattern[4], pixel_pattern[3],
		pixel_pattern[8], pixel_pattern[7], pixel_pattern[6],
	]

func _flip_vert(pixel_pattern: Array[int]) -> Array[int]:
	return [
		pixel_pattern[6], pixel_pattern[7], pixel_pattern[8],
		pixel_pattern[3], pixel_pattern[4], pixel_pattern[5],
		pixel_pattern[0], pixel_pattern[1], pixel_pattern[2],
	]

func _get_potential_color_result(pattern_indices: Array[int]) -> Color:
	if len(pattern_indices) < 1:
		printerr("No patterns to average!")
	
	var color_count: int = len(pattern_indices)
	var color_vector: Vector4 = Vector4.ZERO
	for pattern_index in pattern_indices:
		var pattern_middle_color_index: int = pixel_patterns[pattern_index][MID_PATTERN_PIXEL]
		var color = color_indices[pattern_middle_color_index]
		color_vector += Vector4(color.r, color.g, color.b, color.a)
	
	color_vector /= color_count
	return Color(color_vector.x, color_vector.y, color_vector.z, color_vector.w)

func _collapse_by_wave_index(index: int) -> void:
	if index in wave_front:
		wave_front.erase(index)
	
	# We should make sure to remove any patterns that can't fit with the current surrounding tile
	_reduce_patterns_by_the_adjacent_possible_patterns(index)
	
	# Pick a possible tile
	var pattern_index: int = randi_range(0, len(image_wave[index]))
	
	# commit to pattern
	var pattern_array: Array[int] = [pattern_index]
	image_wave[index] = pattern_array
	
	# update around the perimeter
	var neighbour_indices: Array[int] = _reduce_surrounding_pattern_lists(index)
	
	# update wavefront
	for neighbour_index: int in neighbour_indices:
		_update_wavefront_insert_index(neighbour_index)

func _reduce_patterns_by_the_adjacent_possible_patterns(index: int) -> void:
	"""Check through the possible patterns and remove any that won't fit with surrounding patterns"""
	var pattern_list: Array[int] = image_wave[index]
	# Look in the cells around for restrictions
	for y in range(-1, 2):
		for x in range(-1, 2):
			# Skip the index itself
			if x == 0 and y == 0: continue
			
			var neighbour_index: int = index + (y * output_image.get_width()) + x
			# Check for edges
			if neighbour_index < 0 or neighbour_index >= len(image_wave): continue
			if x == -1 and index % output_image.get_width() == 0: continue
			if x == 1 and neighbour_index % output_image.get_width() == 0: continue
				
			if len(pattern_list) <= 0:
				printerr("No viable patterns left at index ", index)
				continue
			
			var neighbour_in_pattern: int = 4 + x + (y * 3)
			var neighbour_possible_color_ids: Array = image_wave[neighbour_index].map(
				func (pattern_index: int) -> int: return pixel_patterns[pattern_index][MID_PATTERN_PIXEL]
			)
			var updated_pattern_list: Array[int] = []
			
			# Keep only patterns that will fit this space
			for pattern_index: int in pattern_list:
				var pattern: Array[int] = pixel_patterns[pattern_index]
				if pattern[neighbour_in_pattern] in neighbour_possible_color_ids:
					updated_pattern_list.append(pattern_index)
			
			# Update for the next neighbour
			pattern_list = updated_pattern_list
	
	# Record the newly limited patterns in the wave
	image_wave[index] = pattern_list

func _reduce_surrounding_pattern_lists(index: int) -> Array[int]:
	"""For each surrounding cell in the output, reduce the available patterns"""
	
	# Assuming that there is only 1 pattern in the list of patterns
	var pattern_list: Array[int] = image_wave[index]
	if len(pattern_list) != 1:
		printerr("Should be 1 pattern in position ", index, ", but got: ", pattern_list)
	
	var pixel_pattern: Array[int] = pixel_patterns[pattern_list[0]]
	var origin_pixel_color_index: int = pixel_pattern[MID_PATTERN_PIXEL]
	
	# The index itself should be in view okay, but might be on an edge
	var updated_indices: Array[int] = []
	for y in range(-1, 2):
		for x in range(-1, 2):
			var neighbour_index: int = index + (y * output_image.get_width()) + x
			
			# Skip the index itself
			if x == 0 and y == 0: continue
			# Check for edges, Skip top or bottom
			if neighbour_index < 0 or neighbour_index >= len(image_wave): continue
			# Skip left
			if x == -1 and index % output_image.get_width() == 0: continue
			# Skip right
			if x == 1 and neighbour_index % output_image.get_width() == 0: continue
			# Skip neighbours that are already reduced to 1 (or no) pattern
			if len(image_wave[neighbour_index]) <= 1:
				continue
			
			updated_indices.append(neighbour_index)
			var pattern_pos_of_origin_relative_to_neighbour: int = (
				4 - x - (y * 3)
			)
			_reduce_patterns_by_color_index_in_pattern_pos(
				neighbour_index,
				origin_pixel_color_index,
				pattern_pos_of_origin_relative_to_neighbour,
			)
	
	return updated_indices

func _reduce_patterns_by_color_index_in_pattern_pos(index: int, color: int, pos: int) -> void:
	var orig_pattern_list: Array[int] = image_wave[index]
	var new_pattern_list: Array[int] = []
	
	for pattern_index: int in orig_pattern_list:
		var pattern : Array[int] = pixel_patterns[pattern_index]
		if pattern[pos] == color:
			new_pattern_list.append(pattern_index)
	
	image_wave[index] = new_pattern_list

func _update_wavefront_insert_index(index: int) -> void:
	# If already in wavefront, remove it from it's current position
	if index in wave_front:
		wave_front.erase(index)
	
	# If the pattern at index only has one option already, don't add to the list
	if len(image_wave[index]) <= 1:
		return
	
	# Find the right position to insert the index in the wavefront
	# The list should be sorted by fewest available patterns in `image_wave`
	
	var insertion_index: int = wave_front.bsearch_custom(
		index,
		func (a, b) -> bool:
			return len(image_wave[a]) < len(image_wave[b])
	)
	wave_front.insert(insertion_index, index)
