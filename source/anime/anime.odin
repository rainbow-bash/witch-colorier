package anime

import rl "vendor:raylib"

Animation :: struct {
	first:         int,
	last:          int,
	current:       int,
	duration:      f32,
	duration_left: f32,
}

Memory :: struct {
	owner:      string,
	animations: map[string]^Animation,
}

new_memory :: proc(owner: string) -> Memory {
	return {owner = owner, animations = make(map[string]^Animation)}
}

update :: proc(self: ^Memory, name: string) -> bool {
	animation, ok := self.animations[name]
	if !ok {
		return false
	}
	update_animation(animation)
	return true
}

update_animation :: proc(self: ^Animation) {
	dt := rl.GetFrameTime()
	self.duration_left -= dt
	if self.duration_left <= 0 {
		self.duration_left = self.duration
		self.current += 1
		if self.current > self.last {
			self.current = self.first
			self.duration_left = self.duration
		}
	}
}


frame :: proc(
	self: ^Animation,
	frames_per_row: int,
	frame_tile_width: f32 = 23.0,
	frame_tile_heigth: f32 = 29.0,
) -> rl.Rectangle {
	x: f32 = f32(self.current % frames_per_row) * frame_tile_width
	y: f32 = f32(self.current / frames_per_row) * frame_tile_heigth
	width := frame_tile_width
	height := frame_tile_heigth

	return {x, y, width, height}
}
