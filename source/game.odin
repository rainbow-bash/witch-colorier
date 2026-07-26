#+feature dynamic-literals
#+feature dynamic-literals
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
import gl "debug"
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

Mode :: enum {
	NIL,
	DEBUG,
	GAME,
}

mode: Mode = .GAME

Entity_State :: struct {
	start:          time.Time,
	action:         Entity_Action_State,
	death_duration: time.Duration,
	is_dead:        bool,
}


Flags :: struct {
	can_parry: bool,
}

Entity_Kind :: enum {
	PLAYER,
	PROJECTILE,
	INK,
	BALL,
	RAY,
}

Entity_Family :: enum {
	MANE_SIX,
	MSN_MESSENGER,
}

Render :: struct {}

Entity :: struct {
	name:          string,
	core_damage:   int,
	kind:          Entity_Kind,
	parry_time:    time.Duration,
	auto_speed:    rl.Vector2,
	movement:      rl.Vector2,
	animate:       anime.Anime,
	rects:         Entity_Rectangles,
	family:        Entity_Family,
	health:        int,
	max_health:    int,
	collided_with: [dynamic]^Entity,
	state:         Entity_State,
	scale:         f32,
	tint:          rl.Color,
	flags:         Flags,
	rotation:      f32,
	hex:           rl.Color,
	parent:        ^Entity,
}

new_entity :: proc(position: rl.Vector2, texture: rl.Texture, i := 0) -> Entity {
	position := position
	position.x += f32(texture.width) * 2.0
	position.y += f32(texture.height * i32(i))
	scale: f32 = 0.5

	height := f32(f32(texture.height) * scale)
	width := f32(f32(texture.width) * scale)
	rects := entity_generate_rectangles(position, width, height)

	r := u8(rand.uint32())
	g := u8(rand.uint32())
	b := u8(rand.uint32())


	ent := Entity {
		rects = rects,
		state = {death_duration = time.Millisecond * PROJECTILE_DEATH_DURATION},
		health = 1,
		scale = scale,
		hex = {r, g, b, 0},
		auto_speed = 0.15,
	}

	return ent
}

Collision_Rect_Kind :: enum {
	OUTERMOST,
	PARRY,
	CORE,
}

Collision_Rect :: struct {
	using rect:     rl.Rectangle,
	kind:           Collision_Rect_Kind,
	last_collision: time.Time,
	target:         ^Entity,
	is_colliding:   bool,
	is_action:      bool,
	collided_with:  [dynamic]^Entity,
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
		outermost = {rect = {x, y, width, height}, kind = .OUTERMOST},
		parry = {rect = {par_x, par_y, par_w, par_h}, kind = .PARRY},
		core = {rect = {col_x, col_y, col_w, col_h}, kind = .CORE},
	}
}

entity_get_position :: proc(entity: ^Entity) -> rl.Vector2 {
	return {entity.rects.outermost.x, entity.rects.outermost.y}
}

entity_get_size :: proc(entity: Entity) -> rl.Vector2 {
	return {entity.rects.outermost.width, entity.rects.outermost.height}
}

