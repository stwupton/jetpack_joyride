package platform 

Platform :: struct {
	// Platform independent data
	internal: rawptr, 
	read_asset_file: proc(platform: Platform, path: string, allocator := context.allocator, location := #caller_location) -> string
}