package main

import "core:fmt"
import "core:strconv"

// Resolved property value for a node at runtime
Resolved_Property :: struct {
	name:  string,
	value: string, // Always string representation for now
}

get_property_default :: proc(prop_name: string) -> string {
	spec, found := property_spec(prop_name)
	if !found {
		return ""
	}
	return spec.default_value
}

is_property_inheritable :: proc(prop_name: string) -> bool {
	spec, found := property_spec(prop_name)
	if !found {
		return false
	}
	return spec.inherited
}

resolve_theme_reference :: proc(
	token_name: string,
	active_theme: Theme_Definition,
) -> (
	string,
	bool,
) {
	// Look up token in active theme
	for prop in active_theme.values {
		if prop.name == token_name {
			// Return the resolved value (theme props are literals, not refs)
			return prop.value.data, true
		}
	}
	return "", false
}

// Get the highest-precedence explicit property declaration for a node
// Precedence: instance override > component definition > default (none found)
get_base_property_decl :: proc(node: ^Node, prop_name: string) -> (Property_Decl, bool) {
	// Check instance-level overrides first
	for prop in node.instance_properties {
		if prop.name == prop_name {
			return prop, true
		}
	}

	// Check computed style (merged from component definition)
	for prop in node.computed_style.properties {
		if prop.name == prop_name {
			return prop, true
		}
	}

	return Property_Decl{}, false
}

// Get the highest-precedence state declaration for a given property
// Precedence: pressed > hover (base is implicit, no declaration)
get_active_state_decl :: proc(node: ^Node, prop_name: string) -> (Property_Decl, bool) {
	// Check pressed first (highest precedence)
	for state in node.computed_style.states {
		if state.name == "pressed" && node.interaction.pressed {
			for prop in state.properties {
				if prop.name == prop_name {
					return prop, true
				}
			}
		}
	}

	// Check instance-level pressed state
	for state in node.instance_states {
		if state.name == "pressed" && node.interaction.pressed {
			for prop in state.properties {
				if prop.name == prop_name {
					return prop, true
				}
			}
		}
	}

	// Check hover (lower precedence than pressed)
	for state in node.computed_style.states {
		if state.name == "hover" && node.interaction.hover {
			for prop in state.properties {
				if prop.name == prop_name {
					return prop, true
				}
			}
		}
	}

	// Check instance-level hover state
	for state in node.instance_states {
		if state.name == "hover" && node.interaction.hover {
			for prop in state.properties {
				if prop.name == prop_name {
					return prop, true
				}
			}
		}
	}

	return Property_Decl{}, false
}

// Canonical property resolution per spec section 16
resolve_property :: proc(
	node: ^Node,
	prop_name: string,
	parent_node: ^Node,
	active_theme: Theme_Definition,
) -> string {
	// Step 1-3: Determine winning base declaration and evaluate
	base_decl, base_found := get_base_property_decl(node, prop_name)

	base_value := ""
	if base_found {
		// Evaluate the base value
		if base_decl.value.kind == .Theme_Ref {
			// Resolve theme reference
			resolved, theme_found := resolve_theme_reference(base_decl.value.data, active_theme)
			if theme_found {
				base_value = resolved
			}
		} else {
			// Use literal value
			base_value = base_decl.value.data
		}
	} else {
		// Step 4: No explicit base declaration
		if is_property_inheritable(prop_name) && parent_node != nil {
			// Use parent's final computed value
			base_value = resolve_property(parent_node, prop_name, parent_node.parent, active_theme)
		} else {
			// Step 5: Use property default
			base_value = get_property_default(prop_name)
		}
	}

	// Step 6-7: Determine highest-precedence active state declaration
	state_decl, state_found := get_active_state_decl(node, prop_name)

	state_value := ""
	if state_found {
		// Evaluate state value using same rules
		if state_decl.value.kind == .Theme_Ref {
			resolved, theme_found := resolve_theme_reference(state_decl.value.data, active_theme)
			if theme_found {
				state_value = resolved
			}
		} else {
			state_value = state_decl.value.data
		}
	}

	// Step 8-9: Final computed value
	final_value := base_value
	if state_found && state_value != "" {
		final_value = state_value
	}

	// Step 10: Apply property-domain normalization
	final_value = normalize_property_value(prop_name, final_value)

	return final_value
}

normalize_property_value :: proc(prop_name: string, value: string) -> string {
	switch prop_name {
	case "radius":
		// Radius clamping happens during layout when we know width/height
		// For now, just validate it's non-negative
		num, ok := strconv.parse_f64(value)
		if !ok {
			return "0"
		}
		if num < 0 {
			return "0"
		}
		return value

	case "font_size":
		num, ok := strconv.parse_f64(value)
		if !ok {
			return "18"
		}
		if num <= 0 {
			return "18"
		}
		return value

	case "width", "height", "padding", "gap":
		num, ok := strconv.parse_f64(value)
		if !ok {
			return "0"
		}
		if num < 0 {
			return "0"
		}
		return value
	}

	return value
}

// Resolve all properties for a node (populate a style map)
resolve_node_style :: proc(node: ^Node, active_theme: Theme_Definition) {
	// Properties are resolved on-demand during layout
	// This is a hook for future caching/optimization
	_ = node
	_ = active_theme
}

// Get a resolved property value for a node
get_resolved_property :: proc(
	node: ^Node,
	prop_name: string,
	active_theme: Theme_Definition,
) -> string {
	return resolve_property(node, prop_name, node.parent, active_theme)
}

// Recursively resolve all nodes in a tree
resolve_tree :: proc(node: ^Node, active_theme: Theme_Definition) {
	if node == nil {
		return
	}

	resolve_node_style(node, active_theme)

	for child in node.children {
		resolve_tree(child, active_theme)
	}
}
