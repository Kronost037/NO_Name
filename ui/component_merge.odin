package ui

import "core:fmt"
property_value_as_string :: proc(property: Property_Decl) -> string {
	return property.value.data
}

get_property_value :: proc(
	properties: [dynamic]Property_Decl,
	name: string,
) -> (
	Property_Value,
	bool,
) {
	index, found := property_index(properties, name)
	if !found {
		return Property_Value{}, false
	}
	return properties[index].value, true
}

validate_node_property_set :: proc(
	result: ^Semantic_Result,
	properties: [dynamic]Property_Decl,
	kind: Render_Kind,
	parent_layout: string,
	is_screen_root: bool,
) {
	layout_mode := "free"
	if value, ok := get_property_value(properties, "layout"); ok && value.kind == .Identifier {
		layout_mode = value.data
	}

	for property in properties {
        spec, known := property_spec(property.name)
        if !known {
            append_error(result, fmt.aprintf("unknown property '%s'", property.name), property.row, property.col)
            continue
        }
        validate_property_value(result, property, spec.type)
		allow_position := true
		if parent_layout == "vertical" || parent_layout == "horizontal" {
			allow_position = false
		}
		if is_screen_root && (property.name == "x" || property.name == "y") {
			append_error(
				result,
				fmt.aprintf("screen root does not accept positional property '%s'", property.name),
				property.row,
				property.col,
			)
			continue
		}
		validate_property_capability(result, property, kind, layout_mode, allow_position)
	}
}

find_state :: proc(states: [dynamic]State_Decl, name: string) -> (State_Decl, bool) {
	index, found := state_index(states, name)
	if !found {
		return State_Decl{}, false
	}
	return states[index], true
}

merge_properties :: proc(
	base: [dynamic]Property_Decl,
	overrides: [dynamic]Property_Decl,
) -> [dynamic]Property_Decl {
	result := copy_properties(base)
	for override in overrides {
		index, found := property_index(result, override.name)
		if found {
			result[index] = override
		} else {
			append(&result, override)
		}
	}
	return result
}

merge_states :: proc(
	base: [dynamic]State_Decl,
	overrides: [dynamic]State_Decl,
) -> [dynamic]State_Decl {
	result := copy_states(base)
	for override in overrides {
		index, found := state_index(result, override.name)
		if !found {
			append(
				&result,
				State_Decl {
					name = override.name,
					properties = copy_properties(override.properties),
					row = override.row,
					col = override.col,
				},
			)
			continue
		}
		result[index].properties = merge_properties(result[index].properties, override.properties)
	}
	return result
}

merge_effective_child_list :: proc(
	result: ^Effective_Node,
	derived_children: [dynamic]Node_Decl,
	component_name: string,
	diagnostics: ^Semantic_Result,
) {
	for child in derived_children {
		if child.id != "" {
			found := false
			for inherited_child, i in result.children {
				if inherited_child.definition_id == child.id {
					found = true
					if inherited_child.type_name != child.type_name {
						append_error(
							diagnostics,
							fmt.aprintf(
								"identified child '#%s' in component '%s' changes type from '%s' to '%s'",
								child.id,
								component_name,
								inherited_child.type_name,
								child.type_name,
							),
							child.row,
							child.col,
						)
					} else {
						result.children[i] = copy_node_decl_as_effective(child)
					}
					break
				}
			}
			if found {
				continue
			}
		}
		append(&result.children, copy_node_decl_as_effective(child))
	}
}

build_effective_component :: proc(
	components: ^[dynamic]Component_Definition,
	index: int,
	state: ^[dynamic]u8,
	result: ^Semantic_Result,
) -> Effective_Node {
	if state[index] == 2 {
		return components^[index].effective
	}
	if state[index] == 1 {
		component := components^[index]
		append_error(
			result,
			fmt.aprintf("circular component inheritance involving '%s'", component.name),
			component.row,
			component.col,
		)
		return Effective_Node{}
	}

	state[index] = 1
	component := &components^[index]

	if component.parent == "" {
		component.effective = Effective_Node {
			type_name  = component.name,
			properties = copy_properties(component.own_properties),
			states     = copy_states(component.own_states),
		}
		for child in component.own_children {
			append(&component.effective.children, copy_node_decl_as_effective(child))
		}
		state[index] = 2
		component.resolved = true
		return component.effective
	}

	parent_kind, parent_is_builtin := builtin_render_kind(component.parent)
	_ = parent_kind
	if parent_is_builtin {
		component.effective = Effective_Node {
			type_name = component.name,
		}
	} else {
		parent_index, found := find_definition_component(components^, component.parent)
		if !found {
			state[index] = 2
			component.resolved = true
			component.effective = Effective_Node {
				type_name = component.name,
			}
			return component.effective
		}

		parent_effective := build_effective_component(components, parent_index, state, result)
		component.effective = copy_effective_node(parent_effective)
	}
	component.effective.type_name = component.name
	component.effective.properties = merge_properties(
		component.effective.properties,
		component.own_properties,
	)
	component.effective.states = merge_states(component.effective.states, component.own_states)
	merge_effective_child_list(
		&component.effective,
		component.own_children,
		component.name,
		result,
	)
	state[index] = 2
	component.resolved = true
	return component.effective
}
