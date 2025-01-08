package opengl_renderer

import "core:fmt"
import "core:strings"
import "core:math/linalg"

import gl "vendor:OpenGL"
import stbi "vendor:stb/image"

import "common:types"

import "jetpack_joyride:assets"
import "jetpack_joyride:properties"
import plat "jetpack_joyride:platform"

Renderer :: struct {
	generic_vertex_array: u32,
	shape_shader: Shape_Shader_Program,
	basic_shader: Basic_Shader_Program,
	cached_window_size: types.Size(i32),
	loaded_textures: [assets.Texture_ID]Texture_Details
}

Shape_Shader_Program :: struct {
	id: u32,
	uniform_location: struct {
		view_projection: i32,
		transform: i32,
		colour: i32
	}
}

Basic_Shader_Program :: struct {
	id: u32,
	uniform_location: struct {
		view_projection: i32,
		transform: i32
	}
}

Texture_Details :: struct {
	id: u32,
	width, height: i32
}

init :: proc(renderer: ^Renderer, platform: plat.Platform) {
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	
	gl.ClearColor(0, 0, 0, 1)

	init_vertex_array(renderer)
	init_shape_shader(renderer, platform)
	init_basic_shader(renderer, platform)
	init_view_projection(renderer)
	
	load_all_textures(renderer, platform)
}

render :: proc "contextless" (using renderer: ^Renderer, window_size: types.Size(i32)) {
	set_viewport(renderer, window_size)

	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	// Cloud
	gl.UseProgram(basic_shader.id)
	gl.BindVertexArray(generic_vertex_array)
	texture := loaded_textures[.cloud1]
	gl.BindTexture(gl.TEXTURE_2D, texture.id)
	scale_transform := linalg.MATRIX4F32_IDENTITY * linalg.matrix4_scale(linalg.Vector3f32 { f32(texture.width), f32(texture.height), 1 } * 4)
	gl.UniformMatrix4fv(basic_shader.uniform_location.transform, 1, false, &scale_transform[0][0])
	gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
}

@private
init_shader :: proc(platform: plat.Platform, shader: assets.Shader_ID) -> (shader_id: u32) {
	vertex_contents := assets.load_shader(platform, shader, .vertex)
	vertex_contents_cstr := cstring(raw_data(vertex_contents))
	vertex_shader := gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(vertex_shader, 1, &vertex_contents_cstr, nil)
	gl.CompileShader(vertex_shader);

	fragment_contents := assets.load_shader(platform, shader, .fragment)
	fragment_contents_cstr := cstring(raw_data(fragment_contents))
	fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(fragment_shader, 1, &fragment_contents_cstr, nil)
	gl.CompileShader(fragment_shader)

	shader_id = gl.CreateProgram()
	gl.AttachShader(shader_id, vertex_shader)
	gl.AttachShader(shader_id, fragment_shader)
	gl.LinkProgram(shader_id)
	gl.UseProgram(shader_id)

	return
}

@private 
init_shape_shader :: proc(renderer: ^Renderer, platform: plat.Platform) {
	renderer.shape_shader.id = init_shader(platform, .shape)
	renderer.shape_shader.uniform_location.view_projection = gl.GetUniformLocation(renderer.shape_shader.id, "view_projection")
	renderer.shape_shader.uniform_location.transform = gl.GetUniformLocation(renderer.shape_shader.id, "transform")
	renderer.shape_shader.uniform_location.colour = gl.GetUniformLocation(renderer.shape_shader.id, "colour")
}

@private 
init_basic_shader :: proc(renderer: ^Renderer, platform: plat.Platform) {
	renderer.basic_shader.id = init_shader(platform, .basic)
	renderer.basic_shader.uniform_location.view_projection = gl.GetUniformLocation(renderer.basic_shader.id, "view_projection")
	renderer.basic_shader.uniform_location.transform = gl.GetUniformLocation(renderer.basic_shader.id, "transform")
}

