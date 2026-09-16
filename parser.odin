package main

import "core:fmt"
import "core:os"


Property_Value_Kind :: enum {
	Number,
	String,
	Identifier,
	Theme_Ref,
	Color,
}

Property_Value :: struct {
	kind: Property_Value_Kind,
	data: string,
}

Property_Decl :: struct {
	name:  string,
	value: Property_Value,
	row:   int,
	col:   int,
}

State_Decl :: struct {
	name:       string,
	properties: [dynamic]Property_Decl,
	row:        int,
	col:        int,
}

Node_Decl :: struct {
	type_name:  string,
	id:         string,
	properties: [dynamic]Property_Decl,
	states:     [dynamic]State_Decl,
	children:   [dynamic]Node_Decl,
	row:        int,
	col:        int,
}

Theme_Decl :: struct {
	name:   string,
	active: bool,
	values: [dynamic]Property_Decl,
	row:    int,
	col:    int,
}

Component_Decl :: struct {
	name:       string,
	parent:     string,
	properties: [dynamic]Property_Decl,
	states:     [dynamic]State_Decl,
	children:   [dynamic]Node_Decl,
	row:        int,
	col:        int,
}

Screen_Decl :: struct {
	name:       string,
	active:     bool,
	properties: [dynamic]Property_Decl,
	states:     [dynamic]State_Decl,
	children:   [dynamic]Node_Decl,
	row:        int,
	col:        int,
}

Design :: struct {
	themes:     [dynamic]Theme_Decl,
	components: [dynamic]Component_Decl,
	screens:    [dynamic]Screen_Decl,
}


Parser_Error :: struct {
	message: string,
	row:     int,
	col:     int,
}

Parser :: struct {
	lexer:   Lexer,
	current: Token,
}


parser_error :: proc(p: ^Parser, message: string) -> Parser_Error {
	return Parser_Error{message = message, row = p.current.row, col = p.current.col}
}


advance :: proc(p: ^Parser) -> Parser_Error {
	token, lexer_err := next_token(&p.lexer)

	if lexer_err.message != "" {
		return Parser_Error{message = lexer_err.message, row = lexer_err.row, col = lexer_err.col}
	}

	p.current = token
	return Parser_Error{}
}


expect :: proc(p: ^Parser, kind: Token_kind, message: string) -> (Token, Parser_Error) {
	if p.current.kind != kind {
		return Token{}, parser_error(p, message)
	}

	token := p.current

	err := advance(p)

	if err.message != "" {
		return Token{}, err
	}

	return token, Parser_Error{}
}


expect_identifier :: proc(p: ^Parser, message: string) -> (Token, Parser_Error) {
	return expect(p, .Identifier, message)
}


is_identifier :: proc(t: Token, text: string) -> bool {
	return t.kind == .Identifier && t.data == text
}


is_state_name :: proc(name: string) -> bool {
	return name == "hover" || name == "pressed"
}


parse_active :: proc(p: ^Parser) -> (bool, Parser_Error) {
	if !is_identifier(p.current, "active") {
		return false, Parser_Error{}
	}

	err := advance(p)

	if err.message != "" {
		return false, err
	}

	return true, Parser_Error{}
}


parse_value :: proc(p: ^Parser) -> (Property_Value, Parser_Error) {
	switch p.current.kind {
	case .Number:
		value := Property_Value {
			kind = .Number,
			data = p.current.data,
		}

		err := advance(p)

		if err.message != "" {
			return Property_Value{}, err
		}

		return value, Parser_Error{}

	case .String:
		value := Property_Value {
			kind = .String,
			data = p.current.data,
		}

		err := advance(p)

		if err.message != "" {
			return Property_Value{}, err
		}

		return value, Parser_Error{}

	case .Identifier:
		value := Property_Value {
			kind = .Identifier,
			data = p.current.data,
		}

		err := advance(p)

		if err.message != "" {
			return Property_Value{}, err
		}

		return value, Parser_Error{}

	case .Dollar:
		err := advance(p)

		if err.message != "" {
			return Property_Value{}, err
		}

		token, token_err := expect_identifier(p, "expected identifier after '$'")

		if token_err.message != "" {
			return Property_Value{}, token_err
		}

		return Property_Value{kind = .Theme_Ref, data = token.data}, Parser_Error{}

	case .Hash:
		// Special handling for hex colors: read hex digits (0-9, a-f, A-F)
		hex_token, hex_err := lex_hex_color(&p.lexer)

		if hex_err.message != "" {
			return Property_Value{}, Parser_Error{message = hex_err.message, row = hex_err.row, col = hex_err.col}
		}

		if len(hex_token.data) != 6 && len(hex_token.data) != 8 {
			return Property_Value{}, Parser_Error{message = "color must contain exactly 6 or 8 hexadecimal digits", row = hex_token.row, col = hex_token.col}
		}

		for c in hex_token.data {
			switch {
			case c >= '0' && c <= '9':
			case c >= 'a' && c <= 'f':
			case c >= 'A' && c <= 'F':
			case:
				return Property_Value{}, Parser_Error{message = "invalid hexadecimal color", row = hex_token.row, col = hex_token.col}
			}
		}

		// Update current token to reflect what we just read
		p.current = hex_token

		err := advance(p)
		if err.message != "" {
			return Property_Value{}, err
		}

		return Property_Value{kind = .Color, data = hex_token.data}, Parser_Error{}

	case .Eof:
		return Property_Value{}, parser_error(p, "expected property value")

	case .Colon:
		return Property_Value{}, parser_error(p, "expected property value")

	case .LBrace:
		return Property_Value{}, parser_error(p, "expected property value")

	case .RBrace:
		return Property_Value{}, parser_error(p, "expected property value")
	}

	return Property_Value{}, parser_error(p, "expected property value")
}