entity_draw_rects :: proc(entity: ^Entity) {
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

entity_update_collision_state :: proc(
	self: ^Entity,
	self_rect: ^Collision_Rect,
	target_rect_kind: Collision_Rect_Kind,
) {
	gl.msg("%#v", self_rect)
	{
		last_collision: time.Time
		is_colliding := false
		collided_with: [dynamic]^Entity

		for other in g.entities {
			if other == self {
				continue
			}
			target_rect: ^Collision_Rect
			switch (target_rect_kind) {
			case .OUTERMOST:
				target_rect = &other.rects.outermost
			case .PARRY:
				target_rect = &other.rects.parry
			case .CORE:
				target_rect = &other.rects.core
			}
			is, lc := entity_check_collision(
				self, //
				self_rect,
				other,
				target_rect,
			)
			if is {
				last_collision = lc
				is_colliding = is
				append(&collided_with, other)
			}
			target_rect.last_collision = last_collision
			self_rect.last_collision = last_collision
			gl.msg("%#v", time.since(last_collision))
		}
		self_rect.is_colliding = is_colliding
		for ent in collided_with {
			append(&self.collided_with, ent)
		}
	}
}

entity_update_position :: proc(entity: ^Entity) {
	movement := (entity.movement * rl.GetFrameTime() * 50)

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
}

new_random_projectile :: proc(i := 0) -> ^Projectile {
	// position := rl.GetScreenToWorld2D({f32(rand.int63()), f32(rand.int63())})
	// w := f32(rl.GetScreenWidth())
	animate := anime.new_anime()
	texture := anime.insert_animation(&animate, "assets/computer.png", "idle")
	position: rl.Vector2 = {0, 0}
	position.x += f32(texture.width) * 2.0
	position.y += f32(texture.height * i32(i))
	scale: f32 = 0.5

	height := f32(f32(texture.height) * scale)
	width := f32(f32(texture.width) * scale)
	rects := entity_generate_rectangles(position, width, height)


	r := u8(rand.uint32())
	g := u8(rand.uint32())
	b := u8(rand.uint32())


	p := new(Projectile)
	p^ = Projectile {
		rects = rects,
		animate = animate,
		state = {death_duration = time.Millisecond * PROJECTILE_DEATH_DURATION},
		health = 1,
		scale = scale,
		hex = {r, g, b, 0},
		auto_speed = 0.15,
	}

	return p
}

Game_Flag :: enum {
	SHOW_DEBUG_MESSAGES,
}

Game_Flags :: distinct bit_set[Game_Flag;int]

Game_Memory :: struct {
	debug:         ^Debug,
	flags:         Game_Flags,
	is_debug_mode: bool,
	is_paused:     bool,
	player:        ^Player,
	camera_pos:    rl.Vector2,
	obstacles:     [24]rl.Vector2,
	projectiles:   [3]Projectile,
	entities:      [dynamic]^Entity,
	animes:        [dynamic]^anime.Anime,
	camera_speed:  f32,
	some_number:   int,
	run:           bool,
	blocks:        [TILE_COLS * 6]rl.Rectangle,
	zoom:          f32,
	ui_zoom:       f32,
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

ui_camera :: proc() -> rl.Camera2D {
	return {zoom = f32(rl.GetScreenHeight()) / PIXEL_WINDOW_HEIGHT + g.ui_zoom}
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
	if .SHOW_DEBUG_MESSAGES in g.flags {
		gl.render_messages()
	}
}

render_debug :: proc() {
	for ent in g.entities {
		entity_draw_rects(ent)
	}
}

// TODO: make an ui context where the ui elements are stacked,
//			 and everytime a rectangle is drawn add the height (column) or width (row) of that shape, so the next y or x in the current context gets updated to that
render_ui :: proc() {
	end := int(rl.GetScreenToWorld2D({0, f32(rl.GetScreenHeight())}, ui_camera()).y)
	y := end - HEX_SQUARE_HEIGHT * 3

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
		zoom := rl.IsKeyDown(.LEFT_SHIFT)
		if zoom {
			y := rl.GetMouseWheelMove()
			g.ui_zoom = g.ui_zoom + y
			if g.ui_zoom < -5 {
				g.ui_zoom = -5
			}
		} else {
			y := rl.GetMouseWheelMove()
			g.zoom = g.zoom + y
			if g.zoom < -5 {
				g.zoom = -5
			}
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

	if rl.IsKeyPressed(.F3) {
		g.flags ~= Game_Flags{.SHOW_DEBUG_MESSAGES}
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

	// entity_update_position(&g.player.entity, input)
	g.player.entity.movement = input

	for ent in g.entities {
		// update collisions
		entity_update_collision_state(ent, &ent.rects.parry, .OUTERMOST)
		entity_update_collision_state(ent, &ent.rects.core, .OUTERMOST)
		// update animations
		err := anime.update_current(&ent.animate)
		if err != nil {
			gl.msg("%#v", err)
		}
		// update position
		entity_update_position(ent)
	}
	// anime.update(&animem, "idle")

	update_debug()
	// anime.update_animation(&g.player.animations.idle.animation)

	parry := &g.player.rects.parry

	can_parry := time.since(parry.last_collision) < g.player.entity.parry_time

	if rl.IsKeyDown(.L) && can_parry {
		parry.is_action = true
		parry.target.state.is_dead = true
		player_add_hex_color(parry.target.hex)
	} else {
		parry.is_action = false
	}

	if rl.IsKeyPressed(.K) {
		player_attack(.BALL)
	}


}

animFrames: i32

currentAnimFrame: i32 = 0 // Current animation frame to load and draw
frameDelay: i32 = 8 // Frame delay to switch between animation frames
frameCounter: i32 = 0
nextFrameDataOffset: i32 = 0

gImage := rl.LoadImageAnim("assets/idle.gif", &animFrames)
scarfy := rl.LoadTextureFromImage(gImage)

ptr: [^]byte

render :: proc() {

	for e in g.entities {
		if e.state.is_dead {
			continue
		}
		texture, err := anime.get_current_texture(e.animate)
		if err != nil {
			rl.DrawRectangleRec(g.player.rects.outermost, rl.BROWN)
		} else {
			rl.DrawTextureEx(texture, entity_get_position(e), e.rotation, e.scale, rl.WHITE)
		}
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
}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.DARKGRAY)


	rl.BeginMode2D(game_camera())
	if (mode == .DEBUG) {
		gl.render()
	} else {
		render()
	}
	rl.EndMode2D()

	// NOTE: `fmt.ctprintf` uses the temp allocator. The temp allocator is
	// cleared at the end of the frame by the main application, meaning inside
	// `main_hot_reload.odin`, `main_release.odin` or `main_web_entry.odin`.

	rl.BeginMode2D(ui_camera())
	{
		render_ui()
		if g.is_debug_mode {
		}
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
	gl.clear()
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


	player_animations := anime.new_anime()
	sparkles_animations := anime.new_anime()

	anime.insert_animation(&player_animations, "assets/idle.gif", "idle")
	anime.insert_animation(&sparkles_animations, "assets/sparkle.gif", "idle")

	center := screen_center()
	dimensions, _ := anime.get_current_texture_dimensions(player_animations)

	width := f32(dimensions.x)
	height := f32(dimensions.y)

	rects := entity_generate_rectangles(center, width, height)

	player := new(Player)
	player^ = {
		animate      = player_animations,
		rects        = rects,
		auto_speed   = {0.12, 0},
		hex_channels = {{15, 15, 15, 255}},
		health       = 0xF,
		max_health   = 0xF,
		scale        = 1,
		parry_time   = time.Millisecond * 500,
	}


	g^ = Game_Memory {
		flags         = {},
		is_debug_mode = true,
		debug         = &d,
		player        = player,
		run           = true,
		some_number   = 100,
		entities      = {
			player,
			new_random_projectile(0),
			new_random_projectile(1),
			// new_random_projectile(projectile_texture, 1),
			// new_random_projectile(projectile_texture, 2),
		},
		// projectiles   = {
		// 	new_random_projectile(projectile_texture, 0),
		// 	new_random_projectile(projectile_texture, 1),
		// 	new_random_projectile(projectile_texture, 2),
		// },
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
