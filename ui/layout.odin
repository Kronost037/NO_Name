package ui

import "core:strconv"

// Content area of a node after applying padding
Content_Area :: struct {
	x:      f64,
	y:      f64,
	width:  f64,
	height: f64,
}

// Get layout mode from node properties
get_layout_mode :: proc(node: ^Node, active_theme: Theme_Definition) -> string {
	layout_value := get_resolved_property(node, "layout", active_theme)
	if layout_value == "" {
		return "free"
	}
	return layout_value
}

// Parse numeric property safely
parse_number :: proc(value: string) -> f64 {
	num, ok := strconv.parse_f64(value)
	if !ok {
		return 0
	}
	if num < 0 {
		return 0
	}
	return num
}

// Calculate content area (interior after padding)
get_content_area :: proc(node: ^Node, active_theme: Theme_Definition) -> Content_Area {
	padding_val := get_resolved_property(node, "padding", active_theme)
	padding := parse_number(padding_val)

	content := Content_Area {
		x      = node.rect.x + padding,
		y      = node.rect.y + padding,
		width  = node.rect.width - 2 * padding,
		height = node.rect.height - 2 * padding,
	}

	// Clamp to non-negative
	if content.width < 0 {
		content.width = 0
	}
	if content.height < 0 {
		content.height = 0
	}

	return content
}

// Layout children in free layout mode
layout_free :: proc(node: ^Node, active_theme: Theme_Definition) {
	if len(node.children) == 0 {
		return
	}

	content := get_content_area(node, active_theme)

	for child in node.children {
		// Get explicit x, y from child
		x_value := get_resolved_property(child, "x", active_theme)
		y_value := get_resolved_property(child, "y", active_theme)

		x, _ := strconv.parse_f64(x_value)
		y, _ := strconv.parse_f64(y_value)

		// Width and height are required
		width_value := get_resolved_property(child, "width", active_theme)
		height_value := get_resolved_property(child, "height", active_theme)

		width := parse_number(width_value)
		height := parse_number(height_value)

		// Position relative to parent's content area
		child.rect.x = content.x + x
		child.rect.y = content.y + y
		child.rect.width = width
		child.rect.height = height
	}
}

// Layout children in vertical layout mode
layout_vertical :: proc(node: ^Node, active_theme: Theme_Definition) {
	if len(node.children) == 0 {
		return
	}

	content := get_content_area(node, active_theme)
	gap_value := get_resolved_property(node, "gap", active_theme)
	gap := parse_number(gap_value)

	cursor_y := content.y

	for child_idx in 0 ..< len(node.children) {
		child := node.children[child_idx]

		// Width defaults to content width, height required
		width_value := get_resolved_property(child, "width", active_theme)
		height_value := get_resolved_property(child, "height", active_theme)

		width := parse_number(width_value)
		if !has_dimension(child, "width") {
			width = content.width
		}
		height := parse_number(height_value)

		// Position: leftmost at content.x, stacked vertically
		child.rect.x = content.x
		child.rect.y = cursor_y
		child.rect.width = width
		child.rect.height = height

		cursor_y += height + gap
	}
}

// Layout children in horizontal layout mode
layout_horizontal :: proc(node: ^Node, active_theme: Theme_Definition) {
	if len(node.children) == 0 {
		return
	}

	content := get_content_area(node, active_theme)
	gap_value := get_resolved_property(node, "gap", active_theme)
	gap := parse_number(gap_value)

	cursor_x := content.x

	for i in 0 ..< len(node.children) {
		// Width required, height defaults to content height
		width_value := get_resolved_property(node.children[i], "width", active_theme)
		height_value := get_resolved_property(node.children[i], "height", active_theme)

		width := parse_number(width_value)
		height := parse_number(height_value)
		if !has_dimension(node.children[i], "height") {
			height = content.height
		}

		// Position: topmost at content.y, stacked horizontally
		node.children[i].rect.x = cursor_x
		node.children[i].rect.y = content.y
		node.children[i].rect.width = width
		node.children[i].rect.height = height

		cursor_x += width + gap
	}
}

// Layout a single node's children based on its layout mode
layout_node :: proc(node: ^Node, active_theme: Theme_Definition) {
	if node == nil {
		return
	}

	layout_mode := get_layout_mode(node, active_theme)

	switch layout_mode {
	case "free":
		layout_free(node, active_theme)
	case "vertical":
		layout_vertical(node, active_theme)
	case "horizontal":
		layout_horizontal(node, active_theme)
	case:
		// Default to free
		layout_free(node, active_theme)
	}
}

// Recursively layout tree (depth-first)
layout_tree :: proc(node: ^Node, active_theme: Theme_Definition) {
	if node == nil {
		return
	}

	// Layout this node's children
	layout_node(node, active_theme)

	// Recursively layout each child
	for child in node.children {
		layout_tree(child, active_theme)
	}
}

// Main layout entry point
compute_layout :: proc(root: ^Node, active_theme: Theme_Definition) {
	if root == nil {
		return
	}

	// Root gets its explicit dimensions
	width_value := get_resolved_property(root, "width", active_theme)
	height_value := get_resolved_property(root, "height", active_theme)

	root.rect.x = 0
	root.rect.y = 0
	root.rect.width = parse_number(width_value)
	root.rect.height = parse_number(height_value)

	// Layout entire tree starting from root
	layout_tree(root, active_theme)
}

// Omitted cross-axis sizes fill their parent; explicit zero stays zero.
has_dimension :: proc(node: ^Node, name: string) -> bool {
    _, base := get_base_property_decl(node, name)
    _, state := get_active_state_decl(node, name)
    return base || state
}
