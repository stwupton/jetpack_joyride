package main

import "base:intrinsics"
import "core:c"
import "core:fmt"
import "core:mem"
import "core:os"

import gl "vendor:OpenGL"
import "vendor:sdl2"

import "common:types"
import common_platform "common:platform"
import sdl2_platform "common:platform/sdl2"
import common_renderer "common:renderer"
import gl_renderer "common:renderer/opengl"

import "jetpack_joyride:assets"
import "jetpack_joyride:game"
import "jetpack_joyride:properties"

Event_Buffer :: [64]sdl2.Event

Window_State :: struct {
	window: ^sdl2.Window,
	size: types.Size(i32),
	should_close: bool,

	// TODO(steven): Shouldn't be here
	debug_time_scale: f32,
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

	event_buffer := new(Event_Buffer)
	sdl2.SetEventFilter(event_filter, nil)
	
	if window == nil {
		sdl2.Log(sdl2.GetError())
		os.exit(-1)
	}

	window_state := Window_State {
		window = window,
		size = { width = display_mode.w, height = display_mode.h },
		should_close = false,
		debug_time_scale = 1.0,
	}

	gl_context := sdl2.GL_CreateContext(window)
	if gl_context == nil {
		sdl2.Log(sdl2.GetError())
		os.exit(-1)
	}

	gl.load_up_to(3, 3, sdl2.gl_set_proc_address)

	platform := common_platform.Platform {}
	sdl2_platform.make(&platform, "/assets/")

	renderer := new(gl_renderer.Renderer)
	gl_renderer.init(renderer, properties.view_size, len(game.Layer))

	vertex_contents := assets.load_shader(platform, .basic, .vertex)
	fragment_contents := assets.load_shader(platform, .basic, .fragment)
	gl_renderer.init_basic_shader(renderer, vertex_contents, fragment_contents)
	delete(vertex_contents)
	delete(fragment_contents)

	vertex_contents = assets.load_shader(platform, .shape, .vertex)
	fragment_contents = assets.load_shader(platform, .shape, .fragment)
	gl_renderer.init_shape_shader(renderer, vertex_contents, fragment_contents)
	delete(vertex_contents)
	delete(fragment_contents)

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

	render_frame := new(common_renderer.Frame)

	free_all(context.temp_allocator)

	previous_time := sdl2.GetTicks()
	time_accumulator: f32 = 0

	for !window_state.should_close {
		current_time := sdl2.GetTicks()
		time_accumulator += f32(current_time - previous_time) / 1000 * window_state.debug_time_scale
		previous_time = current_time

		handle_events(window_event_handler, event_buffer, &window_state, input)

		// Handle events when this frame does not perform any simulations.
		if time_accumulator < properties.sim_time_s {
			handle_events(game_event_handler, event_buffer, &window_state, input)
		}
		
		for time_accumulator >= properties.sim_time_s {
			time_accumulator -= properties.sim_time_s
			
			// Copy state before last simulation tick to use for rendering.
			if time_accumulator < properties.sim_time_s {
				previous_state^ = state^
			}
			
			handle_events(game_event_handler, event_buffer, &window_state, input)
			game.update(state, input, properties.sim_time_s)

			free_all(context.temp_allocator)
		}

		sdl2.FlushEvents(.FIRSTEVENT, .LASTEVENT)

		alpha := time_accumulator / properties.sim_time_s
		common_renderer.clear_frame(render_frame)
		game.populate_render_frame(render_frame, state^, previous_state^, alpha)
		
		gl_renderer.render(renderer, render_frame^, window_state.size)
		sdl2.GL_SwapWindow(window)
	}

	free(event_buffer)
	free(renderer)
	free(state)
	free(previous_state)
	free(input)
	free(render_frame)
	sdl2_platform.delete(&platform)

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

// TODO(steven): Could make the filter more specific and filter out events that 
// we know we never handle. It doesn't matter too much, because anything left over
// in the queue should be getting flushed.
@private
event_filter :: proc "c" (userdata: rawptr, event: ^sdl2.Event) -> c.int {
	handle_event :: 1
	dont_handle_event :: 0

	#partial switch event.type {
		case .QUIT: fallthrough
		case .WINDOWEVENT: fallthrough
		case .MOUSEBUTTONDOWN: fallthrough
		case .MOUSEBUTTONUP: fallthrough
		case .KEYDOWN: return handle_event
		case: return dont_handle_event
	}
}

@private
Event_Handler :: proc(
	event: sdl2.Event, 
	window_state: ^Window_State, 
	input: ^game.Input
) -> (handled: bool)

@private
handle_events :: proc(
	handler: Event_Handler, 
	buffer: ^Event_Buffer, 
	window_state: ^Window_State, 
	input: ^game.Input
) {
	sdl2.PumpEvents()

	event_count := sdl2.PeepEvents(
		&buffer[0], 
		len(buffer), 
		sdl2.eventaction.PEEKEVENT, 
		.FIRSTEVENT, 
		.LASTEVENT
	)

	// Used to remove events in bulk rather than one at a time. -1 signifies that
	// there are no events to remove.
	handled_start, handled_end: i32 = -1, -1

	for i in 0..<event_count {
		event := buffer[i]
		handled := handler(event, window_state, input)

		if handled {
			handled_start = i if handled_start == -1 else handled_start
			handled_end = i + 1
		} 
		
		should_remove_events := handled_start != -1 && (!handled || i == event_count - 1)
		if should_remove_events {
			handled_count := handled_end - handled_start

			sdl2.PeepEvents(
				&buffer[handled_start], 
				handled_count, 
				sdl2.eventaction.GETEVENT, 
				.FIRSTEVENT, 
				.LASTEVENT
			)

			handled_start, handled_end = -1, -1
		}
	}
}

@private 
game_event_handler :: proc(
	event: sdl2.Event, 
	window_state: ^Window_State, 
	input: ^game.Input
) -> (handled: bool) {
	if event.type == .MOUSEBUTTONDOWN && event.button.button == 1 {
		input.is_primary_button_down = true
		return true
	} else if event.type == .MOUSEBUTTONUP && event.button.button == 1 {
		input.is_primary_button_down = false
		return true
	}

	return false
}

@private 
window_event_handler :: proc(
	event: sdl2.Event, 
	window_state: ^Window_State, 
	input: ^game.Input
) -> (handled: bool) {
	if event.type == .QUIT {
		window_state.should_close = true
		return true
	} else if event.type == .WINDOWEVENT && event.window.event == .SIZE_CHANGED {
		window_state.size.width = event.window.data1
		window_state.size.height = event.window.data2
		return true
	} else if event.type == .KEYDOWN {
		#partial switch event.key.keysym.sym {
			case .F11: {
				fullscreen_flag :: u32(sdl2.WINDOW_FULLSCREEN_DESKTOP)
				is_fullscreen :=
					fullscreen_flag & sdl2.GetWindowFlags(window_state.window) == fullscreen_flag
				if is_fullscreen {
					sdl2.SetWindowFullscreen(window_state.window, {})
				} else {
					sdl2.SetWindowFullscreen(window_state.window, sdl2.WINDOW_FULLSCREEN_DESKTOP)
				}
				return true
			}

			case .EQUALS: {
				window_state.debug_time_scale += 1 if window_state.debug_time_scale >= 1 else 0.1
				return true
			}

			case .MINUS: {
				window_state.debug_time_scale -= 1 if window_state.debug_time_scale > 1 else 0.1
				window_state.debug_time_scale = max(0, window_state.debug_time_scale)
				return true
			}
		}
	}

	return false
}