parse_property :: proc(p: ^Parser) -> (Property_Decl, Parser_Error) {
	name_token, err := expect_identifier(p, "expected property name")

	if err.message != "" {
		return Property_Decl{}, err
	}

	_, err = expect(p, .Colon, "expected ':' after property name")

	if err.message != "" {
		return Property_Decl{}, err
	}

	value, value_err := parse_value(p)

	if value_err.message != "" {
		return Property_Decl{}, value_err
	}

	return Property_Decl {
		name = name_token.data,
		value = value,
		row = name_token.row,
		col = name_token.col,
	}, Parser_Error{}
}


parse_state :: proc(p: ^Parser) -> (State_Decl, Parser_Error) {
	name_token, err := expect_identifier(p, "expected state name")

	if err.message != "" {
		return State_Decl{}, err
	}

	if !is_state_name(name_token.data) {
		return State_Decl{}, Parser_Error{message = "unknown state; expected 'hover' or 'pressed'", row = name_token.row, col = name_token.col}
	}

	state := State_Decl {
		name = name_token.data,
		row  = name_token.row,
		col  = name_token.col,
	}

	_, err = expect(p, .LBrace, "expected '{' after state name")

	if err.message != "" {
		return State_Decl{}, err
	}

	for p.current.kind != .RBrace {
		if p.current.kind == .Eof {
			return State_Decl{}, parser_error(p, "expected '}' before end of file")
		}

		if p.current.kind != .Identifier {
			return State_Decl{}, parser_error(p, "expected property inside state block")
		}

		property, property_err := parse_property(p)

		if property_err.message != "" {
			return State_Decl{}, property_err
		}

		append(&state.properties, property)
	}

	_, err = expect(p, .RBrace, "expected '}' after state block")

	if err.message != "" {
		return State_Decl{}, err
	}

	return state, Parser_Error{}
}


parse_block_contents :: proc(
	p: ^Parser,
	properties: ^[dynamic]Property_Decl,
	states: ^[dynamic]State_Decl,
	children: ^[dynamic]Node_Decl,
) -> Parser_Error {
	for p.current.kind != .RBrace {
		if p.current.kind == .Eof {
			return parser_error(p, "expected '}' before end of file")
		}

		if p.current.kind != .Identifier {
			return parser_error(p, "expected property, state, or child node")
		}

		if is_state_name(p.current.data) {
			state, state_err := parse_state(p)

			if state_err.message != "" {
				return state_err
			}

			append(states, state)
			continue
		}

		name_token := p.current

		err := advance(p)

		if err.message != "" {
			return err
		}

		if p.current.kind == .Colon {
			err = advance(p)

			if err.message != "" {
				return err
			}

			value, value_err := parse_value(p)

			if value_err.message != "" {
				return value_err
			}

			append(
				properties,
				Property_Decl {
					name = name_token.data,
					value = value,
					row = name_token.row,
					col = name_token.col,
				},
			)

			continue
		}

		child := Node_Decl {
			type_name = name_token.data,
			row       = name_token.row,
			col       = name_token.col,
		}

		if p.current.kind == .Hash {
			err = advance(p)

			if err.message != "" {
				return err
			}

			id_token, id_err := expect_identifier(p, "expected identifier after '#'")

			if id_err.message != "" {
				return id_err
			}

			child.id = id_token.data
		}

		_, err = expect(p, .LBrace, "expected '{' after child node declaration")

		if err.message != "" {
			return err
		}

		err = parse_block_contents(p, &child.properties, &child.states, &child.children)

		if err.message != "" {
			return err
		}

		append(children, child)
	}

	_, err := expect(p, .RBrace, "expected '}' after block")

	if err.message != "" {
		return err
	}

	return Parser_Error{}
}


