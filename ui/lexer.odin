package ui
import "core:fmt"


Lexer_Error :: struct {
	message: string,
	row:     int,
	col:     int,
}

Lexer :: struct {
	src:      string,
	filename: string,
	pos:      int,
	ch:       u8,
	row:      int,
	col:      int,
}

Token_kind :: enum {
	Eof,
	Identifier,
	Number,
	String,
	Colon,
	LBrace,
	RBrace,
	Hash,
	Dollar,
}

Token :: struct {
	kind: Token_kind,
	data: string,
	row:  int,
	col:  int,
}

make_error :: proc(l: ^Lexer, message: string) -> Lexer_Error {
	return Lexer_Error{message = message, row = l.row, col = l.col}
}

make_token :: proc(kind: Token_kind, data: string, row: int, col: int) -> Token {
	return Token{kind = kind, data = data, row = row, col = col}
}

advance_char :: proc(l: ^Lexer) {
	if l.ch == '\n' {
		l.row += 1
		l.col = 1
	} else if l.ch != 0 {
		l.col += 1
	}

	l.pos += 1

	if l.pos >= len(l.src) {
		l.ch = 0
	} else {
		l.ch = l.src[l.pos]
	}
}

is_alpha :: proc(b: u8) -> bool {
	switch b {
	case 'a' ..= 'z', 'A' ..= 'Z', '_':
		return true

	case:
		return false
	}
}

is_num :: proc(b: u8) -> bool {
	return b >= '0' && b <= '9'
}

skip_ignored :: proc(l: ^Lexer) {
	for {
		for l.ch == ' ' || l.ch == '\t' || l.ch == '\n' || l.ch == '\r' {
			advance_char(l)
		}

		if l.ch != '/' {
			return
		}

		next_pos := l.pos + 1

		if next_pos >= len(l.src) || l.src[next_pos] != '/' {
			return
		}

		advance_char(l)
		advance_char(l)

		for l.ch != '\n' && l.ch != 0 {
			advance_char(l)
		}
	}
}

lex_identifier :: proc(l: ^Lexer) -> (Token, Lexer_Error) {
	start := l.pos
	row := l.row
	col := l.col

	for is_alpha(l.ch) || is_num(l.ch) {
		advance_char(l)
	}

	return make_token(.Identifier, l.src[start:l.pos], row, col), {}
}

lex_hex_color :: proc(l: ^Lexer) -> (Token, Lexer_Error) {
	start := l.pos
	row := l.row
	col := l.col

	for is_hex_digit(l.ch) {
		advance_char(l)
	}

	hex_data := l.src[start:l.pos]
	if len(hex_data) == 0 {
		return Token{}, make_error(l, "expected hexadecimal color after '#'")
	}

	return make_token(.Identifier, hex_data, row, col), {}
}

is_hex_digit :: proc(b: u8) -> bool {
	return (b >= '0' && b <= '9') || (b >= 'a' && b <= 'f') || (b >= 'A' && b <= 'F')
}

lex_number :: proc(l: ^Lexer) -> (Token, Lexer_Error) {
	start := l.pos
	row := l.row
	col := l.col

	if l.ch == '+' || l.ch == '-' {
		advance_char(l)
	}

	if is_num(l.ch) {
		for is_num(l.ch) {
			advance_char(l)
		}

		if l.ch == '.' {
			advance_char(l)

			if !is_num(l.ch) {
				return Token{}, make_error(l, "expected digits after decimal point")
			}

			for is_num(l.ch) {
				advance_char(l)
			}
		}
	} else if l.ch == '.' {
		advance_char(l)

		if !is_num(l.ch) {
			return Token{}, make_error(l, "expected digits after '.'")
		}

		for is_num(l.ch) {
			advance_char(l)
		}
	} else {
		return Token{}, make_error(l, "invalid numeric literal")
	}

	if l.ch == 'e' || l.ch == 'E' {
		advance_char(l)

		if l.ch == '+' || l.ch == '-' {
			advance_char(l)
		}

		if !is_num(l.ch) {
			return Token{}, make_error(l, "expected digits in exponent")
		}

		for is_num(l.ch) {
			advance_char(l)
		}
	}

	return make_token(.Number, l.src[start:l.pos], row, col), {}
}

lex_string :: proc(l: ^Lexer) -> (Token, Lexer_Error) {
	start_row := l.row
	start_col := l.col

	advance_char(l)

	start := l.pos
	row := l.row
	col := l.col

	for l.ch != '"' && l.ch != 0 {
		if l.ch == '\\' {
			advance_char(l)

			if l.ch != '\\' && l.ch != '"' {
				return Token{}, make_error(l, "invalid escape sequence; only \\\\ and \\\" are supported")
			}
		}

		advance_char(l)
	}

	if l.ch == 0 {
		return Token{}, Lexer_Error{message = "expected closing quotation for string", row = start_row, col = start_col}
	}

	token := make_token(.String, l.src[start:l.pos], row, col)

	advance_char(l)

	return token, {}
}

lex_single_char :: proc(l: ^Lexer, kind: Token_kind) -> (Token, Lexer_Error) {
	row := l.row
	col := l.col
	start := l.pos

	advance_char(l)

	return make_token(kind, l.src[start:l.pos], row, col), {}
}

next_token :: proc(l: ^Lexer) -> (Token, Lexer_Error) {
	skip_ignored(l)

	if l.ch == 0 {
		return make_token(.Eof, "", l.row, l.col), {}
	}

	switch {
	case is_alpha(l.ch):
		return lex_identifier(l)

	case is_num(l.ch):
		return lex_number(l)

	case l.ch == '+' || l.ch == '-':
		if l.pos + 1 < len(l.src) {
			next := l.src[l.pos + 1]

			if is_num(next) || next == '.' {
				return lex_number(l)
			}
		}

		return Token{}, make_error(l, "unexpected character")

	case l.ch == '.':
		if l.pos + 1 < len(l.src) && is_num(l.src[l.pos + 1]) {
			return lex_number(l)
		}

		return Token{}, make_error(l, "unexpected character '.'")

	case l.ch == '"':
		return lex_string(l)

	case l.ch == ':':
		return lex_single_char(l, .Colon)

	case l.ch == '{':
		return lex_single_char(l, .LBrace)

	case l.ch == '}':
		return lex_single_char(l, .RBrace)

	case l.ch == '#':
		return lex_single_char(l, .Hash)

	case l.ch == '$':
		return lex_single_char(l, .Dollar)

	case:
		return Token{}, make_error(l, fmt.aprintf("unknown character '%c'", l.ch))
	}
}
