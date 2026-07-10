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

import "core:fmt"
import "core:math/linalg"
import "core:strings"
import rl "vendor:raylib"

WINDOW_HEIGHT :: 720
WINDOW_WIDTH :: WINDOW_HEIGHT

PIXEL_WINDOW_HEIGHT :: 128
PIXEL_WINDOW_WIDTH :: PIXEL_WINDOW_HEIGHT
TILE_SIZE :: 16
TILE_COLS :: PIXEL_WINDOW_WIDTH / TILE_SIZE

Hex :: struct {
	red:   u8,
	green: u8,
	blue:  u8,
	alpha: u8,
}

hex_to_color :: proc(h: Hex) -> rl.Color {
	return {h.red, h.green, h.blue, 255}
}

Entity :: struct {
	rect:            rl.Rectangle,
	auto_speed:      rl.Vector2,
	textures:        []rl.Texture,
	base_texture:    rl.Texture,
	dying_animation: []rl.Texture,
	health:          i8,
	collided_with:   ^Entity,
}

entity_get_position :: proc(entity: Entity) -> rl.Vector2 {
	return {entity.rect.x, entity.rect.y}
}

entity_set_position :: proc(entity: ^Entity, pos: rl.Vector2) {
	entity.rect.x = pos.x
	entity.rect.y = pos.y
}

entity_is_colliding_with :: proc(this, that: Entity) -> bool {
	return rl.CheckCollisionRecs(this.rect, that.rect)
}

Player :: struct {
	using entity: Entity,
	hex_channels: [6]Hex,
	texture:      rl.Texture,
	is_being_hit: bool,
	is_parrying:  bool,
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
	hex:          Hex,
	rotation:     f32,
}

new_random_projectile :: proc(texture: rl.Texture, i := 0) -> Projectile {
	// position := rl.GetScreenToWorld2D({f32(rand.int63()), f32(rand.int63())})
	// w := f32(rl.GetScreenWidth())
	position: rl.Vector2 = get_player_pos()
	position.x += f32(texture.width) * 2.0
	position.y += f32(texture.height * i32(i))
	debug_persistent("%#v: %#v", i, position)

	return {
		rect = {
			x = position.x,
			y = position.y,
			height = f32(texture.height),
			width = f32(texture.width),
		},
		health = 1,
		hex = {red = 200},
		auto_speed = 0.15,
		base_texture = texture,
	}
}

Game_Memory :: struct {
	debug:         Debug,
	is_debug_mode: bool,
	is_paused:     bool,
	player:        Player,
	camera_pos:    rl.Vector2,
	obstacles:     [24]rl.Vector2,
	projectiles:   [3]Projectile,
	camera_speed:  f32,
	some_number:   int,
	run:           bool,
	blocks:        [TILE_COLS * 6]rl.Rectangle,
	zoom:          f32,
}

g: ^Game_Memory
d: Debug


get_player_pos :: proc() -> rl.Vector2 {
	return rl.Vector2{g.player.rect.x, g.player.rect.y}
}

set_player_pos :: proc(pos: rl.Vector2) {
	g.player.rect.x = pos.x
	g.player.rect.y = pos.y
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
	append(&d.messages, fmt.aprintf(format, ..args))
}

debug_persistent :: proc(format: string, args: ..any) {
	append(&d.persistent_messages, fmt.aprintf(format, ..args))
}

ui_camera :: proc() -> rl.Camera2D {
	return {zoom = f32(rl.GetScreenHeight()) / PIXEL_WINDOW_HEIGHT / 2}
}

render_debug_f3 :: proc() {
	{
		msg := strings.join(g.debug.messages[:], "\n")
		txt := strings.clone_to_cstring(msg)
		rl.DrawText(txt, 0, 0, 1, rl.WHITE)
	}
	{
		msg := strings.join(d.persistent_messages[:], "\n")
		txt := strings.clone_to_cstring(msg)
		x: i32 = 230
		rl.DrawText(txt, x, 0, 1, rl.WHITE)
	}
}

