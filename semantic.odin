package main

import "core:fmt"
import "core:os"
import "core:strconv"

Semantic_Severity :: enum {
	Error,
	Warning,
}

Semantic_Diagnostic :: struct {
	severity: Semantic_Severity,
	message:  string,
	row:      int,
	col:      int,
}

Semantic_Result :: struct {
	design:      Design,
	diagnostics: [dynamic]Semantic_Diagnostic,
}

Property_Type :: enum {
	Number,
	String,
	Color,
	Enum,
}

Property_Capability :: enum {
	Any_Node,
	Text_Capable,
	Text_Or_Button,
	Image,
	Layout_Parent,
	Free_Position,
}

Property_Spec :: struct {
	name:          string,
	type:          Property_Type,
	inherited:     bool,
	required:      bool,
	default_value: string,
	capability:    Property_Capability,
}

Render_Kind :: enum {
	Generic,
	Text,
	Image,
}

Effective_Node :: struct {
	type_name:     string,
	definition_id: string,
	properties:    [dynamic]Property_Decl,
	states:        [dynamic]State_Decl,
	children:      [dynamic]Effective_Node,
}

Theme_Definition :: struct {
	name:   string,
	active: bool,
	values: [dynamic]Property_Decl,
}

Component_Definition :: struct {
	name:           string,
	parent:         string,
	row:            int,
	col:            int,
	own_properties: [dynamic]Property_Decl,
	own_states:     [dynamic]State_Decl,
	own_children:   [dynamic]Node_Decl,
	render_kind:    Render_Kind,
	effective:      Effective_Node,
	resolved:       bool,
}

Screen_Definition :: struct {
	name:       string,
	active:     bool,
	properties: [dynamic]Property_Decl,
	states:     [dynamic]State_Decl,
	children:   [dynamic]Node_Decl,
}

Definition_Set :: struct {
	themes:        [dynamic]Theme_Definition,
	components:    [dynamic]Component_Definition,
	screens:       [dynamic]Screen_Definition,
	active_theme:  int,
	active_screen: int,
}

Semantic_Error :: struct {
	message: string,
	row:     int,
	col:     int,
}

property_specs :: []Property_Spec {
	{
		name = "width",
		type = .Number,
		inherited = false,
		required = true,
		default_value = "",
		capability = .Any_Node,
	},
	{
		name = "height",
		type = .Number,
		inherited = false,
		required = true,
		default_value = "",
		capability = .Any_Node,
	},
	{
		name = "x",
		type = .Number,
		inherited = false,
		required = false,
		default_value = "",
		capability = .Free_Position,
	},
	{
		name = "y",
		type = .Number,
		inherited = false,
		required = false,
		default_value = "",
		capability = .Free_Position,
	},
	{
		name = "padding",
		type = .Number,
		inherited = false,
		required = false,
		default_value = "0",
		capability = .Any_Node,
	},
	{
		name = "gap",
		type = .Number,
		inherited = false,
		required = false,
		default_value = "0",
		capability = .Layout_Parent,
	},
	{
		name = "layout",
		type = .Enum,
		inherited = false,
		required = false,
		default_value = "free",
		capability = .Any_Node,
	},
	{
		name = "background",
		type = .Color,
		inherited = false,
		required = false,
		default_value = "transparent",
		capability = .Any_Node,
	},
	{
		name = "radius",
		type = .Number,
		inherited = false,
		required = false,
		default_value = "0",
		capability = .Any_Node,
	},
	{
		name = "font",
		type = .String,
		inherited = true,
		required = false,
		default_value = "",
		capability = .Text_Capable,
	},
	{
		name = "font_size",
		type = .Number,
		inherited = true,
		required = false,
		default_value = "18",
		capability = .Text_Capable,
	},
	{
		name = "text_color",
		type = .Color,
		inherited = true,
		required = false,
		default_value = "white",
		capability = .Text_Capable,
	},
	{
		name = "content",
		type = .String,
		inherited = false,
		required = false,
		default_value = "",
		capability = .Text_Or_Button,
	},
	{
		name = "source",
		type = .String,
		inherited = false,
		required = true,
		default_value = "",
		capability = .Image,
	},
}

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

