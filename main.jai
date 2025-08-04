#import "Basic";
#import "GL";
#import "Math";
#import "Window_Creation";
Rand :: #import "Random";
Input :: #import "Input";
Simp :: #import "Simp";
Windows :: #import "Windows";

Bullet :: struct {
	pos: Vector2;
	dir: Vector2;
}

Enemy :: struct {
	pos: Vector2;
}

bullets: [..]Bullet;
SCL :: 4;

enemies: [..]Enemy;

world_mouse_pos :: () -> Vector2 {
	mposx, mposy, mpos_ok := get_mouse_pointer_position(false);

	if !mpos_ok {
		return .{};
	}

	return .{mposx.(float)/SCL, mposy.(float)/SCL};
}

RAW_SCREEN_SIZE :: Vector2.{1920, 1080};
SCALED_SCREEN_SIZE :: #run RAW_SCREEN_SIZE / SCL;

Texture :: Simp.Texture;

draw_sprite :: (tex: *Texture, pos: Vector2, size: Vector2, angle: float, color := Vector4.{1,1,1,1}) {
	Simp.set_shader_for_images(tex);
	h := rotate(Vector2.{size.x * 0.5, 0} * SCL, angle);
	v := rotate(Vector2.{0, size.y * 0.5} * SCL, angle);

	Simp.immediate_quad(
		pos * SCL - h - v,
		pos * SCL + h - v,
		pos * SCL + h + v,
		pos * SCL - h + v,
		color,
	);
}

Key :: enum {
	Up;
	Down;
	Left;
	Right;
	Shoot;
}

keys_held: [#run enum_highest_value(Key)]bool;

main :: () {
	Windows.SetProcessDPIAware();
	Windows.timeBeginPeriod(1);

	Rand.random_seed(cast,force(Rand.Some_Big_Time_Value) current_time_monotonic());

	run := true;
	player_pos := Vector2.{40, 40};
	win := create_window(RAW_SCREEN_SIZE.x.(int), RAW_SCREEN_SIZE.y.(int), "Jai Land", 200, 100);
	Simp.set_render_target(win, .LEFT_HANDED);

	tex: Simp.Texture;

	tex_ok := Simp.texture_load_from_file(*tex, "player.png");
	assert(tex_ok);

	PLAYER_SIZE :: Vector2.{16, 16};

	prev_time := seconds_since_init();
	spawn_timer: float = 1;

	while run {
		Input.update_window_events();

		cur_time := seconds_since_init();
		dt := cast(float)(cur_time - prev_time);
		prev_time = cur_time;

		SPEED :: 60;

		mp := world_mouse_pos();

		for Input.events_this_frame {
			if it.type == .QUIT {
				run = false;
			}

			if it.type == .KEYBOARD {
				key := it.key_code;

				if it.key_pressed && key == Input.Key_Code.MOUSE_BUTTON_LEFT {
					bullet_pos := player_pos;

					array_add(*bullets, .{
						pos = bullet_pos,
						dir = normalize(mp - bullet_pos),
					});
				}


				if !it.repeat {
					if key == #char "A" keys_held[Key.Left]  = it.key_pressed.(bool);
					if key == #char "D" keys_held[Key.Right] = it.key_pressed.(bool);
					if key == #char "S" keys_held[Key.Down]  = it.key_pressed.(bool);
					if key == #char "W" keys_held[Key.Up]    = it.key_pressed.(bool);
				}
			}
		}

		spawn_timer -= dt;

		if spawn_timer <= 0 {
			side := Rand.random_get() % 4;
			pos: Vector2;

			if side == {
				case 0;
					pos = .{Rand.random_get_within_range(0, SCALED_SCREEN_SIZE.x), -10};

				case 1;
					pos = .{SCALED_SCREEN_SIZE.x + 10, Rand.random_get_within_range(0, SCALED_SCREEN_SIZE.y)};

				case 2;
					pos = .{Rand.random_get_within_range(0, SCALED_SCREEN_SIZE.x), SCALED_SCREEN_SIZE.y + 10};

				case 3;
					pos = .{- 10, Rand.random_get_within_range(0, SCALED_SCREEN_SIZE.y)};
			}
		
			array_add(*enemies, .{
				pos = pos,
			});
			spawn_timer = 1;
		}

		movement: Vector2;

		if keys_held[Key.Left] {
			movement.x -= 1;
		}

		if keys_held[Key.Right] {
			movement.x += 1;
		}

		if keys_held[Key.Up] {
			movement.y -= 1;
		}

		if keys_held[Key.Down] {
			movement.y += 1;
		}

		player_pos += normalize(movement) * SPEED * dt;

		Simp.clear_render_target(0.14, 0.29, 0.46, 1);

		Simp.set_shader_for_images(*tex);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

		Simp.immediate_begin();

		pps := player_pos * SCL;
		player_to_mouse := player_pos - mp;
		player_angle := atan2(player_to_mouse.y, player_to_mouse.x) + PI / 2;

		draw_sprite(*tex, player_pos, .{16, 16}, player_angle);

		Simp.set_shader_for_color();

		BULLET_SIZE :: 2 * SCL;
		ENEMY_SIZE :: Vector2.{16,16};

		for *bullets {
			it.pos += it.dir * 200 * dt;

			scl_pos := it.pos * SCL;
			Simp.immediate_quad(
				scl_pos + .{-BULLET_SIZE*0.5, -BULLET_SIZE*0.5},
				scl_pos + .{ BULLET_SIZE*0.5, -BULLET_SIZE*0.5},
				scl_pos + .{ BULLET_SIZE*0.5,  BULLET_SIZE*0.5},
				scl_pos + .{-BULLET_SIZE*0.5,  BULLET_SIZE*0.5},
			);

			if it.pos.x < 0
			   || it.pos.x > SCALED_SCREEN_SIZE.x
			   || it.pos.y < 0
			   || it.pos.y > SCALED_SCREEN_SIZE.y {
				remove it;
			}

			for *eit, eit_idx: enemies {
				if it.pos.x > eit.pos.x - ENEMY_SIZE.x/2
				   && it.pos.x < eit.pos.x + ENEMY_SIZE.x/2
				   && it.pos.y > eit.pos.y - ENEMY_SIZE.x/2
				   && it.pos.y < eit.pos.y + ENEMY_SIZE.y/2 {
					remove eit;
					remove it;
				}
			}
		}

		Simp.set_shader_for_images(*tex);

		for *enemies {
			enemy_to_player := player_pos - it.pos;
			dir := normalize(enemy_to_player);
			it.pos += dir * 50 * dt;
			angle := atan2(enemy_to_player.y, enemy_to_player.x) + PI / 2;
			draw_sprite(*tex, it.pos, .{16, 16}, angle, .{0, 1, 0, 1});
		}

		Simp.immediate_flush();

		Simp.swap_buffers(win);

		sleep_milliseconds(10);
	}

	array_free(enemies);
	array_free(bullets);
}