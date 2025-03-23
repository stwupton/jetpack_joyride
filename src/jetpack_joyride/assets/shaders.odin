package assets

import "core:c"
import "core:fmt"
import "core:mem"
import "core:strings"

import common_platform "common:platform"

Shader_ID :: enum {
	shape,
	basic
}

Shader_Type :: enum u8 {
	vertex,
	fragment
}

load_shader :: proc(platform: common_platform.Platform, shader: Shader_ID, type: Shader_Type) -> string {
	extension := "vert" if type == .vertex else "frag"
	shader_name := shader_files[shader]	

	shader_path := strings.concatenate({ "shaders/", shader_name, ".", extension })
	defer delete(shader_path)
	
	contents := platform.read_asset_file(platform, shader_path)
	
	return contents
}

@private 
shader_files := [Shader_ID]string {
	.shape = "shape",
	.basic = "basic",
}