package intersection

import "core:math"
import "core:math/linalg"

import "common:types"
import common_math "common:math"

circle_rect :: proc "contextless" (
	circle_position: [2]f32, 
	radius: f32, 
	rect_position: [2]f32, 
	rect_size: types.Size(f32),
	rect_rotation: f32 = 0
) -> bool {
	circle_position := rect_position - circle_position

	if rect_rotation != 0 {
		rotation := rect_rotation * math.DEG_PER_RAD
		circle_position = common_math.rotate_vector2(circle_position, -rotation)
	}

	left := -rect_size.width / 2
	right := rect_size.width / 2
	bottom := -rect_size.height / 2
	top := rect_size.height / 2

	closest: [2]f32 = {
		clamp(circle_position.x, left, right),
		clamp(circle_position.y, bottom, top)
	}

	distance := closest - circle_position
	return linalg.vector_length2(distance) <= radius * radius
}

rect_rect :: proc "contextless" (
	rect0_position: [2]f32,
	rect0_size: types.Size(f32),
	rect0_rotation: f32,
	rect1_position: [2]f32,
	rect1_size: types.Size(f32),
	rect1_rotation: f32,
) -> bool {
	if !circle_circle(
		rect0_position, 
		max(rect0_size.width, rect0_size.height), 
		rect1_position, 
		max(rect1_size.width, rect1_size.height)
	) {
		return false
	}
	
	for i in 0..<2 {
		a_position := rect0_position if i == 0 else rect1_position
		a_size     := rect0_size     if i == 0 else rect1_size
		a_rotation := rect0_rotation if i == 0 else rect1_rotation

		b_position := rect1_position if i == 0 else rect0_position
		b_size     := rect1_size     if i == 0 else rect0_size
		b_rotation := rect1_rotation if i == 0 else rect0_rotation

		for x := -1; x < 2; x += 2 {
			for y := -1; y < 2; y += 2 {
				rotated_corner: [2]f32 = { 
					a_size.width / 2 * f32(x), 
					a_size.height / 2 * f32(y) 
				}
	
				if a_rotation != 0 {
					rotated_corner = common_math.rotate_vector2(rotated_corner, a_rotation)
				}
	
				point := a_position + rotated_corner
				if point_rect(point, b_position, b_size, b_rotation) {
					return true
				}
			}
		}
	}

	return false
}

point_rect :: proc "contextless" (
	point: [2]f32, 
	rect_position: [2]f32, 
	rect_size: types.Size(f32),
	rect_rotation: f32,
) -> bool {
	point := rect_position - point

	if rect_rotation != 0 {
		rotation := rect_rotation * math.DEG_PER_RAD
		point = common_math.rotate_vector2(point, -rotation)
	}

	left := -rect_size.width / 2
	right := rect_size.width / 2
	top := rect_size.height / 2
	bottom := -rect_size.height / 2

	return point.x >= left && 
		point.x <= right && 
		point.y >= bottom &&
		point.y <= top
}

circle_circle :: proc "contextless" (
	circle0_position: [2]f32, 
	circle0_radius: f32, 
	circle1_position: [2]f32, 
	circle1_radius: f32
) -> bool {
	distance := linalg.length2(circle0_position - circle1_position)
	return distance <= circle0_radius * circle0_radius + circle1_radius * circle1_radius
}