render_debug :: proc() {
	rl.DrawRectangleLinesEx(
		{
			x = g.player.rect.x,
			y = g.player.rect.y,
			width = f32(g.player.texture.width),
			height = f32(g.player.texture.height),
		},
		0.8,
		rl.PURPLE,
	)
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
		} else if rl.CheckCollisionPointRec(mouse, g.player.rect) {
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

update :: proc() {
	update_debug()
	if rl.IsKeyPressed(.LEFT_ALT) {
		// g.is_paused = !g.is_paused
		g.is_debug_mode = !g.is_debug_mode
	}

	if g.is_paused || g.is_debug_mode {
		return
	}

	for &p in g.projectiles {
		// p.rotation += 1
		pos := entity_get_position(p)
		pos.x -= p.auto_speed.x
		entity_set_position(&p.entity, pos)
	}

	colliding_entity: ^Entity
	for &p in g.projectiles {
		if (entity_is_colliding_with(g.player.entity, p.entity)) {
			g.player.health -= 1
			g.player.is_being_hit = true
			colliding_entity = &p
			g.player.collided_with = &p
			break
		} else {
			g.player.is_being_hit = false
		}
	}

	if colliding_entity != nil && rl.IsKeyPressed(.SPACE) {
		g.player.is_parrying = true
	}

	if colliding_entity == nil && g.player.is_parrying {
		g.player.is_parrying = false
	}

	debug("%v", g.player.health)

	// g.camera_pos += {g.camera_speed, 0}
	// g.player.rect.x += g.player.auto_speed.x
	// g.player.rect.y += g.player.auto_speed.y
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


	input = linalg.normalize0(input)
	g.player.rect.x += (input * rl.GetFrameTime() * 100).x
	g.player.rect.y += (input * rl.GetFrameTime() * 100).y

}

render :: proc() {
	rl.DrawRectangle(0, 0, 20, 20, rl.RED)
	for b in g.obstacles {
		rl.DrawRectangleV(b, {f32(TILE_SIZE), f32(TILE_SIZE)}, rl.GREEN)
	}
	rl.DrawRectangle(0, 0, PIXEL_WINDOW_HEIGHT, 20, rl.BLUE)
	rl.DrawTextureEx(g.player.texture, get_player_pos(), 0, 1, rl.WHITE)
	for p in g.projectiles {
		rl.DrawTextureEx(
			p.base_texture,
			entity_get_position(p.entity),
			p.rotation,
			1,
			hex_to_color(p.hex),
		)
	}
	if g.player.is_being_hit {
		rl.ClearBackground(rl.RED)
		rl.DrawRectangle(0, 0, 20, 20, rl.RED)
	}
	if g.player.is_parrying {
		rl.DrawRectangleV(get_player_pos(), {20, 20}, rl.PURPLE)
	}
	if g.is_debug_mode {
		render_debug()
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
		if g.is_debug_mode {
			render_debug_f3()
		}
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
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Odin + Raylib + Hot Reload template!")
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(500)
	rl.SetExitKey(nil)
}

@(export)
game_init :: proc() {
	g = new(Game_Memory)

	player_texture := rl.LoadTexture("assets/witch.png")
	projectile_texture := rl.LoadTexture("assets/tv.png")
	center := screen_center()

	player: Player = {
		rect         = {center.x, center.y, f32(player_texture.width), f32(player_texture.height)},
		auto_speed   = {0.12, 0},
		hex_channels = {},
		health       = 0xA,
		texture      = player_texture,
	}


	g^ = Game_Memory {
		debug        = d,
		player       = player,
		run          = true,
		some_number  = 100,
		projectiles  = {
			new_random_projectile(projectile_texture, 0),
			new_random_projectile(projectile_texture, 1),
			new_random_projectile(projectile_texture, 2),
		},
		// You can put textures, sounds and music in the `assets` folder. Those
		// files will be part any release or web build.
		zoom         = 1,
		camera_speed = 0.1,
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
	for &o, i in g.obstacles {
		o = rl.Vector2{f32(i * TILE_SIZE), f32(i * TILE_SIZE)}
	}
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
