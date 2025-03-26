package common_math

import "core:math"

rotate_vector2 :: proc "contextless" (vector: [2]$T, angle_deg: T) -> [2]T {
	return {
		vector.x * math.cos(angle_deg) - vector.y * math.sin(angle_deg),
		vector.x * math.sin(angle_deg) + vector.y * math.cos(angle_deg)
	}
}