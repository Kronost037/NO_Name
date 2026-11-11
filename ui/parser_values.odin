package ui


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
			data = decode_string(p.current.data),
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

// Escape syntax stays compatible: only backslash and quotation marks.
decode_string :: proc(raw: string) -> string {
 bytes: [dynamic]u8
 for i := 0; i < len(raw); i += 1 {
  if raw[i] == '\\' { i += 1 }
  append(&bytes, raw[i])
 }
 return string(bytes[:])
}
