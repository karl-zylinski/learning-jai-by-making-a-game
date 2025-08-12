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

enemies: [..]Enemy;

powerups: [..]Powerup;

world_mouse_pos :: () -> Vector2 {
	mposx, mposy, mpos_ok := get_mouse_pointer_position(false);

	if !mpos_ok {
		return .{};
	}

	scl := RAW_SCREEN_SIZE / SCREEN_SIZE;

	return .{mposx.(float) / scl.x, mposy.(float) / scl.y};
}

Weapon_Type :: enum {
	Default;
	Triple_Shot;
}

Player :: struct {
	pos: Vector2;
	anim: Animation;
	num_extra_shots: int;
	shoot_timer: float;
	//weapon: Weapon_Type;
}

Powerup :: struct {
	pos: Vector2;
	weapon: Weapon_Type;
}

Rect :: struct {
	x, y: float;
	w, h: float;

#place x;
	pos: Vector2 = ---;

#place w;
	size: Vector2 = ---;
};

RAW_SCREEN_SIZE :: Vector2.{1920, 1080};
SCREEN_SIZE :: Vector2.{320, 180};

Texture :: Simp.Texture;

Animation :: struct {
	tex: Texture;
	cur_frame: int;
	num_frames: int;
	timer: float;
	time_per_frame: float;
}

point_in_rect :: (p: Vector2, r: Rect) -> bool {
	return p.x > r.x
	    && p.x < r.x + r.w
	    && p.y > r.y
	    && p.y < r.y + r.h;
}

rect_from_pos_size :: (p: Vector2, s: Vector2) -> Rect {
	return .{
		p.x, p.y,
		s.x, s.y,
	};
}

overlap_rectangles :: (r1: Rect, r2: Rect) -> bool {
	return r1.x < r2.x + r2.w
	    && r1.x + r1.w > r2.x
	    && r1.y < r2.y + r2.h
	    && r1.y + r1.h > r2.y;
}

set_projection :: () {
	Simp.immediate_set_2d_projection(SCREEN_SIZE.x.(s32), SCREEN_SIZE.y.(s32));
}

update_animaton :: (a: *Animation) {
	a.timer -= dt;

	if a.timer <= 0 {
		a.cur_frame += 1;

		if a.cur_frame >= a.num_frames {
			a.cur_frame = 0;	
		}

		a.timer = a.time_per_frame + a.timer;
	}
}

load_animation :: (tex_path: string, num_frames: int, time_per_frame: float) -> Animation {
	tex: Simp.Texture;
	tex_ok := Simp.texture_load_from_file(*tex, tex_path);
	assert(tex_ok);

	return .{
		tex = tex,
		num_frames = num_frames,
		time_per_frame = time_per_frame,
	};
}

draw_animation :: (a: *Animation, pos: Vector2, size: Vector2, angle: float, color := Vector4.{1,1,1,1}) {
	Simp.set_shader_for_images(*a.tex);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

	set_projection();
	h := rotate(Vector2.{size.x * 0.5, 0}, angle);
	v := rotate(Vector2.{0, size.y * 0.5}, angle);

	u := a.cur_frame.(float)/a.num_frames.(float);
	uw := 1/a.num_frames.(float);

	Simp.immediate_quad(
		pos - h - v,
		pos + h - v,
		pos + h + v,
		pos - h + v,
		color,
		.{u, 0},
		.{u+uw, 0},
		.{u+uw, 1},
		.{u, 1},
	);
}

