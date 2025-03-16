package properties

import "common:types"

simulations_per_second : f32 : 60
sim_time_s : f32 : 1.0 / simulations_per_second
sim_time_ms : f32 : sim_time_s * 1000

view_size :: types.Size(int) {
	width = 1920,
	height = 1080
}

player_x_position :: -f32(view_size.width) * .2 / 2
player_move_speed :: 400.0
player_vertical_acceleration :: 8000.0
player_max_height :: f32(view_size.height) / 2
player_gravity :: 4000.0

bullet_speed :: 1500.0
bullet_spread :: .5
bullet_spawn_rate :: 120
bullet_damage :: 1.0

camera_x_offset :: f32(view_size.width) * .2

floor_y :: -f32(view_size.height) * .8 / 2

obstacle_x_spacing :: 500.0
obstacle_spawn_chance :: f32(1) / 4
obstacle_spawn_count_range :: []int{ 1, 1, 1, 2 }
obstacle_size :: 200.0
obstacle_color :: 0xffaabbff

ground_enemy_spawn_cooldown_duration :: 1.0
ground_enemy_size :: types.Size(f32) {
	width = 50,
	height = 100
}
ground_enemy_move_speed :: 50.0
ground_enemy_spawn_chance :: f32(1) / 3
ground_enemy_health :: 10.0
ground_enemy_color :: 0xffff00ff
ground_enemy_damaged_color :: 0xff0000ff