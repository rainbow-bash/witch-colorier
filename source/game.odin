/*
This file is the starting point of your game.

Some important procedures are:
- game_init_window: Opens the window
- game_init: Sets up the game state
- game_update: Run once per frame
- game_should_close: For stopping your game when close button is pressed
- game_shutdown: Shuts down game and frees memory
- game_shutdown_window: Closes window

The procs above are used regardless if you compile using the `build_release`
script or the `build_hot_reload` script. However, in the hot reload case, the
contents of this file is compiled as part of `build/hot_reload/game.dll` (or
.dylib/.so on mac/linux). In the hot reload cases some other procedures are
also used in order to facilitate the hot reload functionality:

- game_memory: Run just before a hot reload. That way game_hot_reload.exe has a
	pointer to the game's memory that it can hand to the new game DLL.
- game_hot_reloaded: Run after a hot reload so that the `g` global
	variable can be set to whatever pointer it was in the old DLL.

NOTE: When compiled as part of `build_release`, `build_debug` or `build_web`
then this whole package is just treated as a normal Odin package. No DLL is
created.
*/

package game

import "./anime"
import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import "core:strings"
import "core:time"
import rl "vendor:raylib"

WINDOW_HEIGHT :: 720
HEALTH_BAR_WIDTH :: 64
HEALTH_MAX :: 0xFF
WINDOW_WIDTH :: WINDOW_HEIGHT

COLLISION_SCALE :: 0.5
PARRY_SCALE :: 1.2

PIXEL_WINDOW_HEIGHT :: 256
PIXEL_WINDOW_WIDTH :: PIXEL_WINDOW_HEIGHT
TILE_SIZE :: 16
HEX_SQUARE_WIDTH :: TILE_SIZE * 2
HEX_SQUARE_HEIGHT :: TILE_SIZE
TILE_COLS :: PIXEL_WINDOW_WIDTH / TILE_SIZE
PROJECTILE_DEATH_DURATION :: 100


rect_get_position :: proc(rect: rl.Rectangle) -> rl.Vector2 {
	return {rect.x, rect.y}
}

rect_get_size :: proc(rect: rl.Rectangle) -> rl.Vector2 {
	return {rect.x, rect.y}
}

hexcode_to_color :: proc(hex: int) -> rl.Color {
	a: u8 = 0xFF
	r: u8 = u8(hex >> (8 * 2) & 0xFF)
	g: u8 = u8(hex >> (8 * 1) & 0xFF)
	b: u8 = u8(hex >> (8 * 0) & 0xFF)

	return rl.Color {
		u8(r), //
		u8(g), //
		u8(b), //
		u8(a), //
	}
}

Entity_Action_State :: enum {
	NIL,
	STARTING,
	ENDED,
}

Entity_State :: struct {
	start:          time.Time,
	action:         Entity_Action_State,
	death_duration: time.Duration,
	is_dead:        bool,
}

Entity_Animation :: struct {
	using animation: anime.Animation,
	texture:         rl.Texture,
	frame_width:     f32,
	frame_heigth:    f32,
}

Entity_Animations :: struct {
	idle:    Entity_Animation,
	running: Entity_Animation,
	dying:   Entity_Animation,
	emote:   Entity_Animation,
}

Entity_Animation2 :: struct {
	name: string,
}

Flags :: struct {
	can_parry: bool,
}

Entity :: struct {
	auto_speed:        rl.Vector2,
	textures:          []rl.Texture,
	animations:        Entity_Animations,
	animations_memory: Entity_Animation2,
	base_texture:      rl.Texture,
	dying_animation:   []rl.Texture,
	rects:             Entity_Rectangles,
	health:            int,
	max_health:        int,
	collided_with:     [dynamic]^Entity,
	state:             Entity_State,
	scale:             f32,
	tint:              rl.Color,
	flags:             Flags,
	hex:               rl.Color,
}

