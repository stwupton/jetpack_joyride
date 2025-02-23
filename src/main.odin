package main

import "base:intrinsics"
import "core:fmt"
import "core:mem"
import "core:os"

import gl "vendor:OpenGL"
import "vendor:sdl2"

import "common:types"

import "jetpack_joyride:game"
import plat "jetpack_joyride:platform"
import "jetpack_joyride:properties"
import renderer_common "jetpack_joyride:renderer"
import gl_renderer "jetpack_joyride:renderer/opengl"

Window_Info :: struct {
	size: types.Size(i32),
}

main :: proc() {
	when ODIN_DEBUG {
		default_allocator := context.allocator
		tracking_allocator := mem.Tracking_Allocator {}
		mem.tracking_allocator_init(&tracking_allocator, default_allocator)
		context.allocator = mem.tracking_allocator(&tracking_allocator)
	}

	result := sdl2.Init(sdl2.INIT_EVERYTHING)
	if result != 0 {
		sdl2.Log(sdl2.GetError())
		os.exit(-1)
	}

	display_mode: sdl2.DisplayMode
	result = sdl2.GetDesktopDisplayMode(0, &display_mode)
	if result != 0 {
		sdl2.Log(sdl2.GetError())
		os.exit(-1)
	}

	// Needed for RenderDoc
	sdl2.GL_SetAttribute(.CONTEXT_PROFILE_MASK, i32(sdl2.GLprofile.CORE))

	sdl2.GL_SetAttribute(.DOUBLEBUFFER, 1)
	sdl2.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, 3)
	sdl2.GL_SetAttribute(.CONTEXT_MINOR_VERSION, 3)

	window: ^sdl2.Window = sdl2.CreateWindow(
		"Jetpack Joyride",
		0,
		0,
		display_mode.w,
		display_mode.h,
		{ .OPENGL, .RESIZABLE, .MAXIMIZED },
	)
	
	if window == nil {
		sdl2.Log(sdl2.GetError())
		os.exit(-1)
	}

	window_info := Window_Info {
		size = { width = display_mode.w, height = display_mode.h },
	}

	gl_context := sdl2.GL_CreateContext(window)
	if gl_context == nil {
		sdl2.Log(sdl2.GetError())
		os.exit(-1)
	}

	gl.load_up_to(3, 3, sdl2.gl_set_proc_address)

	platform := plat.create_sdl2_platform()

	renderer := new(gl_renderer.Renderer)
	gl_renderer.init(renderer, platform, len(game.Layer))
	free_all(context.temp_allocator)

	result = sdl2.GL_SetSwapInterval(-1)
	vsync_not_supported := result == -1
	if vsync_not_supported {
		result = sdl2.GL_SetSwapInterval(1)
	}

	if result != 0 {
		sdl2.Log(sdl2.GetError())
		os.exit(-1)
	}

	state := new(game.State)
	game.init(state)

	previous_state := new(game.State)
	previous_state^ = state^

	input := new(game.Input)

	render_frame := new(renderer_common.Frame)

	debug_time_scale: f32 = 1
	previous_time := sdl2.GetTicks()
	time_accumulator: f32 = 0

	should_close := false
	for !should_close {
		event: sdl2.Event
		for sdl2.PollEvent(&event) {
			if event.type == .QUIT {
				should_close = true
			} else if event.type == .WINDOWEVENT && event.window.event == .SIZE_CHANGED {
				window_info.size.width = event.window.data1
				window_info.size.height = event.window.data2
			} else if event.type == .MOUSEBUTTONDOWN && event.button.button == 1 {
				input.primary_button_down = true
			} else if event.type == .MOUSEBUTTONUP && event.button.button == 1 {
				input.primary_button_down = false
			} else if event.type == .KEYDOWN {
				#partial switch event.key.keysym.sym {
					case .F11: {
						fullscreen_flag :: u32(sdl2.WINDOW_FULLSCREEN_DESKTOP)
						is_fullscreen :=
							fullscreen_flag & sdl2.GetWindowFlags(window) == fullscreen_flag
						if is_fullscreen {
							sdl2.SetWindowFullscreen(window, {})
						} else {
							sdl2.SetWindowFullscreen(window, sdl2.WINDOW_FULLSCREEN_DESKTOP)
						}
					}

					case .EQUALS: {
						debug_time_scale += (1 if debug_time_scale >= 1 else 0.1)
					}

					case .MINUS: {
						debug_time_scale = max(0, debug_time_scale - (1 if debug_time_scale > 1 else 0.1))
					}
				}
			}
		}

		current_time := sdl2.GetTicks()
		time_accumulator += f32(current_time - previous_time) * debug_time_scale
		previous_time = current_time

		for time_accumulator >= properties.sim_time_ms {
			time_accumulator -= properties.sim_time_ms

			// Copy state before last simulation tick to use for rendering.
			if time_accumulator < properties.sim_time_ms {
				previous_state^ = state^
			}

			game.update(state, input, properties.sim_time_s)
		}

		alpha := time_accumulator / properties.sim_time_ms
		renderer_common.clear_frame(render_frame)
		game.populate_render_frame(render_frame, state^, previous_state^, alpha)

		gl_renderer.render(renderer, render_frame^, window_info.size)
		sdl2.GL_SwapWindow(window)
	}

	free(renderer)
	free(state)
	free(previous_state)
	free(input)
	free(render_frame)

	when ODIN_DEBUG {
		if allocations_length := len(tracking_allocator.allocation_map); allocations_length > 0 {
			fmt.printfln("Memory Leaks (%v): ", allocations_length)

			for _, value in tracking_allocator.allocation_map {
				fmt.printfln("- Location: %v, Bytes: %v", value.location, value.size)
			}
		}

		if bad_free_length := len(tracking_allocator.bad_free_array); bad_free_length > 0 {
			fmt.printfln("Bad Frees (%v): ", bad_free_length)

			for value in tracking_allocator.bad_free_array {
				fmt.printfln("- Location: %v", value.location)
			}
		}
	}
}
