package intersection

import "core:math/linalg"

import "common:types"

circle_rect :: proc "contextless" (
	circle_position: [2]f32, 
	radius: f32, 
	rect_position: [2]f32, 
	rect_size: types.Size(f32)
) -> bool {
	left := rect_position.x - rect_size.width / 2
	right := rect_position.x + rect_size.width / 2
	bottom := rect_position.y - rect_size.height / 2
	top := rect_position.y + rect_size.height / 2

	closest: [2]f32 = {
		clamp(circle_position.x, left, right),
		clamp(circle_position.y, bottom, top)
	}

	distance := closest - circle_position
	return linalg.vector_length(distance) <= radius
}

circle_circle :: proc "contextless" (
	circle0_position: [2]f32, 
	circle0_radius: f32, 
	circle1_position: [2]f32, 
	circle1_radius: f32
) -> bool {
	distance := linalg.distance(circle0_position, circle1_position)
	return distance < circle0_radius + circle1_radius
}