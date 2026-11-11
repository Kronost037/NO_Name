package ui

import "core:unicode/utf8"

graphics_draw_aligned_text :: proc(
	ctx: ^Graphics_Context,
	text: string,
	x, y, available_width, font_size, letter_spacing: f64,
	color: Color,
	align: string,
) {
	draw_x := x
	text_width := graphics_measure_text(ctx, text, font_size, letter_spacing)
	switch align {
	case "center":
		draw_x += (available_width - text_width) / 2
	case "right":
		draw_x += available_width - text_width
	}
	graphics_draw_text(ctx, text, draw_x, y, font_size, letter_spacing, color)
}

// Draw text within a node's content width. Layout remains explicit; this only
// wraps the visual text so a long label cannot bleed into a neighbouring node.
graphics_draw_wrapped_text :: proc(
	ctx: ^Graphics_Context,
	text: string,
	x, y, max_width, max_height, font_size, line_height, letter_spacing: f64,
	color: Color,
	align: string,
) {
	if text == "" || max_width <= 0 || max_height <= 0 {
		return
	}

	actual_line_height := line_height
	if actual_line_height <= 0 {
		actual_line_height = font_size * 1.25
	}
	line_y := y
	line_start := 0
	last_space := -1
	i := 0

	for i < len(text) {
		if text[i] == '\n' {
			if line_y + font_size > y + max_height {
				return
			}
			graphics_draw_aligned_text(ctx, text[line_start:i], x, line_y, max_width, font_size, letter_spacing, color, align)
			line_y += actual_line_height
			i += 1
			line_start = i
			last_space = -1
			continue
		}

		if text[i] == ' ' {
			last_space = i
		}

		_, glyph_size := utf8.decode_rune_in_string(text[i:])
        next_i := i + glyph_size
        candidate := text[line_start : next_i]
		candidate_width := graphics_measure_text(ctx, candidate, font_size, letter_spacing)
		if candidate_width > max_width {
			break_at := i
			next_start := i
			if last_space >= line_start {
				break_at = last_space
				next_start = last_space + 1
			} else if i == line_start {
				// Even a single oversized glyph must advance the cursor.
				break_at = next_i
				next_start = next_i
			}

			if line_y + font_size > y + max_height {
				return
			}
			graphics_draw_aligned_text(ctx, text[line_start:break_at], x, line_y, max_width, font_size, letter_spacing, color, align)
			line_y += actual_line_height
			line_start = next_start
			i = next_start
			last_space = -1
			continue
		}

		i = next_i
	}

	if line_start < len(text) && line_y + font_size <= y + max_height {
		graphics_draw_aligned_text(ctx, text[line_start:], x, line_y, max_width, font_size, letter_spacing, color, align)
	}
}