Collision_Rect :: struct {
	using rect:     rl.Rectangle,
	last_collision: time.Time,
	target:         ^Entity,
	is_colliding:   bool,
	is_action:      bool,
}

Entity_Rectangles :: struct {
	outermost: Collision_Rect,
	parry:     Collision_Rect,
	core:      Collision_Rect,
}


entity_generate_rectangles :: proc(pos: rl.Vector2, width: f32, height: f32) -> Entity_Rectangles {
	x := pos.x
	y := pos.y

	col_w := width * COLLISION_SCALE
	col_h := height * COLLISION_SCALE
	col_x := x + (width / 2 - col_w / 2)
	col_y := y + (height / 2 - col_h / 2)

	par_w := width * PARRY_SCALE
	par_h := height * PARRY_SCALE
	par_x := x + (width / 2 - par_w / 2)
	par_y := y + (height / 2 - par_h / 2)

	return {
		outermost = {rect = {x, y, width, height}},
		parry = {rect = {par_x, par_y, par_w, par_h}},
		core = {rect = {col_x, col_y, col_w, col_h}},
	}
}

entity_get_position :: proc(entity: Entity) -> rl.Vector2 {
	return {entity.rects.outermost.x, entity.rects.outermost.y}
}

entity_draw_rects :: proc(entity: Entity) {
	if entity.state.is_dead {
		return
	}
	rl.DrawRectangleLinesEx(entity.rects.core, 0.8, rl.RED)
	rl.DrawRectangleLinesEx(entity.rects.parry, 0.8, rl.GREEN)
	rl.DrawRectangleLinesEx(entity.rects.outermost, 0.8, rl.BLUE)
}

// TODO: rename this because it does way more than just checking for the collision
entity_check_collision :: proc(
	self: ^Entity,
	rect: ^Collision_Rect,
	target: ^Entity,
	target_rect: ^Collision_Rect,
) -> (
	bool,
	time.Time,
) {
	colliding_entity: ^Entity = nil
	if target.state.is_dead {
		return false, time.Time{}
	}

	did_collide := rl.CheckCollisionRecs(rect, target_rect)

	last_hit := rect.last_collision

	if did_collide && last_hit == {} {
		last_hit = time.now()
		rect.target = target
	}

	if did_collide {
		colliding_entity = target
	}

	return did_collide, last_hit
}

entity_update_collision_state :: proc(self: ^Entity) {
	{
		last_collision: time.Time
		is_colliding := false
		collided_with: [dynamic]^Entity

		for &other in g.entities {
			is, lc := entity_check_collision(
				self, //
				&self.rects.parry,
				&other,
				&other.rects.core,
			)
			if is {
				last_collision = lc
				is_colliding = is
				append(&collided_with, &other)
			}
		}
		self.rects.parry.is_colliding = is_colliding
		self.rects.parry.last_collision = last_collision
		for ent in collided_with {
			append(&self.collided_with, ent)
		}
	}
}

entity_update_position :: proc(entity: ^Entity, input: rl.Vector2) {
	movement := (input * rl.GetFrameTime() * 50)

	x := movement.x
	y := movement.y

	entity.rects.outermost.x += x
	entity.rects.outermost.y += y
	entity.rects.core.x += x
	entity.rects.core.y += y
	entity.rects.parry.x += x
	entity.rects.parry.y += y
}

Debug :: struct {
	is_dragging_player:  bool,
	dragging_target:     Entity,
	messages:            [dynamic]string,
	persistent_messages: [dynamic]string,
}

// parries damage the projectile so some of them might have more health so you need to parry more than once
Projectile :: struct {
	using entity: Entity,
	rotation:     f32,
}


