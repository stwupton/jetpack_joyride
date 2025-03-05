package opengl_renderer

import "core:container/small_array"
import "core:fmt"
import "core:math/linalg"
import "core:strings"

import gl "vendor:OpenGL"
import stbi "vendor:stb/image"

import "common:types"

import "jetpack_joyride:assets"
import plat "jetpack_joyride:platform"
import "jetpack_joyride:properties"
import common "jetpack_joyride:renderer"

Renderer :: struct {
	ortho_projection: linalg.Matrix4f32,
	vertex_array: u32,
	shape_shader: Shape_Shader_Program,
	basic_shader: Basic_Shader_Program,
	window_size: types.Size(i32),
	textures: Textures
}

@private
Textures :: [assets.Texture_ID]u32

@private
Shape_Shader_Program :: struct {
	id: u32,
	uniform_location: struct {
		view_projection: i32,
		transform: i32,
		color: i32,
		shape_type: i32,
	}
}

@private
Basic_Shader_Program :: struct {
	id: u32,
	uniform_location: struct {
		view_projection: i32,
		transform: i32
	}
}

init :: proc(renderer: ^Renderer, platform: plat.Platform, layer_count: u8) {
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	// Enable depth testing with LEQUAL. This means that depth testing works but when
	// the Z positions are the same, the rendering order determines what appears on 
	// top. So the last thing drawn will be visible. 
	gl.Enable(gl.DEPTH_TEST)
	gl.DepthFunc(gl.LEQUAL)
	
	gl.ClearColor(0, 0, 0, 1)

	renderer.vertex_array = create_vertex_array()
	renderer.shape_shader = create_shape_shader(platform)
	renderer.basic_shader = create_basic_shader(platform)
	renderer.ortho_projection = create_ortho_projection(layer_count)

	// Set the view projection uniform on all shaders as this should only need to 
	// be done once.
	{
		gl.UseProgram(renderer.shape_shader.id)
		gl.UniformMatrix4fv(
			renderer.shape_shader.uniform_location.view_projection, 
			1, 
			false, 
			&renderer.ortho_projection[0][0]
		)

		gl.UseProgram(renderer.basic_shader.id)
		gl.UniformMatrix4fv(
			renderer.basic_shader.uniform_location.view_projection, 
			1, 
			false, 
			&renderer.ortho_projection[0][0]
		)
	}

	load_all_textures(&renderer.textures, platform)
}

render :: proc "contextless" (
	renderer: ^Renderer, 
	frame: common.Frame, 
	window_size: types.Size(i32)
) {
	if window_size != renderer.window_size {
		set_viewport(window_size)
		renderer.window_size = window_size
	}

	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
	
	gl.UseProgram(renderer.basic_shader.id)
	gl.BindVertexArray(renderer.vertex_array)
	cached_texture := assets.Texture_ID.none
	for i in 0..<frame.images.len {
		image := frame.images.data[i]

		texture_index := renderer.textures[image.texture]
		texture_size := assets.texture_sizes[image.texture]

		if image.texture != cached_texture {
			gl.BindTexture(gl.TEXTURE_2D, texture_index)
			cached_texture = image.texture
		}

		gl.UniformMatrix4fv(
			renderer.basic_shader.uniform_location.transform, 
			1, 
			false, 
			&image.transform[0][0]
		)
		gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
	}

	gl.UseProgram(renderer.shape_shader.id)
	gl.BindVertexArray(renderer.vertex_array)
	for i in 0..<frame.shapes.len {
		shape := frame.shapes.data[i]
		gl.Uniform4fv(renderer.shape_shader.uniform_location.color, 1, &shape.color[0])
		gl.Uniform1i(renderer.shape_shader.uniform_location.shape_type, i32(shape.type))
		gl.UniformMatrix4fv(
			renderer.shape_shader.uniform_location.transform, 
			1, 
			false, 
			&shape.transform[0][0]
		)
		gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
	}
}

@private
create_shader :: proc(platform: plat.Platform, shader: assets.Shader_ID) -> (shader_id: u32) {
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
create_shape_shader :: proc(platform: plat.Platform) -> Shape_Shader_Program {
	shape_shader: Shape_Shader_Program = {}
	shape_shader.id = create_shader(platform, .shape)
	shape_shader.uniform_location.view_projection = gl.GetUniformLocation(shape_shader.id, "view_projection")
	shape_shader.uniform_location.transform = gl.GetUniformLocation(shape_shader.id, "transform")
	shape_shader.uniform_location.color = gl.GetUniformLocation(shape_shader.id, "color")
	shape_shader.uniform_location.shape_type = gl.GetUniformLocation(shape_shader.id, "shape_type")
	return shape_shader
}

@private 
create_basic_shader :: proc(platform: plat.Platform) -> Basic_Shader_Program {
	basic_shader: Basic_Shader_Program = {}
	basic_shader.id = create_shader(platform, .basic)
	basic_shader.uniform_location.view_projection = gl.GetUniformLocation(basic_shader.id, "view_projection")
	basic_shader.uniform_location.transform = gl.GetUniformLocation(basic_shader.id, "transform")
	return basic_shader
}

@private 
create_ortho_projection :: proc "contextless" (layer_count: u8) -> linalg.Matrix4f32 {
	left := -f32(properties.view_size.width) / 2
	right := f32(properties.view_size.width) / 2
	bottom := -f32(properties.view_size.height) / 2
	top := f32(properties.view_size.height) / 2
	near: f32 = 0
	far: f32 = f32(layer_count)
	return linalg.matrix_ortho3d_f32(left, right, bottom, top, near, far, flip_z_axis = false)
}

@private 
create_vertex_array :: proc "contextless" () -> u32 {
	generic_vertex_array: u32

	// Create generic vertex array object
	gl.GenVertexArrays(1, &generic_vertex_array)
	gl.BindVertexArray(generic_vertex_array)

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

	return generic_vertex_array
}

@private
load_all_textures :: proc(textures: ^Textures, platform: plat.Platform) {
	gl.GenTextures(len(textures), &textures[assets.Texture_ID(0)])

	for texture_id in assets.Texture_ID {
		if texture_id == .none do continue

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
		defer stbi.image_free(texture_bytes)

		assert(texture_bytes != nil)
		assert(width > 0 && height > 0)

		load_texture(textures[texture_id], texture_bytes, width, height)
		assets.texture_sizes[texture_id] = {
			width = u32(width),
			height = u32(height)
		}
	}
}

@private
load_texture :: proc "contextless" (id: u32, bytes: [^]byte, width: i32, height: i32) {
	gl.BindTexture(gl.TEXTURE_2D, id)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, bytes)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
}

@private 
set_viewport :: proc "contextless" (window_size: types.Size(i32)) {
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