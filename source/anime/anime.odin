package anime

// import gl "../debug"
import "core:mem"
import rl "vendor:raylib"

Animation :: struct {
	img:           rl.Image,
	texture:       rl.Texture,
	frame_counter: i32,
	frame_idx:     i32,
	frame_delay:   i32,
	total_frames:  i32,
}

Animemory :: struct {
	owner:      string,
	current:    string,
	animations: map[string]Animation,
}

Error :: enum {
	None,
	NoAnimationsHashmap,
	NoAnimationForThatName,
}

update :: proc(self: ^Animemory, name: string) -> Error {
	if nil == self.animations {
		return .NoAnimationsHashmap
	}
	this, ok := &self.animations[name]
	if !ok {
		return .NoAnimationForThatName
	}
	this.frame_counter += 1
	if (this.frame_counter >= this.frame_delay) {
		// Move to next frame
		// NOTE: If final frame is reached we return to first frame
		this.frame_idx += 1
		if this.frame_idx >= this.total_frames {
			this.frame_idx = 0
		}

		// Get memory offset position for next frame data in image.data
		next_frame_data_offset := this.img.width * this.img.height * 4 * this.frame_idx

		// Update GPU texture data with next frame image data
		// WARNING: Data size (frame size) and pixel format must match already created texture
		x: [^]byte
		x = ([^]byte)(this.img.data)

		ptr := mem.ptr_offset(x, next_frame_data_offset)
		rl.UpdateTexture(this.texture, ptr)

		this.frame_counter = 0
	}
	return .None
}

new_memory :: proc(owner: string) -> Animemory {
	return {owner = owner, animations = make(map[string]Animation)}
}

insert_animation :: proc(self: ^Animemory, filepath: cstring, name: string, frame_delay: i32 = 8) {
	total_frames: i32
	img := rl.LoadImageAnim(filepath, &total_frames)
	texture := rl.LoadTextureFromImage(img)
	self.animations[name] = Animation {
		img           = img,
		texture       = texture,
		frame_counter = 0,
		frame_idx     = 0,
		frame_delay   = frame_delay,
		total_frames  = total_frames,
	}
}

set_animation :: proc(self: ^Animemory, name: string) -> bool {
	_, ok := self.animations[name]
	if ok {
		self.current = name
	}
	return ok
}

get_current_texture :: proc(self: Animemory) -> (rl.Texture, bool) {
	animation, ok := self.animations[self.current]
	if !ok {
		return {}, false
	}
	return animation.texture, true
}
