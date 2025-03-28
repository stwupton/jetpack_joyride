package renderer

import "core:math/linalg"
import "core:container/small_array"

Texture_ID :: u32

Image_Render_Item :: struct {
	transform: linalg.Matrix4f32,
	texture: Texture_ID,
}

Shape_Type :: enum u8 {
	rectangle,
	circle,
}

Shape_Render_Item :: struct {
	transform: linalg.Matrix4f32,
	color: linalg.Vector4f32,
	type: Shape_Type,
}

Frame :: struct {
	images: small_array.Small_Array(64, Image_Render_Item),
	shapes: small_array.Small_Array(512, Shape_Render_Item),
}

clear_frame :: proc "contextless" (frame: ^Frame) {
	small_array.clear(&frame.images)
	small_array.clear(&frame.shapes)
}