parse_node_contents :: proc(p: ^Parser, node: ^Node_Decl) -> Parser_Error {
	return parse_block_contents(p, &node.properties, &node.states, &node.children)
}


parse_node :: proc(p: ^Parser) -> (Node_Decl, Parser_Error) {
	type_token, err := expect_identifier(p, "expected node type")

	if err.message != "" {
		return Node_Decl{}, err
	}

	node := Node_Decl {
		type_name = type_token.data,
		row       = type_token.row,
		col       = type_token.col,
	}

	if p.current.kind == .Hash {
		err = advance(p)

		if err.message != "" {
			return Node_Decl{}, err
		}

		id_token, id_err := expect_identifier(p, "expected identifier after '#'")

		if id_err.message != "" {
			return Node_Decl{}, id_err
		}

		node.id = id_token.data
	}

	_, err = expect(p, .LBrace, "expected '{' after node declaration")

	if err.message != "" {
		return Node_Decl{}, err
	}

	err = parse_node_contents(p, &node)

	if err.message != "" {
		return Node_Decl{}, err
	}

	return node, Parser_Error{}
}


parse_component :: proc(p: ^Parser) -> (Component_Decl, Parser_Error) {
	keyword, err := expect_identifier(p, "expected 'component'")

	if err.message != "" {
		return Component_Decl{}, err
	}

	if keyword.data != "component" {
		return Component_Decl{}, Parser_Error{message = "expected 'component'", row = keyword.row, col = keyword.col}
	}

	name_token: Token
	name_token, err = expect_identifier(p, "expected component name")

	if err.message != "" {
		return Component_Decl{}, err
	}

	component := Component_Decl {
		name = name_token.data,
		row  = keyword.row,
		col  = keyword.col,
	}

	if p.current.kind == .Colon {
		err = advance(p)

		if err.message != "" {
			return Component_Decl{}, err
		}

		parent_token, parent_err := expect_identifier(p, "expected parent component name")

		if parent_err.message != "" {
			return Component_Decl{}, parent_err
		}

		component.parent = parent_token.data
	}

	_, err = expect(p, .LBrace, "expected '{' after component declaration")

	if err.message != "" {
		return Component_Decl{}, err
	}

	block_err := parse_block_contents(
		p,
		&component.properties,
		&component.states,
		&component.children,
	)

	if block_err.message != "" {
		return Component_Decl{}, block_err
	}

	return component, Parser_Error{}
}


parse_screen :: proc(p: ^Parser) -> (Screen_Decl, Parser_Error) {
	keyword, err := expect_identifier(p, "expected 'screen'")

	if err.message != "" {
		return Screen_Decl{}, err
	}

	if keyword.data != "screen" {
		return Screen_Decl{}, Parser_Error{message = "expected 'screen'", row = keyword.row, col = keyword.col}
	}

	name_token: Token
	name_token, err = expect_identifier(p, "expected screen name")

	if err.message != "" {
		return Screen_Decl{}, err
	}

	screen := Screen_Decl {
		name = name_token.data,
		row  = keyword.row,
		col  = keyword.col,
	}

	screen.active, err = parse_active(p)

	if err.message != "" {
		return Screen_Decl{}, err
	}

	_, err = expect(p, .LBrace, "expected '{' after screen declaration")

	if err.message != "" {
		return Screen_Decl{}, err
	}

	block_err := parse_block_contents(p, &screen.properties, &screen.states, &screen.children)

	if block_err.message != "" {
		return Screen_Decl{}, block_err
	}

	return screen, Parser_Error{}
}


parse_theme :: proc(p: ^Parser) -> (Theme_Decl, Parser_Error) {
	keyword, err := expect_identifier(p, "expected 'theme'")

	if err.message != "" {
		return Theme_Decl{}, err
	}

	if keyword.data != "theme" {
		return Theme_Decl{}, Parser_Error{message = "expected 'theme'", row = keyword.row, col = keyword.col}
	}

	name_token: Token
	name_token, err = expect_identifier(p, "expected theme name")

	if err.message != "" {
		return Theme_Decl{}, err
	}

	theme := Theme_Decl {
		name = name_token.data,
		row  = keyword.row,
		col  = keyword.col,
	}

	theme.active, err = parse_active(p)

	if err.message != "" {
		return Theme_Decl{}, err
	}

	_, err = expect(p, .LBrace, "expected '{' after theme declaration")

	if err.message != "" {
		return Theme_Decl{}, err
	}

	for p.current.kind != .RBrace {
		if p.current.kind == .Eof {
			return Theme_Decl{}, parser_error(p, "expected '}' before end of file")
		}

		if p.current.kind != .Identifier {
			return Theme_Decl{}, parser_error(p, "expected property inside theme")
		}

		property, property_err := parse_property(p)

		if property_err.message != "" {
			return Theme_Decl{}, property_err
		}

		append(&theme.values, property)
	}

	_, err = expect(p, .RBrace, "expected '}' after theme")

	if err.message != "" {
		return Theme_Decl{}, err
	}

	return theme, Parser_Error{}
}


