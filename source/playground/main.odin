package main
import "core:fmt"

Game_Flag :: enum {
	SHOW_DEBUG_MESSAGES,
	SHOW_DEBUG_MESSAGES2,
	SHOW_DEBUG_MESSAGES3,
	SHOW_DEBUG_MESSAGES4,
}

Game_Flags :: distinct bit_set[Game_Flag;int]

main :: proc() {
	flags := Game_Flags{.SHOW_DEBUG_MESSAGES, .SHOW_DEBUG_MESSAGES4}
	fmt.printfln("%#v", .SHOW_DEBUG_MESSAGES in flags)
}
