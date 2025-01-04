class_name PatternLink
extends Node

var _pixel_patterns: Array[Array]
var _pattern_index: int
var _pattern: Array[int]
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

func _init(pixel_patterns: Array[Array], pattern_index: int) -> void:
	_pixel_patterns = pixel_patterns
	_pattern_index = pattern_index
	_pattern = pixel_patterns[pattern_index]
	
	_find_links_in_each_direction()

func _to_string() -> String:
	return "{index}: {links}".format(
		{"index": _pattern_index, "links": _pattern_link_lists}
	)

func _find_links_in_each_direction() -> void:
	# Find the patterns that match in each direction and append them to them to the appropriate lists
	# Can include all patterns in each direction, including this pattern
	for pixel_pattern_index in range(len(_pixel_patterns)):
		var possible_neighbour: Array[int] = _pixel_patterns[pixel_pattern_index]
		# In each direction check that each 4 or 6 pixels overlap exactly
		if _up_left_match(possible_neighbour):
			_pattern_link_lists[Vector2i.UP + Vector2i.LEFT].append(pixel_pattern_index)
		if _up_match(possible_neighbour):
			_pattern_link_lists[Vector2i.UP].append(pixel_pattern_index)
		if _up_right_match(possible_neighbour):
			_pattern_link_lists[Vector2i.UP + Vector2i.RIGHT].append(pixel_pattern_index)
		if _left_match(possible_neighbour):
			_pattern_link_lists[Vector2i.LEFT].append(pixel_pattern_index)
		if _right_match(possible_neighbour):
			_pattern_link_lists[Vector2i.RIGHT].append(pixel_pattern_index)
		if _down_left_match(possible_neighbour):
			_pattern_link_lists[Vector2i.DOWN + Vector2i.LEFT].append(pixel_pattern_index)
		if _down_match(possible_neighbour):
			_pattern_link_lists[Vector2i.DOWN].append(pixel_pattern_index)
		if _down_right_match(possible_neighbour):
			_pattern_link_lists[Vector2i.DOWN + Vector2i.RIGHT].append(pixel_pattern_index)

#region pattern matching

func _up_left_match(other: Array[int]) -> bool:
	return [
		other[4], other[5], other[7], other[8],
	] == [
		_pattern[0], _pattern[1], _pattern[3], _pattern[4],
	]

func _up_match(other: Array[int]) -> bool:
	return [
		other[3], other[4], other[5], other[6], other[7], other[8],
	] == [
		_pattern[0], _pattern[1], _pattern[2], _pattern[3], _pattern[4], _pattern[5],
	]

func _up_right_match(other: Array[int]) -> bool:
	return [
		other[3], other[4], other[6], other[7],
	] == [
		_pattern[1], _pattern[2], _pattern[4], _pattern[5],
	]

func _left_match(other: Array[int]) -> bool:
	return [
		other[1], other[2], other[4], other[5], other[7], other[8],
	] == [
		_pattern[0], _pattern[1], _pattern[3], _pattern[4], _pattern[6], _pattern[7],
	]

func _right_match(other: Array[int]) -> bool:
	return [
		other[0], other[1], other[3], other[4], other[6], other[7],
	] == [
		_pattern[1], _pattern[2], _pattern[4], _pattern[5], _pattern[7], _pattern[8],
	]

func _down_left_match(other: Array[int]) -> bool:
	return [
		other[1], other[2], other[4], other[5],
	] == [
		_pattern[3], _pattern[4], _pattern[6], _pattern[7],
	]

func _down_match(other: Array[int]) -> bool:
	return [
		other[0], other[1], other[2], other[3], other[4], other[5],
	] == [
		_pattern[3], _pattern[4], _pattern[5], _pattern[6], _pattern[7], _pattern[8],
	]

func _down_right_match(other: Array[int]) -> bool:
	return [
		other[0], other[1], other[3], other[4],
	] == [
		_pattern[4], _pattern[5], _pattern[7], _pattern[8],
	]

#endregion
