package main

import "base:intrinsics"
import "core:fmt"
import "core:mem"
import "core:os"

import gl "vendor:OpenGL"
import "vendor:sdl2"

import "common:types"

import gl_renderer "jetpack_joyride:renderer/opengl"

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

	window: ^sdl2.Window = sdl2.CreateWindow(
		"Jetpack Joyride", 
		0, 0, display_mode.w, display_mode.h, 
		{ .OPENGL, .RESIZABLE, .MAXIMIZED },
	)
	assert(window != nil)

	window_size := types.Size(i32) {
		width = display_mode.w,
		height = display_mode.h
	}
	
	gl_context := sdl2.GL_CreateContext(window)
	if gl_context == nil {
		sdl2.Log(sdl2.GetError())
		os.exit(-1)
	}

	gl.load_up_to(3, 3, sdl2.gl_set_proc_address)

	renderer := new(gl_renderer.Renderer)	
	gl_renderer.init(renderer)
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

	should_close := false
	for !should_close {
		event: sdl2.Event
		for sdl2.PollEvent(&event) {
			if event.type == .QUIT {
				should_close = true
			}
		}

		gl_renderer.render(renderer, window_size)
		sdl2.GL_SwapWindow(window)
	}

	free(renderer)

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