package ui
import "core:unicode/utf8"

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


parse_source :: proc(source: string, filename := "<memory>") -> (Design, Parser_Error) {
 if !utf8.valid_string(source) { return Design{}, Parser_Error{"source must be valid UTF-8", 1, 1} }
 for b in source { if b == 0 { return Design{}, Parser_Error{"NUL bytes are not allowed", 1, 1} } }
 p := Parser{lexer = Lexer{src = source, filename = filename, row = 1, col = 1}}
 if len(source) > 0 { p.lexer.ch = source[0] }
 err := advance(&p)
 if err.message != "" { return Design{}, err }
 return parse_design(&p)
}