new_random_projectile :: proc(texture: rl.Texture, i := 0) -> Projectile {
	// position := rl.GetScreenToWorld2D({f32(rand.int63()), f32(rand.int63())})
	// w := f32(rl.GetScreenWidth())
	position: rl.Vector2 = get_player_pos()
	position.x += f32(texture.width) * 2.0
	position.y += f32(texture.height * i32(i))
	scale: f32 = 0.5

	height := f32(f32(texture.height) * scale)
	width := f32(f32(texture.width) * scale)
	rects := entity_generate_rectangles(position, width, height)
	fmt.printfln("%#v", rects)


	r := u8(rand.uint32())
	g := u8(rand.uint32())
	b := u8(rand.uint32())

	return {
		rects = rects,
		state = {death_duration = time.Millisecond * PROJECTILE_DEATH_DURATION},
		health = 1,
		scale = scale,
		hex = {r, g, b, 0},
		auto_speed = 0.15,
		base_texture = texture,
	}
}

Game_Memory :: struct {
	debug:         ^Debug,
	is_debug_mode: bool,
	is_paused:     bool,
	player:        Player,
	camera_pos:    rl.Vector2,
	obstacles:     [24]rl.Vector2,
	projectiles:   [3]Projectile,
	entities:      [dynamic]Entity,
	camera_speed:  f32,
	some_number:   int,
	run:           bool,
	blocks:        [TILE_COLS * 6]rl.Rectangle,
	zoom:          f32,
}

g: ^Game_Memory
d: Debug


get_player_pos :: proc() -> rl.Vector2 {
	return rl.Vector2{g.player.rects.outermost.x, g.player.rects.outermost.y}
}


set_player_pos :: proc(pos: rl.Vector2) {
	g.player.rects.outermost.x = pos.x
	g.player.rects.outermost.y = pos.y
}


game_camera :: proc() -> rl.Camera2D {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())

	return {
		zoom   = (h / PIXEL_WINDOW_HEIGHT) + g.zoom,
		// zoom   = 4,
		target = g.camera_pos,
		offset = {w / 2, h / 2},
	}
}

screen_center :: proc() -> rl.Vector2 {
	return {0, 0}
}

debug :: proc(format: string, args: ..any) {
	append(&g.debug.messages, fmt.aprintf(format, ..args))
}

debug_once :: proc(format: string, args: ..any) {
	if len(g.debug.messages) == 0 {
		debug(format, ..args)
	}
}

debug_persistent :: proc(format: string, args: ..any) {
	append(&d.persistent_messages, fmt.aprintf(format, ..args))
}

ui_camera :: proc() -> rl.Camera2D {
	return {zoom = f32(rl.GetScreenHeight()) / PIXEL_WINDOW_HEIGHT}
}

draw_text :: proc(text: string, pos_x, pos_y: int, font_size: int, color: rl.Color) {
	txt := strings.clone_to_cstring(text)
	rl.DrawText(txt, i32(pos_x), i32(pos_y), i32(font_size), color)
}

draw_rect :: proc(pos_x, pos_y: int, width: int, height: int, color: rl.Color) {
	rl.DrawRectangle(i32(pos_x), i32(pos_y), i32(width), i32(height), color)
}

draw_rect_lines :: proc(pos_x, pos_y: int, width: int, height: int, color: rl.Color) {
	rl.DrawRectangle(i32(pos_x), i32(pos_y), i32(width), i32(height), color)
}

draw_text_rect :: proc(
	texture: rl.Texture,
	rect: rl.Rectangle,
	rotation: f32 = 0,
	scale: f32 = 1,
	tint: rl.Color = rl.WHITE,
) {
	rl.DrawTextureEx(texture, rect_get_position(rect), rotation, scale, tint)
}

render_debug_f3 :: proc() {
	{
		msg := strings.join(g.debug.messages[:], "\n")
		txt := strings.clone_to_cstring(msg)
		rl.DrawText(txt, 0, 0, 1, rl.WHITE)
	}
	// {
	// 	msg := strings.join(d.persistent_messages[:], "\n")
	// 	txt := strings.clone_to_cstring(msg)
	// 	x: i32 = 230
	// 	rl.DrawText(txt, x, 0, 1, rl.WHITE)
	// }
}

