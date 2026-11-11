package ui

import "core:fmt"
validate_theme_references_in_value :: proc(
	result: ^Semantic_Result,
	property: Property_Decl,
	property_type: Property_Type,
	design: Design,
) {
	if property.value.kind != .Theme_Ref {
		return
	}

	for theme in design.themes {
		_, found := property_index(theme.values, property.value.data)
		if !found {
			append_error(
				result,
				fmt.aprintf(
					"theme '%s' is missing referenced token '$%s'",
					theme.name,
					property.value.data,
				),
				property.row,
				property.col,
			)
			continue
		}
		index, _ := property_index(theme.values, property.value.data)
		token := theme.values[index]
		if token.value.kind == .Theme_Ref {
			append_error(
				result,
				fmt.aprintf("theme token '$%s' must resolve to a literal", property.value.data),
				token.row,
				token.col,
			)
			continue
		}
		if !value_matches_type(token.value, property_type) {
			append_error(
				result,
				fmt.aprintf(
					"theme token '$%s' in theme '%s' has type %s, expected %s",
					property.value.data,
					theme.name,
					value_type_name(token.value),
					required_type_name(property_type),
				),
				token.row,
				token.col,
			)
			continue
		}

        // Validate domains as well as literal kinds (including enum tokens).
        resolved := property
        resolved.value = token.value
        validate_property_value(result, resolved, property_type)

	}
}

walk_theme_references :: proc(
	result: ^Semantic_Result,
	properties: [dynamic]Property_Decl,
	design: Design,
) {
	for property in properties {
		spec, ok := property_spec(property.name)
		if ok {
			validate_theme_references_in_value(result, property, spec.type, design)
		}
	}
}

walk_node_theme_references :: proc(result: ^Semantic_Result, node: Node_Decl, design: Design) {
	walk_theme_references(result, node.properties, design)
	for state in node.states {
		walk_theme_references(result, state.properties, design)
	}
	for child in node.children {
		walk_node_theme_references(result, child, design)
	}
}
