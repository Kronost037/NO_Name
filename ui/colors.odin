package ui

// Converts the design language's color values to RGBA. Color tokens are stored
// without their leading '#' by the parser, while named colors remain identifiers.
hex_to_color :: proc(value: string) -> Color {
	switch value {
	case "white":
		return Color{255, 255, 255, 255}
	case "black":
		return Color{0, 0, 0, 255}
	case "transparent":
		return Color{0, 0, 0, 0}
	}

	start := 0
	if len(value) > 0 && value[0] == '#' {
		start = 1
	}
	remaining := len(value) - start
	if remaining != 6 && remaining != 8 {
		return Color{0, 0, 0, 255}
	}

	r := hex_byte(value[start : start + 2])
	g := hex_byte(value[start + 2 : start + 4])
	b := hex_byte(value[start + 4 : start + 6])
	a: u8 = 255
	if remaining == 8 {
		a = hex_byte(value[start + 6 : start + 8])
	}

	return Color{r, g, b, a}
}

hex_byte :: proc(hex: string) -> u8 {
	val: u8 = 0
	for c in hex {
		val *= 16
		if c >= '0' && c <= '9' {
			val += u8(c - '0')
		} else if c >= 'a' && c <= 'f' {
			val += u8(c - 'a' + 10)
		} else if c >= 'A' && c <= 'F' {
			val += u8(c - 'A' + 10)
		}
	}
	return val
}