render_debug :: proc() {
	entity_draw_rects(g.player.entity)
	for p in g.projectiles {
		entity_draw_rects(p.entity)
	}
}

// TODO: make an ui context where the ui elements are stacked,
//			 and everytime a rectangle is drawn add the height (column) or width (row) of that shape, so the next y or x in the current context gets updated to that
render_ui :: proc() {
	y := PIXEL_WINDOW_HEIGHT / 2 + PIXEL_WINDOW_HEIGHT / 3
	{
		health_width := ((g.player.health * HEALTH_BAR_WIDTH) / g.player.max_health)
		draw_rect(0, y, HEALTH_BAR_WIDTH, 10, hexcode_to_color(0x2c2933))
		draw_rect(0, y, health_width, 10, hexcode_to_color(0xc8abd0))
		draw_text(fmt.aprintf("0x%2X", g.player.health), 0, y, 12, rl.WHITE)
		y += TILE_SIZE
	}
	{
		for hex, _ in g.player.hex_channels {
			x := 0 * HEX_SQUARE_WIDTH
			red := hex[0]
			green := hex[1]
			blue := hex[2]

			{
				draw_rect(x, y, HEX_SQUARE_WIDTH, HEX_SQUARE_HEIGHT, {red, 0, 0, 255})
				draw_text(fmt.aprintf("0x%2X", red), x, y, 1, rl.WHITE)
				x += HEX_SQUARE_WIDTH
			}

			{
				draw_rect(x, y, HEX_SQUARE_WIDTH, HEX_SQUARE_HEIGHT, {0, green, 0, 255})
				draw_text(fmt.aprintf("0x%2X", green), x, y, 1, rl.WHITE)
				x += HEX_SQUARE_WIDTH
			}

			{
				draw_rect(x, y, HEX_SQUARE_WIDTH, HEX_SQUARE_HEIGHT, {0, 0, blue, 255})
				draw_text(fmt.aprintf("0x%2X", blue), x, y, 1, rl.WHITE)
				x += HEX_SQUARE_WIDTH
			}


			y += HEX_SQUARE_HEIGHT + 1
			x = 0 * HEX_SQUARE_WIDTH
			draw_rect(x, y, HEX_SQUARE_WIDTH * 3, HEX_SQUARE_HEIGHT, hex)
			draw_text(fmt.aprintf("0x%2X%2X%2X", red, green, blue), x, y, 1, rl.WHITE)
		}
	}
}

update_debug :: proc() {
	mouse := rl.GetScreenToWorld2D(rl.GetMousePosition(), game_camera())
	if rl.IsKeyDown(.R) {
		reset_memory()
	}

	if rl.GetMouseWheelMove() != 0 {
		// g.camera_pos = rl.GetMousePosition()
		y := rl.GetMouseWheelMove()
		g.zoom = g.zoom + y
		if g.zoom < -5 {
			g.zoom = -5
		}

		// fmt.println(y)
	}


	if rl.IsMouseButtonDown(.MIDDLE) {
		delta := rl.GetMouseDelta()
		g.camera_pos += -(delta / 4)
	}

	if rl.IsMouseButtonDown(.LEFT) {
		if g.debug.is_dragging_player {
			set_player_pos(mouse)
		} else if rl.CheckCollisionPointRec(mouse, g.player.rects.outermost) {
			set_player_pos(mouse)
			g.debug.is_dragging_player = true
		}
	}

	if rl.IsMouseButtonUp(.LEFT) {
		if g.debug.is_dragging_player {
			g.debug.is_dragging_player = false
		}
	}

}

handle_input :: proc() -> rl.Vector2 {
	input: rl.Vector2

	if rl.IsKeyDown(.UP) || rl.IsKeyDown(.W) {
		input.y -= 1
	}


	if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S) {
		input.y += 1
	}


	if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
		input.x -= 1
	}

	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
		input.x += 1
	}

	if rl.IsKeyPressed(.LEFT_ALT) {
		g.is_debug_mode = !g.is_debug_mode
	}

	if rl.IsKeyPressed(.ESCAPE) {
		g.is_paused = !g.is_paused
	}

	input = linalg.normalize0(input)
	return input
}


