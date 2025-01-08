package platform

import "core:c"
import "core:mem"
import "core:strings"

import "vendor:sdl2"

create_sdl2_platform :: proc() -> Platform {
	return Platform {
		read_file = read_file
	}
}

@private 
asset_path := string(sdl2.GetBasePath())

@private
read_file :: proc(path: string, allocator := context.allocator, location := #caller_location) -> string {
	file_path := strings.concatenate({ asset_path, path })
	defer delete(file_path)

	file: ^sdl2.RWops = sdl2.RWFromFile(cstring(raw_data(file_path)), "r")
	defer sdl2.RWclose(file)
	
	file_size := sdl2.RWsize(file)
	contents := make([]u8, file_size, allocator, location)
	sdl2.RWread(file, &contents[0], size_of(u8), c.size_t(file_size))
	
	return string(contents)
}