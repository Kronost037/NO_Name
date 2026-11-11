package ui

import "core:fmt"
validate_active_declarations :: proc(result: ^Semantic_Result, design: Design) {
	active_theme_count := 0
	for theme in design.themes {
		if theme.active {
			active_theme_count += 1
		}
	}
	if active_theme_count == 0 {
		append_error(result, "no active theme declared", 1, 1)
	} else if active_theme_count > 1 {
		append_error(result, "more than one active theme declared", 1, 1)
	}

	active_screen_count := 0
	for screen in design.screens {
		if screen.active {
			active_screen_count += 1
		}
	}
	if active_screen_count == 0 {
		append_error(result, "no active screen declared", 1, 1)
	} else if active_screen_count > 1 {
		append_error(result, "more than one active screen declared", 1, 1)
	}
}

validate_unique_names :: proc(result: ^Semantic_Result, names: []string, category: string) {
	for name, i in names {
		for j in 0 ..< i {
			if names[j] == name {
				append_error(result, fmt.aprintf("duplicate %s '%s'", category, name), 1, 1)
				break
			}
		}
	}
}

validate_declaration_names :: proc(result: ^Semantic_Result, design: Design) {
	theme_names: [dynamic]string
	component_names: [dynamic]string
	screen_names: [dynamic]string
	defer delete(theme_names)
	defer delete(component_names)
	defer delete(screen_names)
	for theme in design.themes {
		append(&theme_names, theme.name)
		if is_reserved_identifier(theme.name) {
			append_error(
				result,
				fmt.aprintf("reserved identifier '%s' cannot be used as a theme name", theme.name),
				theme.row,
				theme.col,
			)
		}
	}
	for component in design.components {
		append(&component_names, component.name)
		if is_reserved_identifier(component.name) {
			append_error(
				result,
				fmt.aprintf(
					"reserved identifier '%s' cannot be used as a component name",
					component.name,
				),
				component.row,
				component.col,
			)
		}
		if is_builtin_name(component.name) {
			append_error(
				result,
				fmt.aprintf("built-in component '%s' cannot be redefined", component.name),
				component.row,
				component.col,
			)
		}
	}
	for screen in design.screens {
		append(&screen_names, screen.name)
		if is_reserved_identifier(screen.name) {
			append_error(
				result,
				fmt.aprintf(
					"reserved identifier '%s' cannot be used as a screen name",
					screen.name,
				),
				screen.row,
				screen.col,
			)
		}
	}
	validate_unique_names(result, theme_names[:], "theme")
	validate_unique_names(result, component_names[:], "component")
	validate_unique_names(result, screen_names[:], "screen")
}

validate_component_declaration :: proc(
	result: ^Semantic_Result,
	design: Design,
	component: Component_Decl,
) {
	validate_duplicate_properties(
		result,
		component.properties,
		fmt.aprintf("component '%s'", component.name),
	)
	validate_duplicate_states(
		result,
		component.states,
		fmt.aprintf("component '%s'", component.name),
	)
	validate_state_properties(
		result,
		component.states,
		fmt.aprintf("component '%s'", component.name),
	)

	kind, _ := component_render_kind(design.components, component.name)
	validate_state_capabilities(
		result,
		component.states,
		kind,
		fmt.aprintf("component '%s'", component.name),
	)
	validate_node_property_set(result, component.properties, kind, "", false)
	validate_node_ids(result, Node_Decl{type_name = component.name, children = component.children})

	for property in component.properties {
		spec, ok := property_spec(property.name)
		if ok {
			validate_property_value(result, property, spec.type)
		}
	}

	for child in component.children {
		validate_component_node_reference(result, design.components, child)
	}

}

validate_screen :: proc(result: ^Semantic_Result, design: Design, screen: Screen_Decl) {
	validate_duplicate_properties(
		result,
		screen.properties,
		fmt.aprintf("screen '%s'", screen.name),
	)
	validate_duplicate_states(result, screen.states, fmt.aprintf("screen '%s'", screen.name))
	validate_state_properties(result, screen.states, fmt.aprintf("screen '%s'", screen.name))
	validate_state_capabilities(
		result,
		screen.states,
		.Generic,
		fmt.aprintf("screen '%s'", screen.name),
	)

	validate_node_property_set(result, screen.properties, .Generic, "", true)

	width, width_found := get_property_value(screen.properties, "width")
	height, height_found := get_property_value(screen.properties, "height")
	if !width_found {
		append_error(
			result,
			fmt.aprintf("screen '%s' requires a resolvable width", screen.name),
			screen.row,
			screen.col,
		)
	} else if width.kind != .Number && width.kind != .Theme_Ref {
		append_error(
			result,
			"screen width must be a number or compatible theme reference",
			screen.row,
			screen.col,
		)
	}
	if !height_found {
		append_error(
			result,
			fmt.aprintf("screen '%s' requires a resolvable height", screen.name),
			screen.row,
			screen.col,
		)
	} else if height.kind != .Number && height.kind != .Theme_Ref {
		append_error(
			result,
			"screen height must be a number or compatible theme reference",
			screen.row,
			screen.col,
		)
	}

	layout_mode := "free"
	if value, ok := get_property_value(screen.properties, "layout");
	   ok && value.kind == .Identifier {
		layout_mode = value.data
	}

	for child in screen.children {
		validate_component_node_reference(result, design.components, child)
		kind, ok := component_render_kind(design.components, child.type_name)
		if ok {
			validate_node_property_set(result, child.properties, kind, layout_mode, false)
		}
	}
	validate_node_ids(result, Node_Decl{type_name = screen.name, children = screen.children})
}

validate_parent_layout_properties :: proc(result: ^Semantic_Result, node: Node_Decl) {
	layout_mode := "free"
	if value, ok := get_property_value(node.properties, "layout");
	   ok && value.kind == .Identifier {
		layout_mode = value.data
	}
	if layout_mode == "vertical" || layout_mode == "horizontal" {
		for child in node.children {
			for property in child.properties {
				if property.name == "x" || property.name == "y" {
					append_warning(
						result,
						fmt.aprintf(
							"property '%s' is ignored in %s parent layout",
							property.name,
							layout_mode,
						),
						property.row,
						property.col,
					)
				}
			}
		}
	}
	for child in node.children {
		validate_parent_layout_properties(result, child)
	}
}
