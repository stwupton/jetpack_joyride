package sdl2_platform

import "base:builtin"
import "core:c"
import "core:mem"
import "core:strings"

import "vendor:sdl2"

import common_platform "common:platform"

make :: proc(platform: ^common_platform.Platform, asset_location: string) {
	internal: ^SDL2_Platform_Internal = builtin.new(SDL2_Platform_Internal)
	internal.asset_path = strings.concatenate({ string(sdl2.GetBasePath()), asset_location })

	platform^ = {
		internal = internal,
		read_asset_file = read_asset_file
	}
}

delete :: proc(platform: ^common_platform.Platform) {
	assert(platform.internal != nil)

	internal := transmute(^SDL2_Platform_Internal)platform.internal

	builtin.delete(internal.asset_path)
	free(internal)
}

@private
SDL2_Platform_Internal :: struct {
	asset_path: string
}

@private
read_asset_file :: proc(
	platform: common_platform.Platform, 
	path: string, 
	allocator := context.allocator, 
	location := #caller_location
) -> string {
	assert(platform.internal != nil)

	internal := transmute(^SDL2_Platform_Internal)platform.internal

	file_path := strings.concatenate({ internal.asset_path, path })
	defer builtin.delete(file_path)

	file: ^sdl2.RWops = sdl2.RWFromFile(cstring(raw_data(file_path)), "r")
	defer sdl2.RWclose(file)
	
	file_size := sdl2.RWsize(file)
	contents := builtin.make([]u8, file_size, allocator, location)

	sdl2.RWread(file, &contents[0], size_of(u8), c.size_t(file_size))
	
	return string(contents)
}