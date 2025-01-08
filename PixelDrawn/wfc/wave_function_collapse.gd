extends TextureRect

const MID_PATTERN_PIXEL: int = 4

@export var input_sample: Texture2D
@export var rotations: bool = false
@export var reflections: bool = false
@export var max_propagation_depth: int = 10

@onready var output: Texture2D = texture

var pixel_patterns: PixelPatterns
var pattern_wave: PatternWave
var output_image: Image

var debug: bool = true
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
	
	pixel_patterns = PixelPatterns.new(input_sample, rotations, reflections)
	
	if debug:
		pixel_patterns.print_color_indices_to_stdout()
		pixel_patterns.create_and_save_debug_pattern_image()
		pixel_patterns.create_and_save_debug_linkage_table()
	
	# Prepare the output
	output_image = Image.create_empty(texture.get_width(), texture.get_height(), false, input_sample.get_image().get_format())
	
	# Setup an initial front
	pattern_wave = PatternWave.new(texture.get_size(), pixel_patterns, max_propagation_depth)
	
	# If we check for corner or edge bound patterns, we can set up an initial pattern
	var edge_bound_pattern_indices: Dictionary = pixel_patterns.find_edge_only_linked_pattern_indices()
	print(edge_bound_pattern_indices)
	
	# Just do this for 1 tile
	for dir: Vector2i in edge_bound_pattern_indices:
		var edge_pattern_list: Array[int]
		edge_pattern_list.assign(edge_bound_pattern_indices[dir])
		if not edge_pattern_list.is_empty():
			var rand_index: int = randi_range(0, len(edge_pattern_list) - 1)
			pattern_wave.put_pattern_at_edge_position(dir, edge_pattern_list[rand_index])
			break
	
	_update_output_image_from_latest_changes()


func _process(_delta: float) -> void:
	pattern_wave.collapse_next_wave_front_cell()
	
	_update_output_image_from_latest_changes()

#region output update

func _update_output_image_from_latest_changes() -> void:
	for cell_pos: Vector2i in pattern_wave.get_and_clear_updated_cells():
		var pixel_pattern_array: Array[int] = pattern_wave.get_remaining_patterns_in_cell(cell_pos)
		output_image.set_pixelv(cell_pos, _get_potential_color_result(pixel_pattern_array))
	
	texture = ImageTexture.create_from_image(output_image)

func _get_potential_color_result(pattern_indices: Array[int]) -> Color:
	if len(pattern_indices) < 1:
		printerr("No patterns to average!")
	
	if len(pattern_indices) == 1:
		var pattern_middle_color_index: int = (
			pixel_patterns.get_pattern_color_index_by_pos_index(
				pattern_indices[0], MID_PATTERN_PIXEL
			)
		)
		return pixel_patterns.get_color_by_index(pattern_middle_color_index)
	
	var color_count: int = len(pattern_indices)
	var color_vector: Vector4 = Vector4.ZERO
	for pattern_index in range(len(pattern_indices)):
		var pattern_middle_color_index: int = (
			pixel_patterns.get_pattern_color_index_by_pos_index(
				pattern_index, MID_PATTERN_PIXEL
			)
		)
		var color = pixel_patterns.get_color_by_index(pattern_middle_color_index)
		color_vector += Vector4(color.r, color.g, color.b, color.a)
	
	color_vector /= color_count
	return Color(color_vector.x, color_vector.y, color_vector.z, color_vector.w)

#endregion

#region collapsing to a pattern

#
#func _update_wavefront_insert_index(index: int) -> void:
	## If already in wavefront, remove it from it's current position
	#if index in wave_front:
		#wave_front.erase(index)
	#
	## If the pattern at index only has one option already, don't add to the list
	#if len(image_wave[index]) <= 1:
		#return
	#
	## Find the right position to insert the index in the wavefront
	## The list should be sorted by fewest available patterns in `image_wave`
	#
	#var insertion_index: int = wave_front.bsearch_custom(
		#index,
		#func (a, b) -> bool:
			#return len(image_wave[a]) < len(image_wave[b])
	#)
	#wave_front.insert(insertion_index, index)
#
#endregion
