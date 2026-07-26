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


Anime :: struct {
	animations: map[string]Animation,
	current:    string,
}

Error :: enum {
	None,
	NoAnimationsHashmapForThisOwner,
	NoAnimationsHashmap,
	NoAnimationForCurrentAnimationOrCurrentAnimationIsEmptyString,
	NoAnimationForThatName,
}

update_current :: proc(self: ^Anime) -> Error {
	if nil == self {
		return .NoAnimationsHashmap
	}

	this, ok := &self.animations[self.current]
	if !ok {
		return .NoAnimationForCurrentAnimationOrCurrentAnimationIsEmptyString
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

new_anime :: proc() -> Anime {
	return {animations = make(map[string]Animation), current = ""}
}

//
insert_animation :: proc(
	self: ^Anime,
	filepath: cstring,
	name: string,
	frame_delay: i32 = 8,
	set_animation := true,
) -> rl.Texture {
	total_frames: i32
	img := rl.LoadImageAnim(filepath, &total_frames)
	texture := rl.LoadTextureFromImage(img)

	old, ok := self.animations[name]

	if ok {
		rl.UnloadTexture(old.texture)
		rl.UnloadImage(old.img)
	}

	self.animations[name] = Animation {
		img           = img,
		texture       = texture,
		frame_counter = 0,
		frame_idx     = 0,
		frame_delay   = frame_delay,
		total_frames  = total_frames,
	}

	if set_animation {
		self.current = name
	}


	return texture
}

clean :: proc(self: ^Anime) {
	for k, v in self.animations {
		rl.UnloadTexture(v.texture)
		rl.UnloadImage(v.img)
	}
}

use_animation :: proc(self: ^Anime, name: string) {
	self.current = name
}

get_current_texture :: proc(self: Anime) -> (rl.Texture, Error) {

	animation, ok := self.animations[self.current]

	if !ok {
		return {}, .NoAnimationForThatName
	}

	return animation.texture, .None
}

get_current_texture_dimensions :: proc(self: Anime) -> ([2]i32, Error) {
	texture, err := get_current_texture(self)
	if err != nil {
		return {}, err
	}
	return {texture.width, texture.height}, .None
}