@private 
init_view_projection :: proc "contextless" (using renderer: ^Renderer) {
	left := -f32(properties.view_size.width) / 2
	right := f32(properties.view_size.width) / 2
	bottom := -f32(properties.view_size.height) / 2
	top := f32(properties.view_size.height) / 2
	near: f32 = -1
	far: f32 = 1
	projection := linalg.matrix_ortho3d_f32(left, right, bottom, top, near, far)

	gl.UseProgram(shape_shader.id)
	gl.UniformMatrix4fv(shape_shader.uniform_location.view_projection, 1, false, &projection[0][0])
	
	gl.UseProgram(basic_shader.id)
	gl.UniformMatrix4fv(basic_shader.uniform_location.view_projection, 1, false, &projection[0][0])
}

@private 
init_vertex_array :: proc "contextless" (renderer: ^Renderer) {
	// Create generic vertex array object
	gl.GenVertexArrays(1, &renderer.generic_vertex_array)
	gl.BindVertexArray(renderer.generic_vertex_array)

	// Create buffer array object
	// Data: x, y, z, s, t
	// Must draw counter clockwise to face forward
	generic_vertices := [?]f32 {
		-0.5, 0.5, 0.0, 0.0, 0.0,
		-0.5, -0.5, 0.0, 0.0, 1.0, 
		0.5, 0.5, 0.0, 1.0, 0.0,
		0.5, -0.5, 0.0, 1.0, 1.0
	}

	generic_vertex_buffer: u32
	gl.GenBuffers(1, &generic_vertex_buffer)
	gl.BindBuffer(gl.ARRAY_BUFFER, generic_vertex_buffer)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(generic_vertices), &generic_vertices, gl.STATIC_DRAW)

	// Setup generic vertex attributes
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, 5 * size_of(f32), 0)
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1, 2, gl.FLOAT, false, 5 * size_of(f32), 3 * size_of(f32))
}

@private
load_all_textures :: proc(renderer: ^Renderer, platform: plat.Platform) {
	texture_ids := [assets.Texture_ID]u32 {}
	gl.GenTextures(len(texture_ids), &texture_ids[assets.Texture_ID(0)])

	for texture_id in assets.Texture_ID {
		texture_data := assets.load_texture_data(platform, texture_id)
		width, height, channels_in_file: i32
		texture_bytes := stbi.load_from_memory(
			raw_data(texture_data), 
			i32(len(texture_data)), 
			&width, 
			&height, 
			&channels_in_file, 
			4
		)
		assert(texture_bytes != nil)

		load_texture(texture_ids[texture_id], texture_bytes, width, height)
		renderer.loaded_textures[texture_id] = {
			id = texture_ids[texture_id],
			width = width, 
			height = height
		}
	}
}

@private
load_texture :: proc(id: u32, bytes: [^]byte, width: i32, height: i32) {
	gl.BindTexture(gl.TEXTURE_2D, id)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, bytes)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
}

@private 
set_viewport :: proc "contextless" (using renderer: ^Renderer, window_size: types.Size(i32)) {
	if window_size == cached_window_size do return
	cached_window_size = window_size

	window_aspect_ratio := f32(window_size.width) / f32(window_size.height)
	view_aspect_ratio := f32(properties.view_size.width) / f32(properties.view_size.height)

	viewport_size: types.Size(i32)

	snap_to_height: bool = window_aspect_ratio > view_aspect_ratio
	if snap_to_height {
		viewport_size.height = window_size.height
		viewport_size.width = i32(f32(viewport_size.height) * view_aspect_ratio)
	} else {
		viewport_size.width = window_size.width
		viewport_size.height = i32(f32(viewport_size.width) / view_aspect_ratio)
	}

	viewport_position := [2]i32 {
		window_size.width / 2 - viewport_size.width / 2,	
		window_size.height / 2 - viewport_size.height / 2	
	}

	gl.Viewport(
		viewport_position.x, 
		viewport_position.y, 
		viewport_size.width, 
		viewport_size.height
	)
}