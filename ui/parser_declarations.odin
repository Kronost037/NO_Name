package ui


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
