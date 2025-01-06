package assets

import "core:c"
import "core:fmt"
import "core:mem"
import "core:strings"

import "vendor:sdl2"

Shader :: enum {
	shape,
	base
}

Shader_Type :: enum u8 {
	vertex,
	fragment
}

load_shader :: proc(shader: Shader, type: Shader_Type) -> string {
	extension := "vert" if type == .vertex else "frag"
	shader_name := shader_files[shader]
	
	asset_path := strings.concatenate({ base_path, "/assets/shaders/" }, context.temp_allocator)
	shader_path := strings.concatenate({ asset_path, shader_name, ".", extension }, context.temp_allocator)
	
	file: ^sdl2.RWops = sdl2.RWFromFile(cstring(raw_data(shader_path)), "r")
	defer sdl2.RWclose(file)
	
	file_size := sdl2.RWsize(file)
	contents := make([]u8, file_size, context.temp_allocator)
	sdl2.RWread(file, &contents[0], size_of(u8), c.size_t(file_size))
	
	return string(contents)
}

@private
base_path := string(sdl2.GetBasePath())

@private 
shader_files := map[Shader]string {
	.shape = "shape",
	.base = "base",
}