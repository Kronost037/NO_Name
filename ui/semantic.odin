package ui
import "core:fmt"

semantic_analyze :: proc(design: Design) -> (Definition_Set, Semantic_Error) {
	result := Semantic_Result {
		design = design,
	}
	validate_declaration_names(&result, design)
	validate_active_declarations(&result, design)

	for theme in design.themes {
		validate_theme_literals(&result, theme)
	}

	for component in design.components {
		if component.parent != "" {
			if is_reserved_identifier(component.parent) {
				append_error(
					&result,
					fmt.aprintf(
						"reserved identifier '%s' cannot be a parent component",
						component.parent,
					),
					component.row,
					component.col,
				)
			} else if !is_builtin_name(component.parent) {
				_, found := find_component(design.components, component.parent)
				if !found {
					append_error(
						&result,
						fmt.aprintf("unknown parent component '%s'", component.parent),
						component.row,
						component.col,
					)
				}
			}
		}
		validate_component_declaration(&result, design, component)
		validate_parent_layout_properties(
			&result,
			Node_Decl {
				type_name = component.name,
				properties = component.properties,
				children = component.children,
			},
		)
	}

	for screen in design.screens {
		validate_screen(&result, design, screen)
		validate_parent_layout_properties(
			&result,
			Node_Decl {
				type_name = screen.name,
				properties = screen.properties,
				children = screen.children,
			},
		)
	}

	for component in design.components {
		walk_theme_references(&result, component.properties, design)
		for state in component.states {
			walk_theme_references(&result, state.properties, design)
		}
		for child in component.children {
			walk_node_theme_references(&result, child, design)
		}
	}
	for screen in design.screens {
		walk_theme_references(&result, screen.properties, design)
		for state in screen.states {
			walk_theme_references(&result, state.properties, design)
		}
		for child in screen.children {
			walk_node_theme_references(&result, child, design)
		}
	}

	if err := first_error(result); err.message != "" {
		return Definition_Set{}, err
	}

	definitions := Definition_Set{}
	for theme in design.themes {
		append(
			&definitions.themes,
			Theme_Definition {
				name = theme.name,
				active = theme.active,
				values = copy_properties(theme.values),
			},
		)
	}
	for component in design.components {
		kind, _ := component_render_kind(design.components, component.name)
		append(
			&definitions.components,
			Component_Definition {
				name = component.name,
				parent = component.parent,
				row = component.row,
				col = component.col,
				own_properties = copy_properties(component.properties),
				own_states = copy_states(component.states),
				own_children = copy_node_decls(component.children),
				render_kind = kind,
			},
		)
	}
	for screen in design.screens {
		append(
			&definitions.screens,
			Screen_Definition {
				name = screen.name,
				active = screen.active,
				properties = copy_properties(screen.properties),
				states = copy_states(screen.states),
				children = screen.children,
			},
		)
	}

	component_states: [dynamic]u8
	defer delete(component_states)
	for _ in definitions.components {
		append(&component_states, 0)
	}
	for i in 0 ..< len(definitions.components) {
		build_effective_component(&definitions.components, i, &component_states, &result)
	}
	if err := first_error(result); err.message != "" {
		return Definition_Set{}, err
	}

	for theme, i in definitions.themes {
		if theme.active {
			definitions.active_theme = i
		}
	}
	for screen, i in definitions.screens {
		if screen.active {
			definitions.active_screen = i
		}
	}

	return definitions, Semantic_Error{}
}