draw_sprite :: (tex: *Texture, pos: Vector2, size: Vector2, angle: float, color := Vector4.{1,1,1,1}) {
	Simp.set_shader_for_images(tex);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

	set_projection();
	h := rotate(Vector2.{size.x * 0.5, 0}, angle);
	v := rotate(Vector2.{0, size.y * 0.5}, angle);

	Simp.immediate_quad(
		pos - h - v,
		pos + h - v,
		pos + h + v,
		pos - h + v,
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

keys_held: [#run enum_highest_value(Key)+1]bool;
dt: float;

spawn_time: float = 1;

main :: () {
	Windows.SetProcessDPIAware();
	Windows.timeBeginPeriod(1);

	Rand.random_seed(cast,force(Rand.Some_Big_Time_Value) current_time_monotonic());
	run := true;
	win := create_window(RAW_SCREEN_SIZE.x.(int), RAW_SCREEN_SIZE.y.(int), "Jai Land", 200, 100);
	Simp.set_render_target(win, .LEFT_HANDED);

	screen_rect := Rect.{
		0, 0,
		SCREEN_SIZE.x, SCREEN_SIZE.y,
	};

	enemy_tex: Simp.Texture;

	player := Player.{
		pos = .{40, 40},
		anim = load_animation("player_walk.png", 2, 0.1),
	};

	tex_ok := Simp.texture_load_from_file(*enemy_tex, "enemy.png");
	assert(tex_ok);

	prev_time := seconds_since_init();
	spawn_timer: float = 1;

	while run {
		Input.update_window_events();

		cur_time := seconds_since_init();
		dt = cast(float)(cur_time - prev_time);
		prev_time = cur_time;

		update_animaton(*player.anim);

		SPEED :: 60;

		player.shoot_timer -= dt;

		mp := world_mouse_pos();

		for Input.events_this_frame {
			if it.type == .QUIT {
				run = false;
			}

			if it.type == .KEYBOARD {
				key := it.key_code;

				if !it.repeat {
					if key == #char "A" keys_held[Key.Left]  = it.key_pressed.(bool);
					if key == #char "D" keys_held[Key.Right] = it.key_pressed.(bool);
					if key == #char "S" keys_held[Key.Down]  = it.key_pressed.(bool);
					if key == #char "W" keys_held[Key.Up]    = it.key_pressed.(bool);
					if key == Input.Key_Code.MOUSE_BUTTON_LEFT keys_held[Key.Shoot] = it.key_pressed.(bool);
				}
			}
		}

		if keys_held[Key.Shoot] && player.shoot_timer <= 0 {
			player.shoot_timer = 0.3;
			bullet_pos := player.pos;
			dir := mp - bullet_pos;

			array_add(*bullets, .{
				pos = bullet_pos,
				dir = normalize(dir),
			});

			for 1..player.num_extra_shots {
				rot_dir := ifx it % 2 == 0 then 1 else - 1;
				dir_r := rotate(dir, PI/8 * rot_dir * ((it+1)/2));

				array_add(*bullets, .{
					pos = bullet_pos,
					dir = normalize(dir_r),
				});
			}
		}

		spawn_timer -= dt;

		if spawn_timer <= 0 {
			side := Rand.random_get() % 4;
			pos: Vector2;

			if side == {
				case 0;
					pos = .{Rand.random_get_within_range(0, SCREEN_SIZE.x), -10};

				case 1;
					pos = .{SCREEN_SIZE.x + 10, Rand.random_get_within_range(0, SCREEN_SIZE.y)};

				case 2;
					pos = .{Rand.random_get_within_range(0, SCREEN_SIZE.x), SCREEN_SIZE.y + 10};

				case 3;
					pos = .{- 10, Rand.random_get_within_range(0, SCREEN_SIZE.y)};
			}
		
			array_add(*enemies, .{
				pos = pos,
			});
			spawn_timer = spawn_time;
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

		PLAYER_SIZE :: Vector2.{16, 16};

		player.pos += normalize(movement) * SPEED * dt;

		player_rect := rect_from_pos_size(player.pos - PLAYER_SIZE*0.5, PLAYER_SIZE);

		Simp.clear_render_target(0.15, 0.34, 0.18, 1);

		Simp.immediate_begin();

		POWERUP_SIZE :: Vector2.{8,8};

		Simp.set_shader_for_color();
		for *powerups {
			set_projection();

			r := rect_from_pos_size(it.pos - POWERUP_SIZE*0.5, POWERUP_SIZE);
			Simp.immediate_quad(
				r.pos,
				r.pos + .{r.w, 0},
				r.pos + r.size,
				r.pos + .{0, r.h},
				.{0, 0, 0.6, 1},
			);

			if overlap_rectangles(r, player_rect) {
				player.num_extra_shots += 1;
				remove it;
			}
		}

		player_to_mouse := player.pos - mp;
		player_angle := atan2(player_to_mouse.y, player_to_mouse.x) - PI / 2;

		draw_animation(*player.anim, player.pos, PLAYER_SIZE, player_angle);

		Simp.set_shader_for_color();

		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

		BULLET_SIZE :: Vector2.{2, 2};
		ENEMY_SIZE :: Vector2.{16,16};

		for *bullets {
			it.pos += it.dir * 200 * dt;

			r := rect_from_pos_size(it.pos - BULLET_SIZE*0.5, BULLET_SIZE);

			set_projection();
			Simp.immediate_quad(
				r.pos,
				r.pos + .{r.w, 0},
				r.pos + r.size,
				r.pos + .{0, r.h},
			);

			if !point_in_rect(it.pos, screen_rect) {
				remove it;
			}

			for *eit, eit_idx: enemies {
				er := rect_from_pos_size(eit.pos - ENEMY_SIZE*0.5, ENEMY_SIZE);
				if point_in_rect(it.pos, er) {
					chance := Rand.random_get() % 100;

					if chance > 90 {
						array_add(*powerups, .{
							pos = it.pos,
							weapon = .Triple_Shot,
						});
					}

					spawn_time -= 0.01;

					remove eit;
					remove it;
				}
			}
		}

		for *enemies {
			enemy_to_player := player.pos - it.pos;
			dir := normalize(enemy_to_player);
			it.pos += dir * 50 * dt;
			angle := atan2(enemy_to_player.y, enemy_to_player.x) + PI / 2;
			draw_sprite(*enemy_tex, it.pos, ENEMY_SIZE, angle);

			enemy_rect := rect_from_pos_size(it.pos - ENEMY_SIZE*0.5, ENEMY_SIZE);

			if overlap_rectangles(enemy_rect, player_rect) {
				run = false;
			}
		}
		Simp.immediate_flush();


		Simp.immediate_flush();

		Simp.swap_buffers(win);

		sleep_milliseconds(10);
	}

	array_free(enemies);
	array_free(bullets);
}