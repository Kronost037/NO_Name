package main

import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

// Get a fully resolved property value for rendering.  The parser stores a theme
// reference without its '$' prefix, so rendering must use the canonical resolver
// rather than inspecting the raw declaration.
get_node_property :: proc(
	node: ^Node,
	prop_name: string,
	active_theme: Theme_Definition,
) -> string {
	return get_resolved_property(node, prop_name, active_theme)
}

// Raylib backend implementation of graphics abstraction

graphics_init_raylib :: proc(width: i32, height: i32, title: cstring) -> Graphics_Context {
	rl.InitWindow(width, height, title)
	rl.SetTargetFPS(60)

	ctx := Graphics_Context {
		_backend_data = nil,
		width         = width,
		height        = height,
		initialized   = rl.IsWindowReady(),
	}

	return ctx
}

graphics_shutdown_raylib :: proc(ctx: ^Graphics_Context) {
	if ctx.initialized {
		rl.CloseWindow()
		ctx.initialized = false
	}
}

graphics_should_close_raylib :: proc(ctx: ^Graphics_Context) -> bool {
	return !ctx.initialized || rl.WindowShouldClose()
}

graphics_begin_frame_raylib :: proc(ctx: ^Graphics_Context) {
	rl.BeginDrawing()
}

graphics_end_frame_raylib :: proc(ctx: ^Graphics_Context) {
	rl.EndDrawing()
}

graphics_clear_raylib :: proc(ctx: ^Graphics_Context, color: Color) {
	rl_color := rl.Color{color.r, color.g, color.b, color.a}
	rl.ClearBackground(rl_color)
}

graphics_draw_rect_raylib :: proc(ctx: ^Graphics_Context, rect: Rect, color: Color, filled: bool) {
	rl_color := rl.Color{color.r, color.g, color.b, color.a}

	if filled {
		rl.DrawRectangle(i32(rect.x), i32(rect.y), i32(rect.width), i32(rect.height), rl_color)
	} else {
		rl.DrawRectangleLines(
			i32(rect.x),
			i32(rect.y),
			i32(rect.width),
			i32(rect.height),
			rl_color,
		)
	}
}

graphics_draw_text_raylib :: proc(
	ctx: ^Graphics_Context,
	text: string,
	x: f64,
	y: f64,
	font_size: f64,
	color: Color,
) {
	rl_color := rl.Color{color.r, color.g, color.b, color.a}
	// Odin strings are length-delimited, not NUL-terminated. DrawText accepts a
	// C string, so a direct raw_data conversion makes raylib read into adjacent
	// allocations (often the next property declaration) and draw it as text.
	cstr := strings.clone_to_cstring(text)
	defer delete(cstr)

	rl.DrawText(cstr, i32(x), i32(y), i32(font_size), rl_color)
}

// Draw text within a node's content width. Layout remains explicit; this only
// wraps the visual text so a long label cannot bleed into a neighbouring node.
graphics_draw_wrapped_text_raylib :: proc(
	ctx: ^Graphics_Context,
	text: string,
	x, y, max_width, max_height, font_size: f64,
	color: Color,
) {
	if text == "" || max_width <= 0 || max_height <= 0 {
		return
	}

	line_height := font_size * 1.25
	line_y := y
	line_start := 0
	last_space := -1
	i := 0

	for i < len(text) {
		if text[i] == '\n' {
			if line_y + font_size > y + max_height {
				return
			}
			graphics_draw_text_raylib(ctx, text[line_start:i], x, line_y, font_size, color)
			line_y += line_height
			i += 1
			line_start = i
			last_space = -1
			continue
		}

		if text[i] == ' ' {
			last_space = i
		}

		candidate := text[line_start : i + 1]
		candidate_cstr := strings.clone_to_cstring(candidate)
		candidate_width := f64(rl.MeasureText(candidate_cstr, i32(font_size)))
		delete(candidate_cstr)
		if candidate_width > max_width {
			break_at := i
			next_start := i
			if last_space >= line_start {
				break_at = last_space
				next_start = last_space + 1
			} else if i == line_start {
				// Even a single oversized glyph must advance the cursor.
				break_at = i + 1
				next_start = i + 1
			}

			if line_y + font_size > y + max_height {
				return
			}
			graphics_draw_text_raylib(ctx, text[line_start:break_at], x, line_y, font_size, color)
			line_y += line_height
			line_start = next_start
			i = next_start
			last_space = -1
			continue
		}

		i += 1
	}

	if line_start < len(text) && line_y + font_size <= y + max_height {
		graphics_draw_text_raylib(ctx, text[line_start:], x, line_y, font_size, color)
	}
}

