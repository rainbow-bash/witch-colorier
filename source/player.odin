package game
import rl "vendor:raylib"


Attack :: struct {
	using entity: Entity,
}


Player :: struct {
	using entity:        Entity,
	attack_ball_texture: rl.Texture,
	hex_channels:        [1]rl.Color,
	attacks:             [dynamic]Attack,
}

// TODO: make a trail for the shooting
// rl.IsKeyPressed(.SPACE)
player_attack :: proc(kind: Entity_Kind) {
	width := f32(g.player.attack_ball_texture.width)
	height := f32(g.player.attack_ball_texture.height)

	pos := get_player_attack_position()
	debug("%#v", pos)
	rects := entity_generate_rectangles(pos, width, height)
	tint := g.player.hex_channels[0]
	append(
		&g.player.attacks,
		Attack {
			//
			kind       = kind,
			rects      = rects,
			auto_speed = {1, 0},
			tint       = tint,
			scale      = 0.4,
			rotation   = 0.7,
		},
	)
	player_sub_hex_color({16, 16, 16, 0})
}

player_add_hex_color :: proc(h: rl.Color) {
	g.player.hex_channels[0] += h
}

player_sub_hex_color :: proc(h: rl.Color) {
	_r := int(h[0])
	_g := int(h[1])
	_b := int(h[2])

	red := int(g.player.hex_channels[0][0])
	green := int(g.player.hex_channels[0][1])
	blue := int(g.player.hex_channels[0][2])

	rResult := red - _r
	gResult := green - _g
	bResult := blue - _b

	if rResult < 0 {
		rResult = 0
	}

	if gResult < 0 {
		gResult = 0
	}

	if bResult < 0 {
		bResult = 0
	}


	g.player.hex_channels[0][0] = u8(rResult)
	g.player.hex_channels[0][1] = u8(gResult)
	g.player.hex_channels[0][2] = u8(bResult)

}

get_player_attack_position :: proc() -> rl.Vector2 {
	rect := g.player.rects.outermost
	return rl.Vector2{rect.x + rect.width, rect.y + rect.height / 2}
}