validate_numeric_value :: proc(property: Property_Decl) -> string {
	value, ok := strconv.parse_f64(property.value.data)
	if !ok {
		return fmt.aprintf("invalid numeric value for property '%s'", property.name)
	}
	if value != value {
		return fmt.aprintf("numeric value for property '%s' must be finite", property.name)
	}
	switch property.name {
	case "width", "height", "padding", "gap", "radius":
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
		if kind != .Text {
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
		if kind != .Text {
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
			spec, ok := property_spec(property.name)
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
		if kind != .Text {
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
		if kind != .Text {
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

		if property_type == .Number {
			message := validate_numeric_value(
				Property_Decl {
					name = property.name,
					value = token.value,
					row = token.row,
					col = token.col,
				},
			)
			if message != "" {
				append_error(result, message, token.row, token.col)
			}
		}

		if property_type == .Enum && property.name == "layout" {
			if token.value.data != "free" &&
			   token.value.data != "vertical" &&
			   token.value.data != "horizontal" {
				append_error(
					result,
					fmt.aprintf(
						"theme token '$%s' in theme '%s' has invalid layout value '%s'",
						property.value.data,
						theme.name,
						token.value.data,
					),
					token.row,
					token.col,
				)
			}
		}
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

print_semantic_error :: proc(filename: string, err: Semantic_Error) {
	if err.message == "" {
		return
	}
	fmt.printf("Semantic error: %s:%d:%d: %s\n", filename, err.row, err.col, err.message)
}


main :: proc() {
	data, file_err := os.read_entire_file("design.rss", context.allocator)
	if file_err != os.ERROR_NONE {
		fmt.println("Error reading file.")
		return
	}
	defer delete(data)

	parser := Parser {
		lexer = Lexer{src = string(data), filename = "design.rss", row = 1, col = 1},
	}

	if len(parser.lexer.src) > 0 {
		parser.lexer.ch = parser.lexer.src[0]
	}

	parse_err := advance(&parser)
	if parse_err.message != "" {
		fmt.printf(
			"Error: %s:%d:%d: %s\n",
			parser.lexer.filename,
			parse_err.row,
			parse_err.col,
			parse_err.message,
		)
		return
	}

	design: Design
	design, parse_err = parse_design(&parser)
	if parse_err.message != "" {
		fmt.printf(
			"Error: %s:%d:%d: %s\n",
			parser.lexer.filename,
			parse_err.row,
			parse_err.col,
			parse_err.message,
		)
		return
	}

	definitions, semantic_err := semantic_analyze(design)
	if semantic_err.message != "" {
		print_semantic_error(parser.lexer.filename, semantic_err)
		return
	}

	fmt.printf(
		"Semantic analysis successful: %d themes, %d components, %d screens\n",
		len(definitions.themes),
		len(definitions.components),
		len(definitions.screens),
	)
	fmt.printf("Active theme: %s\n", definitions.themes[definitions.active_theme].name)
	fmt.printf("Active screen: %s\n", definitions.screens[definitions.active_screen].name)

	fmt.println("\n========== EFFECTIVE COMPONENTS ==========")
	for component in definitions.components {
		fmt.printf("Effective component: %s", component.name)
		if component.parent != "" {
			fmt.printf(" : %s", component.parent)
		}
		fmt.printf("\n")
		for property in component.effective.properties {
			fmt.printf("    %s\n", property.name)
		}
	}

	fmt.println("\n========== RUNTIME INSTANTIATION ==========")
	active_screen := definitions.screens[definitions.active_screen]
	root_node, instantiate_err := instantiate_screen(
		active_screen,
		definitions.components,
		definitions,
	)
	if instantiate_err.message != "" {
		fmt.printf(
			"Instantiation error: %s:%d:%d: %s\n",
			parser.lexer.filename,
			instantiate_err.row,
			instantiate_err.col,
			instantiate_err.message,
		)
		return
	}

	fmt.printf("Root screen node: %s\n", root_node.origin_definition)
	fmt.printf("Root node children: %d\n", len(root_node.children))

	fmt.println("\n========== PROPERTY RESOLUTION ==========")
	active_theme := definitions.themes[definitions.active_theme]
	resolve_tree(root_node, active_theme)
	fmt.println("Property resolution complete")

	fmt.println("\n========== LAYOUT COMPUTATION ==========")
	compute_layout(root_node, active_theme)
	fmt.println("Layout computation complete")

	fmt.println("\n========== RUNTIME TREE WITH LAYOUT ==========")
	print_node_tree(root_node, 0)

	fmt.println("\n========== RAYLIB RENDERING ==========")
	fmt.println("Starting application loop...")

	// Initialize graphics
	width_str := get_resolved_property(root_node, "width", active_theme)
	height_str := get_resolved_property(root_node, "height", active_theme)
	window_width := i32(parse_number(width_str))
	window_height := i32(parse_number(height_str))

	gfx := graphics_init(window_width, window_height, "UI Designer")
	defer graphics_shutdown(&gfx)

	// Main game loop
	for !graphics_should_close(&gfx) {
		// Update interaction states based on input
		graphics_update_input(&gfx, root_node)

		// Render frame
		graphics_begin_frame(&gfx)

		// Clear background with screen background color
		bg_color_str := get_resolved_property(root_node, "background", active_theme)
		bg_color := hex_to_color(bg_color_str)
		graphics_clear(&gfx, bg_color)

		// Render the entire node tree
		render_node_tree(&gfx, root_node, active_theme)

		graphics_end_frame(&gfx)
	}

	fmt.println("Application closed.")
}
