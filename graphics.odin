package main

// Abstract graphics interface
// Allows swapping raylib for SDL, WebGL, or other backends
// by implementing these procedures with a different graphics backend

// Graphics context (opaque to caller, backend-specific)
Graphics_Context :: struct {
	_backend_data: rawptr,
	width:         i32,
	height:        i32,
	initialized:   bool,
}

// Color representation (RGBA)
Color :: struct {
	r: u8,
	g: u8,
	b: u8,
	a: u8,
}

// Converts the design language's color values to RGBA. Color tokens are stored
// without their leading '#' by the parser, while named colors remain identifiers.
hex_to_color :: proc(value: string) -> Color {
	switch value {
	case "white":
		return Color{255, 255, 255, 255}
	case "black":
		return Color{0, 0, 0, 255}
	case "transparent":
		return Color{0, 0, 0, 0}
	}

	start := 0
	if len(value) > 0 && value[0] == '#' {
		start = 1
	}
	remaining := len(value) - start
	if remaining != 6 && remaining != 8 {
		return Color{0, 0, 0, 255}
	}

	r := hex_byte(value[start : start + 2])
	g := hex_byte(value[start + 2 : start + 4])
	b := hex_byte(value[start + 4 : start + 6])
	a: u8 = 255
	if remaining == 8 {
		a = hex_byte(value[start + 6 : start + 8])
	}

	return Color{r, g, b, a}
}

hex_byte :: proc(hex: string) -> u8 {
	val: u8 = 0
	for c in hex {
		val *= 16
		if c >= '0' && c <= '9' {
			val += u8(c - '0')
		} else if c >= 'a' && c <= 'f' {
			val += u8(c - 'a' + 10)
		} else if c >= 'A' && c <= 'F' {
			val += u8(c - 'A' + 10)
		}
	}
	return val
}

// Graphics API (backend-specific implementation)
graphics_init :: proc(width: i32, height: i32, title: cstring) -> Graphics_Context {
	return graphics_init_raylib(width, height, title)
}

graphics_shutdown :: proc(ctx: ^Graphics_Context) {
	graphics_shutdown_raylib(ctx)
}

graphics_should_close :: proc(ctx: ^Graphics_Context) -> bool {
	return graphics_should_close_raylib(ctx)
}

graphics_begin_frame :: proc(ctx: ^Graphics_Context) {
	graphics_begin_frame_raylib(ctx)
}

graphics_end_frame :: proc(ctx: ^Graphics_Context) {
	graphics_end_frame_raylib(ctx)
}

graphics_clear :: proc(ctx: ^Graphics_Context, color: Color) {
	graphics_clear_raylib(ctx, color)
}

graphics_draw_rect :: proc(ctx: ^Graphics_Context, rect: Rect, color: Color, filled: bool) {
	graphics_draw_rect_raylib(ctx, rect, color, filled)
}

graphics_draw_text :: proc(
	ctx: ^Graphics_Context,
	text: string,
	x: f64,
	y: f64,
	font_size: f64,
	color: Color,
) {
	graphics_draw_text_raylib(ctx, text, x, y, font_size, color)
}

graphics_update_input :: proc(ctx: ^Graphics_Context, root_node: ^Node) {
	graphics_update_input_raylib(ctx, root_node)
}