// Update interaction state based on mouse input
graphics_update_input_raylib :: proc(ctx: ^Graphics_Context, root_node: ^Node) {
	mouse_x := f64(rl.GetMouseX())
	mouse_y := f64(rl.GetMouseY())
	mouse_down := rl.IsMouseButtonDown(.LEFT)

	// Update hover and pressed states recursively
	update_node_interaction(root_node, mouse_x, mouse_y, mouse_down)
}

// Recursively update interaction states for all nodes
update_node_interaction :: proc(node: ^Node, mouse_x: f64, mouse_y: f64, mouse_down: bool) {
	if node == nil {
		return
	}

	// Check if mouse is inside this node's rect
	is_inside :=
		mouse_x >= node.rect.x &&
		mouse_x < node.rect.x + node.rect.width &&
		mouse_y >= node.rect.y &&
		mouse_y < node.rect.y + node.rect.height

	node.interaction.hover = is_inside
	node.interaction.pressed = is_inside && mouse_down

	// Update children
	for child in node.children {
		update_node_interaction(child, mouse_x, mouse_y, mouse_down)
	}
}

// Render node tree to screen
render_node_tree :: proc(ctx: ^Graphics_Context, node: ^Node, active_theme: Theme_Definition) {
	if node == nil {
		return
	}

	// Containers and panels are pure rectangles; only text-like nodes render labels.
	is_text_like := node.origin_definition == "Text" || node.origin_definition == "Button"

	// Get background color from computed style and resolve theme refs
	bg_color_str := get_node_property(node, "background", active_theme)
	if bg_color_str == "" {
		bg_color_str = "#000000"
	}
	bg_color := hex_to_color(bg_color_str)

	// The design language specifies a visual body only for non-transparent
	// backgrounds. This keeps text nodes from looking like debug rectangles.
	if bg_color.a != 0 {
		graphics_draw_rect(ctx, node.rect, bg_color, true)
	}

	// Only render text for real UI label/button nodes
	if is_text_like {
		content_str := get_node_property(node, "content", active_theme)
		if content_str != "" {
			font_size_str := get_node_property(node, "font_size", active_theme)
			font_size := parse_number_gfx(font_size_str, 16)

			text_color_str := get_node_property(node, "text_color", active_theme)
			if text_color_str == "" {
				text_color_str = get_node_property(node, "text", active_theme)
			}
			if text_color_str == "" {
				text_color_str = "#EEEEEE"
			}

			text_color := hex_to_color(text_color_str)
			padding_str := get_node_property(node, "padding", active_theme)
			padding := parse_number_gfx(padding_str, 4)

			graphics_draw_wrapped_text_raylib(
				ctx,
				content_str,
				node.rect.x + padding,
				node.rect.y + padding,
				node.rect.width - 2 * padding,
				node.rect.height - 2 * padding,
				font_size,
				text_color,
			)
		}
	}

	for child in node.children {
		render_node_tree(ctx, child, active_theme)
	}
}

// Safe number parsing for graphics (with defaults)
parse_number_gfx :: proc(value: string, default: f64) -> f64 {
	num, ok := strconv.parse_f64(value)
	if !ok {
		return default
	}
	if num < 0 {
		return default
	}
	return num
}