update :: proc() {
	input := handle_input()
	if g.is_paused {
		return
	}

	entity_update_position(&g.player.entity, input)

	for &ent in g.entities {
		entity_update_collision_state(&ent)
	}

	for &p in g.projectiles {
		entity_update_position(&p.entity, {-p.auto_speed.x, 0})
	}

	for &a in g.player.attacks {
		entity_update_position(&a.entity, {a.auto_speed.x, 0})
		a.rotation = f32((int(a.rotation + 1)) % 360)
	}
	update_debug()
	anime.update_animation(&g.player.animations.idle.animation)


	// g.player.rects.parry.is_colliding = false
	// g.player.rects.parry.last_collision = time.Time{}

	g.player.collided_with = nil
	{
		// colliding_entity: ^Entity
		last_collision: time.Time
		is_colliding := false
		collided_with: [dynamic]^Projectile

		for &p in g.projectiles {
			is, lc := entity_check_collision(
				&g.player.entity, //
				&g.player.rects.parry,
				&p,
				&p.rects.core,
			)
			if is {
				last_collision = lc
				is_colliding = is
				append(&collided_with, &p)
			}
		}
		g.player.rects.parry.is_colliding = is_colliding
		g.player.rects.parry.last_collision = last_collision
		for ent in collided_with {
			append(&g.player.collided_with, ent)
		}
	}

	{
		last_collision: time.Time
		is_colliding := false
		rect := &g.player.rects.outermost
		collided_with: [dynamic]^Projectile
		for &p in g.projectiles {
			is, lc := entity_check_collision(
				&g.player.entity, //
				rect,
				&p,
				&p.rects.core,
			)
			if is {
				is_colliding = is
				last_collision = lc
				append(&collided_with, &p)
			}
		}
		rect.is_colliding = is_colliding
		rect.last_collision = last_collision
		for ent in collided_with {
			append(&g.player.collided_with, ent)
		}
	}

	parry_dt := time.since(g.player.rects.parry.last_collision)
	core_parry_dt := time.since(g.player.rects.core.last_collision)

	can_parry :=
		(parry_dt < 300 * time.Millisecond && g.player.rects.parry.is_colliding) ||
		(core_parry_dt < 100 * time.Millisecond && g.player.rects.core.is_colliding)

	g.player.flags.can_parry = can_parry


	if rl.IsKeyDown(.L) && can_parry {
		g.player.rects.parry.is_action = true
		for &ent in g.player.collided_with {
			ent.state.is_dead = true
			player_add_hex_color(ent.hex)
		}
		// g.player.rects.parry.target.state.is_dead = true
	} else {
		g.player.rects.parry.is_action = false
	}

	if rl.IsKeyPressed(.K) {
		player_attack(.BALL)
	}


}

