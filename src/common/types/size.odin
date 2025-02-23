package common

import "core:math/linalg"

Size :: struct($T: typeid) {
	width: T,
	height: T
}

size_to_vector2 :: proc "contextless" (size: Size($T)) -> [2]T {
	return { size.width, size.height }
}