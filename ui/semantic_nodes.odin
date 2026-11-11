package ui

import "core:fmt"
validate_textual_property_capability :: proc(
	result: ^Semantic_Result,
	property: Property_Decl,
	kind: Render_Kind,
) {
	spec, ok := property_spec(property.name)
	if !ok {
		return
	}
	switch spec.capability {
	case .Any_Node, .Layout_Parent, .Free_Position:
		return
	case .Text_Capable:
		if kind != .Text && !spec.inherited {
			append_error(
				result,
				fmt.aprintf(
					"property '%s' is only valid on text-capable components",
					property.name,
				),
				property.row,
				property.col,
			)
		}
	case .Text_Or_Button:
		if kind != .Text && !spec.inherited {
			append_error(
				result,
				"property 'content' is only valid on Text or Button components",
				property.row,
				property.col,
			)
		}
	case .Image:
		if kind != .Image {
			append_error(
				result,
				"property 'source' is only valid on Image components",
				property.row,
				property.col,
			)
		}
	}
}

validate_state_capabilities :: proc(
	result: ^Semantic_Result,
	states: [dynamic]State_Decl,
	kind: Render_Kind,
	scope_name: string,
) {
	_ = scope_name
	for state in states {
		for property in state.properties {
			validate_textual_property_capability(result, property, kind)
		}
	}
}

validate_node_ids :: proc(result: ^Semantic_Result, node: Node_Decl) {
	for child, i in node.children {
		if child.id != "" {
			if is_reserved_identifier(child.id) {
				append_error(
					result,
					fmt.aprintf(
						"reserved identifier '%s' cannot be used as a definition ID",
						child.id,
					),
					child.row,
					child.col,
				)
			}
			for j in 0 ..< i {
				if node.children[j].id != "" && node.children[j].id == child.id {
					append_error(
						result,
						fmt.aprintf("duplicate definition ID #%s among siblings", child.id),
						child.row,
						child.col,
					)
					break
				}
			}
		}
		validate_node_ids(result, child)
	}
}

validate_component_node_reference :: proc(
	result: ^Semantic_Result,
	components: [dynamic]Component_Decl,
	node: Node_Decl,
) {
	kind, builtin := builtin_render_kind(node.type_name)
	_, user_component := find_component(components, node.type_name)
 if user_component { kind, _ = component_render_kind(components, node.type_name) }
	if !builtin && !user_component {
		append_error(
			result,
			fmt.aprintf("unknown component '%s'", node.type_name),
			node.row,
			node.col,
		)
	}

	validate_duplicate_properties(
		result,
		node.properties,
		fmt.aprintf("node '%s'", node.type_name),
	)
	validate_duplicate_states(result, node.states, fmt.aprintf("node '%s'", node.type_name))
	validate_state_properties(result, node.states, fmt.aprintf("node '%s'", node.type_name))

	layout_mode := "free"
	if value, ok := get_property_value(node.properties, "layout");
	   ok && value.kind == .Identifier {
		layout_mode = value.data
	}

	for property in node.properties {
		spec, ok := property_spec(property.name)
		if !ok {
			append_error(
				result,
				fmt.aprintf("unknown property '%s'", property.name),
				property.row,
				property.col,
			)
			continue
		}
		validate_property_value(result, property, spec.type)
		if builtin || user_component {
			validate_property_capability(result, property, kind, layout_mode, true)
		}
	}

	for state in node.states {
		for property in state.properties {
			_, ok := property_spec(property.name)
			if !ok {
				continue
			}
			if builtin || user_component {
				validate_property_capability(result, property, kind, layout_mode, true)
			}
		}
	}

	validate_node_ids(result, node)
	for child in node.children {
		validate_component_node_reference(result, components, child)
	}
}

component_render_kind :: proc(
	components: [dynamic]Component_Decl,
	name: string,
) -> (
	Render_Kind,
	bool,
) {
	kind, builtin := builtin_render_kind(name)
	if builtin {
		return kind, true
	}

	current := name
	for steps := 0; steps <= len(components); steps += 1 {
		index, found := find_component(components, current)
		if !found {
			return .Generic, false
		}

		component := components[index]
		if component.parent == "" {
			return .Generic, true
		}

		kind, builtin = builtin_render_kind(component.parent)
		if builtin {
			return kind, true
		}

		current = component.parent
	}

	return .Generic, false
}

validate_property_capability :: proc(
	result: ^Semantic_Result,
	property: Property_Decl,
	kind: Render_Kind,
	layout_mode: string,
	allow_position: bool,
) {
	spec, ok := property_spec(property.name)
	if !ok {
		return
	}

	switch spec.capability {
	case .Any_Node:
		return
	case .Text_Capable:
		if kind != .Text && !spec.inherited {
			append_error(
				result,
				fmt.aprintf(
					"property '%s' is only valid on text-capable components",
					property.name,
				),
				property.row,
				property.col,
			)
		}
	case .Text_Or_Button:
		if kind != .Text && !spec.inherited {
			append_error(
				result,
				"property 'content' is only valid on Text or Button components",
				property.row,
				property.col,
			)
		}
	case .Image:
		if kind != .Image {
			append_error(
				result,
				"property 'source' is only valid on Image components",
				property.row,
				property.col,
			)
		}
	case .Layout_Parent:
		if layout_mode == "free" {
			append_warning(
				result,
				"property 'gap' is ignored when layout is 'free'",
				property.row,
				property.col,
			)
		}
	case .Free_Position:
		if !allow_position {
			append_warning(
				result,
				fmt.aprintf(
					"property '%s' is ignored in vertical/horizontal parent layout",
					property.name,
				),
				property.row,
				property.col,
			)
		}
	}
}
