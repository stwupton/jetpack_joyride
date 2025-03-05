#version 330 core

uniform vec4 color;
uniform int shape_type; // 0 = rect, 1 = circle

in vec3 _position;

out vec4 result_color;

void main() {
	if (shape_type == 0) {
		result_color = color;
	} else {
		bool is_circle = length(_position) <= 0.5;
		result_color = color * float(is_circle);
	}
}