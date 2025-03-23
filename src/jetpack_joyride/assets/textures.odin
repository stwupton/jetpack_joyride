package assets

import "core:strings"

import "common:types"

import common_platform "common:platform"

Texture_ID :: enum u8 {
	none,
	back_panel,
	floor,
}

texture_sizes: [Texture_ID]types.Size(u32) = {}

load_texture_data :: proc(platform: common_platform.Platform, texture: Texture_ID) -> []u8 {
	texture_file := texture_files[texture]
	texture_path := strings.concatenate({ "textures/", texture_file })
	defer delete(texture_path)

	contents := platform.read_asset_file(platform, texture_path)
	return transmute([]u8)contents
}

@private
texture_files := [Texture_ID]string {
	.none = "",
	.back_panel = "back_panel.png",
	.floor = "floor.png"
}