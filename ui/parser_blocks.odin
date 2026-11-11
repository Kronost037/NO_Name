package ui


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
