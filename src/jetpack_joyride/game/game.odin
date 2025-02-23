package game

import "core:math"
import "core:math/rand"
import "core:math/linalg"
import "core:container/small_array"
import "core:fmt"

import "common:types"
import "common:pool"

import "jetpack_joyride:assets"
import "jetpack_joyride:properties"
import "jetpack_joyride:renderer"

update :: proc(state: ^State, input: ^Input, delta: f32) {
	update_back_panels(&state.back_panels, state.camera, delta)
	update_floors(&state.floors, state.camera, delta)
	update_player(&state.player, &state.bullets, input^, delta)
	update_bullets(&state.bullets, delta)
	update_camera(&state.camera, state.player)
}

init :: proc "contextless" (state: ^State) {
	init_back_panels(&state.back_panels)
	init_floors(&state.floors)
	init_player(&state.player)
}

populate_render_frame :: proc(
	frame: ^renderer.Frame,
	state: State, 
	previous_state: State, 
	alpha: f32
) {
	shapes_overflowed: bool = false
	sprites_overflowed: bool = false

	// Need to interpolate the camera position before calculating the transforms
	// for each entity.
	camera := linalg.lerp(previous_state.camera, state.camera, alpha)

	// Back panels
	{
		previous := previous_state.back_panels
		for panel, index in state.back_panels {
			shapes_overflowed = !small_array.push(&frame.shapes, make_shape_render_item(panel, previous[index], camera, alpha))
		}
	}
	
	// Floors
	{
		previous := previous_state.floors
		for floor, index in state.floors {
			shapes_overflowed = !small_array.push(&frame.shapes, make_shape_render_item(floor, previous[index], camera, alpha))
		}
	}

	// Bullets 
	{
		previous := previous_state.bullets
		for taken, index in state.bullets.taken {
			if !taken do continue
			bullet := state.bullets.data[index]
			shapes_overflowed = !small_array.push(&frame.shapes, make_shape_render_item(bullet, previous.data[index], camera, alpha))
		}
	}

	// Player
	{
		previous := previous_state.player
		shapes_overflowed = !small_array.push(&frame.shapes, make_shape_render_item(state.player, previous, camera, alpha))
	}

	assert(!shapes_overflowed && !sprites_overflowed)
}

@private
make_shape_render_item :: proc "contextless" (
	current: Shape, 
	previous: Shape, 
	camera: Camera, 
	alpha: f32
) -> renderer.Shape_Render_Item {
	current := current
	previous := previous
	
	// Modify the scales of both current and previous shapes to include the size.
	current.scale *= types.size_to_vector2(current.size)
	previous.scale *= types.size_to_vector2(previous.size)

	return renderer.Shape_Render_Item {
		transform = make_transform(current, previous, camera, alpha),
		colour = current.colour,
		type = current.type,
	}
}

@private 
make_transform :: proc "contextless" (
	current: Entity, 
	previous: Entity, 
	camera: Camera,
	alpha: f32
) -> linalg.Matrix4f32 {
	position := current.position
	scale := current.scale
	rotation := current.rotation
	
	if current.version == previous.version {
		position = linalg.lerp(previous.position, current.position, alpha)
		scale = linalg.lerp(previous.scale, current.scale, alpha)
		rotation = linalg.lerp(previous.rotation, current.rotation, alpha)
	}

	position -= camera

	transform := linalg.matrix4_translate_f32({ position.x, position.y, f32(current.layer) })
	transform *= linalg.matrix4_scale_f32({ scale.x, scale.y, 1 })
	transform *= linalg.matrix4_rotate_f32(rotation, { 0, 0, 1 })

	return transform
}

@private 
init_back_panels :: proc "contextless" (back_panels: ^Back_Panels) {
	panel_size :: 1080
	colour :: linalg.Vector4f32 { 0.7, 0.7, 0.7, 1 }
	back_panels^ = {
		make_shape(
			type = .rectangle, 
			size = { width = panel_size, height = panel_size }, 
			position = { -panel_size, 0 }, 
			layer = .background,
			colour = colour,
		),
		make_shape(
			type = .rectangle, 
			size = { width = panel_size, height = panel_size }, 
			position = { 0, 0 }, 
			layer = .background,
			colour = colour * .9,
		),
		make_shape(
			type = .rectangle, 
			size = { width = panel_size, height = panel_size }, 
			position = { panel_size, 0 }, 
			layer = .background,
			colour = colour * .8,
		),
		make_shape(
			type = .rectangle, 
			size = { width = panel_size, height = panel_size }, 
			position = { panel_size * 2, 0 }, 
			layer = .background,
			colour = colour * .7,
		),
	}
}

