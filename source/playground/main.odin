package main
import "../anime"
import "core:fmt"
import rl "vendor:raylib"

main :: proc() {
	mem := anime.new_anime()
	size: i32 = 720
	rl.InitWindow(size, size, "hello")
	rl.SetTargetFPS(60) // Set our game to run at 60 frames-per-second
	defer rl.CloseWindow()

	anime.insert_animation(
		&mem,
		"/home/marcy/Documents/projects/games/witch-colorier/assets/idle.gif",
		"idle",
	)

	for !rl.WindowShouldClose() {
		fmt.printfln("%#v", mem)
		{
			err := anime.update_current(&mem)
			if err != nil {
				rl.DrawText(fmt.caprintf("%#v", err), 0, 0, 20, rl.RED)
			}
		}
		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)
		texture, err := anime.get_current_texture(mem)
		if err != nil {
			rl.DrawText(fmt.caprintf("%#v", err), 0, 20, 20, rl.RED)
		} else {
			rl.DrawTextureEx(texture, {0, 0}, 0, 4, rl.WHITE)
		}
		rl.EndDrawing()
	}
}