render :: proc() {
	rl.DrawRectangle(-34, -34, 20, 20, rl.RED)
	rl.DrawRectangle(0, 0, 20, 20, rl.RED)
	for b in g.obstacles {
		rl.DrawRectangleV(b, {f32(TILE_SIZE), f32(TILE_SIZE)}, rl.GREEN)
	}
	rl.DrawRectangle(0, 0, PIXEL_WINDOW_HEIGHT, 20, rl.BLUE)
	rl.DrawTexturePro(
		g.player.animations.idle.texture,
		anime.frame(&g.player.animations.idle.animation, 6),
		g.player.rects.outermost,
		{0, 0},
		0,
		rl.WHITE,
	)

	for p in g.projectiles {
		if p.state.is_dead {
			continue
		}
		rl.DrawTextureEx(
			p.base_texture,
			entity_get_position(p.entity),
			p.rotation,
			p.scale,
			rl.WHITE,
		)
	}

	if g.player.flags.can_parry {
		for p in g.player.collided_with {
			rl.DrawRectangleLinesEx(p.rects.outermost, 2, rl.ORANGE)
		}
	}

	if g.player.rects.core.is_colliding {
		rl.ClearBackground(rl.RED)
	}

	if g.player.rects.parry.is_action {
		rl.DrawRectangleV(get_player_pos(), {20, 20}, rl.PURPLE)
	}

	if g.is_debug_mode {
		render_debug()
	}

	debug("%v", len(g.player.attacks))

	for a in g.player.attacks {
		if a.state.is_dead {
			continue
		}
		for i in 0 ..< 5 {
			pos := entity_get_position(a.entity)
			pos.x += f32(i)
			tint := a.tint
			// tint[3] -= u8(i) / 4
			scale := a.scale
			// scale -= f32(i) / 8
			rl.DrawTextureEx(a.base_texture, pos, a.rotation, scale, tint)
		}
	}

}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.DARKGRAY)


	rl.BeginMode2D(game_camera())
	render()
	rl.EndMode2D()

	// NOTE: `fmt.ctprintf` uses the temp allocator. The temp allocator is
	// cleared at the end of the frame by the main application, meaning inside
	// `main_hot_reload.odin`, `main_release.odin` or `main_web_entry.odin`.

	rl.BeginMode2D(ui_camera())
	{
		render_ui()
		// if g.is_debug_mode {
		// }
		render_debug_f3()
	}
	rl.EndMode2D()

	rl.EndDrawing()
}

reset_memory :: proc() {
	d = {}
	game_init()
}

@(export)
game_update :: proc() {
	update()
	draw()

	g.debug.messages = nil
	// Everything on tracking allocator is valid until end-of-frame.
	free_all(context.temp_allocator)
}

@(export)
game_init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Odin + Raylib + Hot Reload template!")
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(500)
	rl.SetExitKey(nil)
}

@(export)
game_init :: proc() {
	g = new(Game_Memory)

	player_texture := rl.LoadTexture("assets/witch.png")
	sparkle_texture := rl.LoadTexture("assets/sparkle.png")
	projectile_texture := rl.LoadTexture("assets/computer.png")
	player_idle_texture_atlas := rl.LoadTexture("assets/twi.png")
	center := screen_center()

	width := f32(player_texture.width)
	height := f32(player_texture.height)

	rects := entity_generate_rectangles(center, width, height)

	player: Player = {
		rects = rects,
		auto_speed = {0.12, 0},
		hex_channels = {{15, 15, 15, 255}},
		health = 0xF,
		max_health = 0xF,
		texture = player_texture,
		attack_ball_texture = sparkle_texture,
		animations = {
			idle = {
				animation = {
					//
					duration      = 0.15,
					duration_left = 0.15,
					current       = 0,
					last          = 2,
				},
				texture = player_idle_texture_atlas,
			},
		},
	}


	g^ = Game_Memory {
		is_debug_mode = true,
		debug         = &d,
		player        = player,
		run           = true,
		some_number   = 100,
		projectiles   = {
			new_random_projectile(projectile_texture, 0),
			new_random_projectile(projectile_texture, 1),
			new_random_projectile(projectile_texture, 2),
		},
		// You can put textures, sounds and music in the `assets` folder. Those
		// files will be part any release or web build.
		zoom          = 1,
		camera_speed  = 0.1,
	}

	game_hot_reloaded(g)
}

@(export)
game_should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		// Never run this proc in browser. It contains a 16 ms sleep on web!
		if rl.WindowShouldClose() {
			return false
		}
	}

	return g.run
}

@(export)
game_shutdown :: proc() {
	free(g)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseWindow()
}

@(export)
game_memory :: proc() -> rawptr {
	return g
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(Game_Memory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	g = (^Game_Memory)(mem)
	// Here you can also set your own global variables. A good idea is to make
	// your global variables into pointers that point to something inside `g`.
}

@(export)
game_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.F6)
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
game_parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(i32(w), i32(h))
}
