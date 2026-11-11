package ui

reserved_identifiers :: []string {
	"theme",
	"component",
	"screen",
	"active",
	"hover",
	"pressed",
	"edit",
	"delete",
}

builtin_names :: []string{"Text", "Image", "Panel", "Button"}

builtin_render_kind :: proc(name: string) -> (Render_Kind, bool) {
	switch name {
	case "Text":
		return .Text, true
	case "Image":
		return .Image, true
	case "Panel":
		return .Generic, true
	case "Button":
		return .Text, true
	}
	return .Generic, false
}

make_semantic_error :: proc(message: string, row, col: int) -> Semantic_Error {
	return Semantic_Error{message = message, row = row, col = col}
}

append_error :: proc(result: ^Semantic_Result, message: string, row, col: int) {
	append(
		&result.diagnostics,
		Semantic_Diagnostic{severity = .Error, message = message, row = row, col = col},
	)
}

append_warning :: proc(result: ^Semantic_Result, message: string, row, col: int) {
	append(
		&result.diagnostics,
		Semantic_Diagnostic{severity = .Warning, message = message, row = row, col = col},
	)
}

first_error :: proc(result: Semantic_Result) -> Semantic_Error {
	for diagnostic in result.diagnostics {
		if diagnostic.severity == .Error {
			return make_semantic_error(diagnostic.message, diagnostic.row, diagnostic.col)
		}
	}
	return Semantic_Error{}
}

is_reserved_identifier :: proc(name: string) -> bool {
	for reserved in reserved_identifiers {
		if name == reserved {
			return true
		}
	}
	return false
}

is_builtin_name :: proc(name: string) -> bool {
	_, ok := builtin_render_kind(name)
	return ok
}

property_spec :: proc(name: string) -> (Property_Spec, bool) {
	for spec in property_specs {
		if spec.name == name {
			return spec, true
		}
	}
	return Property_Spec{}, false
}

find_theme :: proc(themes: [dynamic]Theme_Decl, name: string) -> (int, bool) {
	for theme, i in themes {
		if theme.name == name {
			return i, true
		}
	}
	return 0, false
}

find_component :: proc(components: [dynamic]Component_Decl, name: string) -> (int, bool) {
	for component, i in components {
		if component.name == name {
			return i, true
		}
	}
	return 0, false
}

find_definition_component :: proc(
	components: [dynamic]Component_Definition,
	name: string,
) -> (
	int,
	bool,
) {
	for component, i in components {
		if component.name == name {
			return i, true
		}
	}
	return 0, false
}

property_index :: proc(properties: [dynamic]Property_Decl, name: string) -> (int, bool) {
	for property, i in properties {
		if property.name == name {
			return i, true
		}
	}
	return 0, false
}

property_is_declared :: proc(properties: [dynamic]Property_Decl, name: string) -> bool {
	_, found := property_index(properties, name)
	return found
}

state_index :: proc(states: [dynamic]State_Decl, name: string) -> (int, bool) {
	for state, i in states {
		if state.name == name {
			return i, true
		}
	}
	return 0, false
}

child_index_by_id :: proc(children: [dynamic]Node_Decl, id: string) -> (int, bool) {
	if id == "" {
		return 0, false
	}
	for child, i in children {
		if child.id == id {
			return i, true
		}
	}
	return 0, false
}

copy_properties :: proc(properties: [dynamic]Property_Decl) -> [dynamic]Property_Decl {
	result: [dynamic]Property_Decl
	for property in properties {
		append(&result, property)
	}
	return result
}

copy_states :: proc(states: [dynamic]State_Decl) -> [dynamic]State_Decl {
	result: [dynamic]State_Decl
	for state in states {
		copy_state := State_Decl {
			name = state.name,
			row  = state.row,
			col  = state.col,
		}
		for property in state.properties {
			append(&copy_state.properties, property)
		}
		append(&result, copy_state)
	}
	return result
}

copy_node_decls :: proc(nodes: [dynamic]Node_Decl) -> [dynamic]Node_Decl {
	result: [dynamic]Node_Decl
	for node in nodes {
		copy := Node_Decl {
			type_name  = node.type_name,
			id         = node.id,
			row        = node.row,
			col        = node.col,
			properties = copy_properties(node.properties),
			states     = copy_states(node.states),
		}
		copy.children = copy_node_decls(node.children)
		append(&result, copy)
	}
	return result
}

copy_node_decl_as_effective :: proc(node: Node_Decl) -> Effective_Node {
	result := Effective_Node {
		type_name     = node.type_name,
		definition_id = node.id,
	}
	result.properties = copy_properties(node.properties)
	result.states = copy_states(node.states)
	for child in node.children {
		append(&result.children, copy_node_decl_as_effective(child))
	}
	return result
}

copy_effective_node :: proc(node: Effective_Node) -> Effective_Node {
	result := Effective_Node {
		type_name     = node.type_name,
		definition_id = node.definition_id,
		properties    = copy_properties(node.properties),
		states        = copy_states(node.states),
	}
	for child in node.children {
		append(&result.children, copy_effective_node(child))
	}
	return result
}
