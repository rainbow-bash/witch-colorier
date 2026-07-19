package debug
import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

Debug :: struct {
	persisted_messages: [dynamic]string,
	messages:           [dynamic]string,
}

d: Debug

msg :: proc(format: string, args: ..any) {
	append(&d.messages, fmt.aprintf(format, ..args))
}

persist :: proc(format: string, args: ..any) {
	append(&d.persisted_messages, fmt.aprintf(format, ..args))
}

once :: proc(format: string, args: ..any) {
	if len(d.messages) == 0 {
		msg(format, ..args)
	}
}

calculate_text_height :: proc(text: string, font_size: i32) -> i32 {
	h := 2
	for c in text {
		if c == '\n' {
			h += 1
		}
	}

	height := i32(h) * i32(f32(font_size))

	return height
}


clear :: proc() {
	d.messages = nil
}

reset :: proc() {
	d.messages = nil
	d.persisted_messages = nil
}

render :: proc() {
	y: i32 = 0
	font_size: i32 = 12
	{
		msg := strings.join(d.messages[:], "\n")
		if msg != "" {
			fmt.printfln("%#v", msg)
		}
		txt := strings.clone_to_cstring(msg)
		rl.DrawText(txt, 0, y, font_size, rl.WHITE)
		y = calculate_text_height(msg, font_size)
	}
	{
		msg := strings.join(d.persisted_messages[:], "\n")
		txt := strings.clone_to_cstring(msg)
		rl.DrawText(txt, 0, y, font_size, rl.WHITE)
	}
}
