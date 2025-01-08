package assets

import "core:c"
import "core:fmt"
import "core:mem"
import "core:strings"

import plat "jetpack_joyride:platform"

Shader :: enum {
	shape,
	base
}

Shader_Type :: enum u8 {
	vertex,
	fragment
}

load_shader :: proc(platform: plat.Platform, shader: Shader, type: Shader_Type) -> string {
	extension := "vert" if type == .vertex else "frag"
	shader_name := shader_files[shader]	

	shader_path := strings.concatenate({ "/assets/shaders/", shader_name, ".", extension })
	defer delete(shader_path)
	
	contents := platform.read_file(shader_path, context.temp_allocator)
	
	return contents
}

@private 
shader_files := [Shader]string {
	.shape = "shape",
	.base = "base",
}