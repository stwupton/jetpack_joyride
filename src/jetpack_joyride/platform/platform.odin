package platform 

Platform :: struct {
	read_file: proc(path: string, allocator := context.allocator, location := #caller_location) -> string
}