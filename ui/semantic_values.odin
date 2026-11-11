package ui

import "core:fmt"
import "core:strconv"
import "core:math"
validate_numeric_value :: proc(property: Property_Decl) -> string {
	value, ok := strconv.parse_f64(property.value.data)
	if !ok {
		return fmt.aprintf("invalid numeric value for property '%s'", property.name)
	}
	if math.is_nan(value) || math.is_inf(value) {
		return fmt.aprintf("numeric value for property '%s' must be finite", property.name)
	}
	switch property.name {
	case "width", "height", "padding", "gap", "radius", "border_width", "line_height", "letter_spacing":
		if value < 0 {
			return fmt.aprintf("property '%s' must be non-negative", property.name)
		}
	case "font_size":
		if value <= 0 {
			return "property 'font_size' must be greater than zero"
		}
	}
	return ""
}

is_named_color :: proc(name: string) -> bool {
	return name == "white" || name == "black" || name == "transparent"
}

value_matches_type :: proc(value: Property_Value, property_type: Property_Type) -> bool {
	switch property_type {
	case .Number:
		return value.kind == .Number
	case .String:
		return value.kind == .String
	case .Enum:
		return value.kind == .Identifier
	case .Color:
		switch value.kind {
		case .Color:
			return true
		case .Identifier:
			return is_named_color(value.data)
		case .Number, .String, .Theme_Ref:
			return false
		}
	}
	return false
}

value_type_name :: proc(value: Property_Value) -> string {
	switch value.kind {
	case .Number:
		return "number"
	case .String:
		return "string"
	case .Identifier:
		return "identifier"
	case .Theme_Ref:
		return "theme reference"
	case .Color:
		return "color"
	}
	return "unknown"
}

required_type_name :: proc(property_type: Property_Type) -> string {
	switch property_type {
	case .Number:
		return "number"
	case .String:
		return "string"
	case .Color:
		return "color"
	case .Enum:
		return "identifier"
	}
	return "unknown"
}

validate_property_value :: proc(
	result: ^Semantic_Result,
	property: Property_Decl,
	expected: Property_Type,
) {
	if property.value.kind == .Theme_Ref {
		return
	}

	if !value_matches_type(property.value, expected) {
		append_error(
			result,
			fmt.aprintf(
				"property '%s' expects %s, got %s",
				property.name,
				required_type_name(expected),
				value_type_name(property.value),
			),
			property.row,
			property.col,
		)
		return
	}

    if property.name == "font" && property.value.data != "" {
        append_error(result, "document font resources are not supported; choose a font in the host backend", property.row, property.col)
    }
	if expected == .Number {
		message := validate_numeric_value(property)
		if message != "" {
			append_error(result, message, property.row, property.col)
		}
	}

	if expected == .Enum && property.name == "layout" {
		if property.value.data != "free" &&
		   property.value.data != "vertical" &&
		   property.value.data != "horizontal" {
			append_error(
				result,
				"invalid layout; expected 'free', 'vertical', or 'horizontal'",
				property.row,
				property.col,
			)
		}
	}

	if expected == .Enum && property.name == "text_align" {
		if property.value.data != "left" && property.value.data != "center" && property.value.data != "right" {
			append_error(result, "invalid text_align; expected 'left', 'center', or 'right'", property.row, property.col)
		}
	}

	if expected == .Enum && property.name == "text_vertical_align" {
		if property.value.data != "top" && property.value.data != "middle" && property.value.data != "bottom" {
			append_error(result, "invalid text_vertical_align; expected 'top', 'middle', or 'bottom'", property.row, property.col)
		}
	}
}

validate_theme_literals :: proc(result: ^Semantic_Result, theme: Theme_Decl) {
	seen: [dynamic]string
	for property in theme.values {
		if property_is_declared(theme.values, property.name) {
			count := 0
			for other in theme.values {
				if other.name == property.name {
					count += 1
				}
			}
			if count > 1 {
				already_reported := false
				for name in seen {
					if name == property.name {
						already_reported = true
						break
					}
				}
				if !already_reported {
					append_error(
						result,
						fmt.aprintf("duplicate property '%s' in theme", property.name),
						property.row,
						property.col,
					)
					append(&seen, property.name)
				}
			}
		}

		if property.value.kind == .Theme_Ref {
			append_error(
				result,
				fmt.aprintf(
					"theme values must be literals; theme token '%s' cannot reference another token",
					property.value.data,
				),
				property.row,
				property.col,
			)
		}
	}
}

validate_duplicate_properties :: proc(
	result: ^Semantic_Result,
	properties: [dynamic]Property_Decl,
	scope_name: string,
) {
	for property, i in properties {
		for j in 0 ..< i {
			if properties[j].name == property.name {
				append_error(
					result,
					fmt.aprintf("duplicate property '%s' in %s", property.name, scope_name),
					property.row,
					property.col,
				)
				break
			}
		}
	}
}

validate_duplicate_states :: proc(
	result: ^Semantic_Result,
	states: [dynamic]State_Decl,
	scope_name: string,
) {
	for state, i in states {
		for j in 0 ..< i {
			if states[j].name == state.name {
				append_error(
					result,
					fmt.aprintf("duplicate state '%s' in %s", state.name, scope_name),
					state.row,
					state.col,
				)
				break
			}
		}
	}
}

validate_state_properties :: proc(
	result: ^Semantic_Result,
	states: [dynamic]State_Decl,
	scope_name: string,
) {
	for state in states {
		validate_duplicate_properties(
			result,
			state.properties,
			fmt.aprintf("%s.%s", scope_name, state.name),
		)
		for property in state.properties {
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
		}
	}
}