@private
hex_to_vector4f32 :: proc "contextless" (hex: u32) -> linalg.Vector4f32 {
	r := f32((hex >> 24) & 0xff) / 255
	g := f32((hex >> 16) & 0xff) / 255
	b := f32((hex >> 8) & 0xff) / 255
	a := f32(hex & 0xff) / 255
	return linalg.Vector4f32 { r, g, b, a }
}

@private
init_floors :: proc "contextless" (floors: ^Floors) {
	size := types.Size(f32) { 
		width = 1920, 
		height = f32(properties.view_size.height) / 2 + properties.floor_y,
	}

	y := properties.floor_y - f32(size.height) / 2
	colour := hex_to_vector4f32(0xced38dff)

	floors^ = {
		make_shape(
			type = .rectangle, 
			size = size,
			position = { 0, y }, 
			layer = .foreground,
			colour = colour,
		),
		make_shape(
			type = .rectangle, 
			size = size,
			position = { f32(size.width), y }, 
			layer = .foreground,
			colour = colour,
		),
		make_shape(
			type = .rectangle, 
			size = size,
			position = { f32(size.width * 2), y }, 
			layer = .foreground,
			colour = colour,
		),
	}
}

@private
init_player :: proc "contextless" (player: ^Player) {
	height :: f32(200)
	width :: f32(100)
	player.shape = make_shape(
		type = .rectangle,
		size = { width = width, height = height },
		position = { properties.player_x_position, properties.floor_y + height / 2 },
		colour = { 1, 0, 0, 1 },
	)
}

@private 
spawn_bullet :: proc(bullets: ^Bullets, position: linalg.Vector2f32) {
	bullet := pool.add(bullets)
	bullet.type = .circle
	bullet.size = { width = 30, height = 30 }
	bullet.scale = { 1, 1 }
	bullet.position = position
	bullet.colour = hex_to_vector4f32(0xd8c495ff)
	bullet.layer = .main
	bullet.version += 1

	// Give a random angle to the bullets direction
	bullet.direction = { 0, -1 }
	rotate_by: f32 = rand.float32_range(-properties.bullet_spread, properties.bullet_spread)
	bullet.direction.x = bullet.direction.x * math.cos(rotate_by) - bullet.direction.y * math.sin(rotate_by)
	bullet.direction.y = bullet.direction.x * math.sin(rotate_by) + bullet.direction.y * math.cos(rotate_by)
}

@private
update_back_panels :: proc "contextless" (back_panels: ^Back_Panels, camera: Camera, delta: f32) {
	count := len(back_panels^)
	for &panel in back_panels {
		left_cutoff: f32 = camera.x - f32(properties.view_size.width / 2) - f32(panel.size.width / 2)
		if panel.position.x <= left_cutoff {
			panel.position.x += f32(panel.size.width) * f32(count)
			panel.version += 1
		}
	}
}

@private 
update_bullets :: proc(bullets: ^Bullets, delta: f32) {
	iterator := pool.make_pool_iterator(bullets)
	for bullet, index in pool.iterate_pool(&iterator) {
		bullet.position += bullet.direction * properties.bullet_speed * delta
		
		if bullet.position.y < properties.floor_y - 200 {
			pool.remove(bullets, index)
		}
	}	
}

@private 
update_camera :: proc "contextless" (camera: ^linalg.Vector2f32, player: Player) {
	camera.x = player.position.x + properties.camera_x_offset
}

@private
update_floors :: proc "contextless" (floors: ^Floors, camera: Camera, delta: f32) {
	count := len(floors^)
	for &floor in floors {
		left_cutoff: f32 = camera.x - f32(properties.view_size.width / 2) - f32(floor.size.width / 2)
		if floor.position.x <= left_cutoff {
			floor.position.x += f32(floor.size.width) * f32(count)
			floor.version += 1
		}
	}
}

@private
update_player :: proc (player: ^Player, bullets: ^Bullets, input: Input, delta: f32) {
	player.position.x += properties.player_move_speed * delta

	if input.primary_button_down {
		player.y_velocity += properties.player_vertical_velocity * delta
		spawn_bullet(bullets, { 
			player.position.x, 
			player.position.y - player.size.height / 2 
		})
	}

	player.y_velocity -= properties.player_gravity * delta
	player.position.y += player.y_velocity

	ground_level := properties.floor_y + player.size.height / 2
	max_height := properties.player_max_height - player.size.height / 2
	if player.position.y <= ground_level || player.position.y >= max_height {
		player.y_velocity = 0
	}

	player.position.y = clamp(player.position.y, ground_level, max_height)
}