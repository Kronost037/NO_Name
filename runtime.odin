package main

import "core:fmt"

Rect :: struct {
	x:      f64,
	y:      f64,
	width:  f64,
	height: f64,
}

Interaction_State :: struct {
	hover:   bool,
	pressed: bool,
}

Computed_Style :: struct {
	properties: [dynamic]Property_Decl,
	states:     [dynamic]State_Decl,
}

Node :: struct {
	origin_definition:   string,
	instance_id:         string,
	parent:              ^Node,
	children:            [dynamic]^Node,

	// Instance-level overrides
	instance_properties: [dynamic]Property_Decl,
	instance_states:     [dynamic]State_Decl,

	// Computed/resolved
	computed_style:      Computed_Style,
	rect:                Rect,
	interaction:         Interaction_State,
}

instantiate_node :: proc(component_def: Component_Definition, instance_decl: Node_Decl) -> ^Node {
	node := new(Node)

	node.origin_definition = component_def.name
	node.instance_id = instance_decl.id

	// Copy component's effective properties
	node.computed_style.properties = copy_properties(component_def.effective.properties)
	node.computed_style.states = copy_states(component_def.effective.states)

	// Copy component's effective children; instance-declared children are resolved later
	for child in component_def.effective.children {
		child_copy := copy_effective_node_as_runtime(child)
		child_copy.parent = node
		append(&node.children, child_copy)
	}

	// Apply instance-level property/state overrides
	for instance_prop in instance_decl.properties {
		apply_instance_property_override(node, instance_prop)
	}
	for instance_state in instance_decl.states {
		apply_instance_state_override(node, instance_state)
	}

	return node
}

copy_effective_node_as_runtime :: proc(effective: Effective_Node) -> ^Node {
	node := new(Node)

	node.origin_definition = effective.type_name

	// Copy effective properties and states
	node.computed_style.properties = copy_properties(effective.properties)
	node.computed_style.states = copy_states(effective.states)

	// Recursively copy children
	for child in effective.children {
		child_copy := copy_effective_node_as_runtime(child)
		child_copy.parent = node
		append(&node.children, child_copy)
	}

	return node
}

apply_instance_property_override :: proc(node: ^Node, property: Property_Decl) {
	// Find and replace property in computed style, or append if not found
	found := false
	for i := 0; i < len(node.computed_style.properties); i += 1 {
		if node.computed_style.properties[i].name == property.name {
			node.computed_style.properties[i] = property
			found = true
			break
		}
	}

	if !found {
		append(&node.computed_style.properties, property)
	}

	// Also track as instance override for later reference
	append(&node.instance_properties, property)
}

apply_instance_state_override :: proc(node: ^Node, state: State_Decl) {
	// Find matching state in computed style
	found_idx := -1
	for i := 0; i < len(node.computed_style.states); i += 1 {
		if node.computed_style.states[i].name == state.name {
			found_idx = i
			break
		}
	}

	if found_idx >= 0 {
		// Merge instance state properties into existing state
		existing_state := &node.computed_style.states[found_idx]
		for instance_prop in state.properties {
			prop_found := false
			for j := 0; j < len(existing_state.properties); j += 1 {
				if existing_state.properties[j].name == instance_prop.name {
					existing_state.properties[j] = instance_prop
					prop_found = true
					break
				}
			}
			if !prop_found {
				append(&existing_state.properties, instance_prop)
			}
		}
	} else {
		// State doesn't exist in component, add it from instance
		append(&node.computed_style.states, state)
	}

	// Track as instance override
	append(&node.instance_states, state)
}

instantiate_screen :: proc(
	screen_def: Screen_Definition,
	components: [dynamic]Component_Definition,
	definitions: Definition_Set,
) -> (
	^Node,
	Semantic_Error,
) {
	// Create root node
	root := new(Node)
	root.origin_definition = screen_def.name

	// Copy screen properties
	root.computed_style.properties = copy_properties(screen_def.properties)
	root.computed_style.states = copy_states(screen_def.states)

	// Instantiate each child in the screen
	for child_decl in screen_def.children {
		child_node, err := instantiate_child_in_screen(child_decl, components, definitions)
		if err.message != "" {
			return nil, err
		}

		child_node.parent = root
		append(&root.children, child_node)
	}

	return root, Semantic_Error{}
}

instantiate_child_in_screen :: proc(
	child_decl: Node_Decl,
	components: [dynamic]Component_Definition,
	definitions: Definition_Set,
) -> (
	^Node,
	Semantic_Error,
) {
	// Look up component definition
	comp_index, found := find_definition_component(components, child_decl.type_name)
	if !found {
		return nil, make_semantic_error(
			fmt.aprintf("unknown component '%s'", child_decl.type_name),
			child_decl.row,
			child_decl.col,
		)
	}

	component_def := components[comp_index]

	// Create node from component definition + instance overrides
	node := instantiate_node(component_def, child_decl)

	// Recursively instantiate appended children
	// (children declared inside the instance)
	for appended_child_decl in child_decl.children {
		appended_child, err := instantiate_child_in_screen(
			appended_child_decl,
			components,
			definitions,
		)
		if err.message != "" {
			return nil, err
		}

		appended_child.parent = node
		append(&node.children, appended_child)
	}

	return node, Semantic_Error{}
}

find_node_by_id :: proc(node: ^Node, id: string) -> ^Node {
	if node == nil {
		return nil
	}

	if node.instance_id == id {
		return node
	}

	for child in node.children {
		result := find_node_by_id(child, id)
		if result != nil {
			return result
		}
	}

	return nil
}

print_node_tree :: proc(node: ^Node, depth: int) {
	if node == nil {
		return
	}

	print_indent(depth)
	fmt.printf("Node %s", node.origin_definition)
	if node.instance_id != "" {
		fmt.printf(" #%s", node.instance_id)
	}
	fmt.printf(
		" @ (%.0f, %.0f) [%.0f x %.0f]\n",
		node.rect.x,
		node.rect.y,
		node.rect.width,
		node.rect.height,
	)

	for child in node.children {
		print_node_tree(child, depth + 1)
	}
}
