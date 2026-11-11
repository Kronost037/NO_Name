package ui

import "core:strconv"

// Render node tree to screen
render_node_tree :: proc(ctx: ^Graphics_Context, node: ^Node, active_theme: Theme_Definition) {
	if node == nil {
		return
	}

	// Containers and panels are pure rectangles; only text-like nodes render labels.
	is_text_like := node.primitive == .Text || node.primitive == .Button

	// Get background color from computed style and resolve theme refs
	bg_color_str := get_resolved_property(node, "background", active_theme)
	if bg_color_str == "" {
		bg_color_str = "#000000"
	}
	bg_color := hex_to_color(bg_color_str)
	radius := parse_number_gfx(get_resolved_property(node, "radius", active_theme), 0)
	border_color := hex_to_color(get_resolved_property(node, "border_color", active_theme))
	border_width := parse_number_gfx(get_resolved_property(node, "border_width", active_theme), 0)

	// Transparent nodes remain text-only unless they explicitly declare a border.
	if bg_color.a != 0 || (border_color.a != 0 && border_width > 0) {
		graphics_draw_box(ctx, node.rect, bg_color, border_color, radius, border_width)
	}

	// Only render text for real UI label/button nodes
	if is_text_like {
		content_str := get_resolved_property(node, "content", active_theme)
		if content_str != "" && node.rect.width > 0 && node.rect.height > 0 {
			font_size_str := get_resolved_property(node, "font_size", active_theme)
			font_size := parse_number_gfx(font_size_str, 16)

			text_color_str := get_resolved_property(node, "text_color", active_theme)
			if text_color_str == "" {
				text_color_str = get_resolved_property(node, "text", active_theme)
			}
			if text_color_str == "" {
				text_color_str = "#EEEEEE"
			}

			text_color := hex_to_color(text_color_str)
			padding_str := get_resolved_property(node, "padding", active_theme)
			padding := parse_number_gfx(padding_str, 4)
			text_align := get_resolved_property(node, "text_align", active_theme)
			vertical_align := get_resolved_property(node, "text_vertical_align", active_theme)
			line_height := parse_number_gfx(get_resolved_property(node, "line_height", active_theme), 0)
			letter_spacing := parse_number_gfx(get_resolved_property(node, "letter_spacing", active_theme), 0)
			content_x := node.rect.x + padding
			content_y := node.rect.y + padding
			content_width := node.rect.width - 2 * padding
			content_height := node.rect.height - 2 * padding

            if vertical_align == "middle" {
                content_y = node.rect.y + (node.rect.height - font_size) / 2
            } else if vertical_align == "bottom" {
                content_y = node.rect.y + node.rect.height - padding - font_size
            }
            if node.primitive == .Button {
				graphics_draw_aligned_text(
					ctx,
					content_str,
					content_x,
					content_y,
					content_width,
					font_size,
					letter_spacing,
					text_color,
					text_align,
				)
			} else {
				if text_align == "" {
					text_align = "left"
				}

				graphics_draw_wrapped_text(
					ctx,
					content_str,
					content_x,
					content_y,
					content_width,
					content_height,
					font_size,
					line_height,
					letter_spacing,
					text_color,
					text_align,
				)
			}
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
