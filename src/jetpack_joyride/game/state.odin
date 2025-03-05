package game

import "core:math/linalg"

import "common:types"
import "common:pool"

import "jetpack_joyride:assets"
import "jetpack_joyride:renderer"

Layer :: enum u8 {
	foreground,
	main,
	background,
}

Entity_Version :: u8

Entity :: struct {
	position: linalg.Vector2f32,
	scale: linalg.Vector2f32,
	rotation: f32,
	version: Entity_Version,
	layer: Layer,
}

Shape :: struct {
	using entity: Entity,
	color: linalg.Vector4f32,
	size: types.Size(f32),
	type: renderer.Shape_Type,
}

Sprite :: struct {
	using entity: Entity,
	texture: assets.Texture_ID,
}

make_shape :: proc "contextless" (
	type: renderer.Shape_Type,
	size: types.Size(f32),
	position: linalg.Vector2f32 = {},
	scale: linalg.Vector2f32 = { 1, 1 },
	rotation: f32 = 0,
	layer: Layer = .main,
	color: linalg.Vector4f32 = { 1, 1, 1, 1 },
	version: Entity_Version = 0
) -> Shape {
	return {
		position = position,
		scale = scale,
		rotation = rotation,
		layer = layer,
		type = type,
		size = size,
		color = color,
		version = version,
	}
}

make_sprite :: proc "contextless" (
	texture: assets.Texture_ID,
	position: linalg.Vector2f32 = {}, 
	scale: linalg.Vector2f32 = { 1, 1 }, 
	rotation: f32 = 0,
	layer: Layer = .main
) -> Sprite {
	return {
		position = position,
		scale = scale,
		rotation = rotation,
		layer = layer,
		texture = texture,
	}
}

Back_Panels :: [4]Shape
Floors :: [3]Shape
Camera :: linalg.Vector2f32

Bullet :: struct {
	using shape: Shape,
	direction: linalg.Vector2f32,
}

Player :: struct {
	using shape: Shape,
	y_velocity: f32,
}

Bullets :: pool.Pool(Bullet, 256)

Ground_Enemy :: struct {
	using shape: Shape,
	damaged_timestamp: f32,
	health: f32,
}

Ground_Enemies :: pool.Pool(Ground_Enemy, 32)

State :: struct {
	camera: Camera,
	back_panels: Back_Panels,
	floors: Floors,
	player: Player,
	bullets: Bullets,
	ground_enemies: Ground_Enemies,
	time: f32,
	ground_enemy_spawn_cooldown: f32,
}