parse_design :: proc(p: ^Parser) -> (Design, Parser_Error) {
	design := Design{}

	for p.current.kind != .Eof {
		if p.current.kind != .Identifier {
			return Design{}, parser_error(p, "expected 'theme', 'component', or 'screen'")
		}

		switch p.current.data {
		case "theme":
			theme, err := parse_theme(p)

			if err.message != "" {
				return Design{}, err
			}

			append(&design.themes, theme)

		case "component":
			component, err := parse_component(p)

			if err.message != "" {
				return Design{}, err
			}

			append(&design.components, component)

		case "screen":
			screen, err := parse_screen(p)

			if err.message != "" {
				return Design{}, err
			}

			append(&design.screens, screen)

		case:
			return Design{}, parser_error(p, "expected 'theme', 'component', or 'screen'")
		}
	}

	return design, Parser_Error{}
}

// PRINTING

print_indent :: proc(depth: int) {
	for i := 0; i < depth; i += 1 {
		fmt.print("    ")
	}
}


print_property_value :: proc(value: Property_Value) {
	switch value.kind {
	case .Number:
		fmt.printf("Number(%s)", value.data)

	case .String:
		fmt.printf("String(\"%s\")", value.data)

	case .Identifier:
		fmt.printf("Identifier(%s)", value.data)

	case .Theme_Ref:
		fmt.printf("Theme_Ref($%s)", value.data)

	case .Color:
		fmt.printf("Color(#%s)", value.data)
	}
}


print_property :: proc(property: Property_Decl, depth: int) {
	print_indent(depth)
	fmt.printf("%s: ", property.name)
	print_property_value(property.value)
	fmt.printf("  [%d:%d]\n", property.row, property.col)
}


print_state :: proc(state: State_Decl, depth: int) {
	print_indent(depth)
	fmt.printf("State %s  [%d:%d]\n", state.name, state.row, state.col)

	for property in state.properties {
		print_property(property, depth + 1)
	}
}


print_node :: proc(node: Node_Decl, depth: int) {
	print_indent(depth)

	if node.id != "" {
		fmt.printf("Node %s #%s  [%d:%d]\n", node.type_name, node.id, node.row, node.col)
	} else {
		fmt.printf("Node %s  [%d:%d]\n", node.type_name, node.row, node.col)
	}

	for property in node.properties {
		print_property(property, depth + 1)
	}

	for state in node.states {
		print_state(state, depth + 1)
	}

	for child in node.children {
		print_node(child, depth + 1)
	}
}


print_theme :: proc(theme: Theme_Decl) {
	if theme.active {
		fmt.printf("Theme %s (active)  [%d:%d]\n", theme.name, theme.row, theme.col)
	} else {
		fmt.printf("Theme %s  [%d:%d]\n", theme.name, theme.row, theme.col)
	}

	for property in theme.values {
		print_property(property, 1)
	}
}


print_component :: proc(component: Component_Decl) {
	if component.parent != "" {
		fmt.printf(
			"Component %s : %s  [%d:%d]\n",
			component.name,
			component.parent,
			component.row,
			component.col,
		)
	} else {
		fmt.printf("Component %s  [%d:%d]\n", component.name, component.row, component.col)
	}

	for property in component.properties {
		print_property(property, 1)
	}

	for state in component.states {
		print_state(state, 1)
	}

	for child in component.children {
		print_node(child, 1)
	}
}


print_screen :: proc(screen: Screen_Decl) {
	if screen.active {
		fmt.printf("Screen %s (active)  [%d:%d]\n", screen.name, screen.row, screen.col)
	} else {
		fmt.printf("Screen %s  [%d:%d]\n", screen.name, screen.row, screen.col)
	}

	for property in screen.properties {
		print_property(property, 1)
	}

	for state in screen.states {
		print_state(state, 1)
	}

	for child in screen.children {
		print_node(child, 1)
	}
}


print_design :: proc(design: Design) {
	fmt.println("========== DESIGN ==========")

	for theme in design.themes {
		print_theme(theme)
		fmt.println()
	}

	for component in design.components {
		print_component(component)
		fmt.println()
	}

	for screen in design.screens {
		print_screen(screen)
		fmt.println()
	}

	fmt.println("=============================")
}
