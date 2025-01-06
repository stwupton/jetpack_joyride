package renderer

import "core:fmt"
import "core:strings"
import "core:math/linalg"

import gl "vendor:OpenGL"
import "vendor:sdl2"

import "common:types"

import "jetpack_joyride:assets"
import "jetpack_joyride:properties"

Renderer :: struct {
	generic_vertex_array: u32,
	shape_shader: Shape_Shader_Program,
	cached_window_size: types.Size(i32)
}

Shape_Shader_Program :: struct {
	id: u32,
	uniform_location: struct {
		view_projection: i32,
		transform: i32,
		colour: i32
	}
}

init :: proc(renderer: ^Renderer) {
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	
	gl.ClearColor(0, 0, 0, 1)

	init_vertex_array(renderer)
	init_shape_shader(renderer)
	init_view_projection(renderer)
}

render :: proc(using renderer: ^Renderer, window_size: types.Size(i32)) {
	set_viewport(renderer, window_size)

	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	gl.UseProgram(shape_shader.id)
	gl.BindVertexArray(generic_vertex_array)
	colour: [4]f32 = { 0, 0, 1, 1 }
	transform := linalg.MATRIX4F32_IDENTITY
	scale_transform := linalg.matrix4_scale(linalg.Vector3f32 { 400, 400, 0 })
	transform *= scale_transform

	gl.Uniform4fv(shape_shader.uniform_location.colour, 1, &colour[0])
	gl.UniformMatrix4fv(shape_shader.uniform_location.transform, 1, false, &transform[0][0])

	gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
}

@private
init_shader :: proc(shader: assets.Shader) -> (shader_id: u32) {
	vertex_contents := assets.load_shader(shader, assets.Shader_Type.vertex)
	vertex_contents_cstr := cstring(raw_data(vertex_contents))
	vertex_shader := gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(vertex_shader, 1, &vertex_contents_cstr, nil)
	gl.CompileShader(vertex_shader);

	fragment_contents := assets.load_shader(shader, assets.Shader_Type.fragment)
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
init_shape_shader :: proc(using renderer: ^Renderer) {
	shape_shader.id = init_shader(.shape)
	shape_shader.uniform_location.view_projection = gl.GetUniformLocation(shape_shader.id, "view_projection")
	shape_shader.uniform_location.transform = gl.GetUniformLocation(shape_shader.id, "transform")
	shape_shader.uniform_location.colour = gl.GetUniformLocation(shape_shader.id, "colour")
}

@private 
init_view_projection :: proc(using renderer: ^Renderer) {
	left := -f32(properties.view_size.width) / 2
	right := f32(properties.view_size.width) / 2
	bottom := -f32(properties.view_size.height) / 2
	top := f32(properties.view_size.height) / 2
	near: f32 = -1
	far: f32 = 1
	projection := linalg.matrix_ortho3d_f32(left, right, bottom, top, near, far)

	gl.UseProgram(shape_shader.id)
	gl.UniformMatrix4fv(shape_shader.uniform_location.view_projection, 1, false, &projection[0][0])
}

@private 
init_vertex_array :: proc(renderer: ^Renderer) {
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
set_viewport :: proc(using renderer: ^Renderer, window_size: types.Size(i32)) {
	if window_size == cached_window_size {
		return 
	} else {
		cached_window_size = window_size
	}

	window_aspect_ratio := f32(window_size.width) / f32(window_size.height)
	view_aspect_ratio := f32(properties.view_size.width) / f32(properties.view_size.height)

	viewport_size: types.Size(i32)

	snape_to_height: bool = window_aspect_ratio > view_aspect_ratio
	if snape_to_height {
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