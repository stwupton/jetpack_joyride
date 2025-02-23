package properties

import "common:types"

sim_time_s :: f32(1) / 60
sim_time_ms :: f32(1000) / 60

view_size :: types.Size(int) {
	width = 1920,
	height = 1080
}

player_x_position :: -f32(view_size.width) * .2 / 2
player_move_speed :: 100.0
player_vertical_velocity :: 100.0
player_max_height :: f32(view_size.height) / 2
player_gravity :: 50.0

bullet_speed :: 1500.0
bullet_spread :: .5

camera_x_offset :: f32(view_size.width) * .2

floor_y :: -f32(view_size.height) * .8 / 2

ground_enemy_spawn_cooldown_duration :: 1.0
ground_enemy_size :: types.Size(f32) {
	width = 50,
	height = 100
}
ground_enemy_move_speed :: 20.0
ground_enemy_spawn_chance :: f32(1) / 3