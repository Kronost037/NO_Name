package raylib_backend
import gfx "../../graphics"
import rl "vendor:raylib"
import "core:strings"

// The host calls InitWindow/BeginDrawing/EndDrawing. This adapter works in an
// existing game's frame without opening, clearing, or closing its window.
// A supplied font is borrowed; the host unloads it after all UI drawing ends.
State :: struct { font: rl.Font }
create :: proc(state: ^State = nil) -> gfx.Context { return gfx.Context{data = state, api = &api} }
get_font :: proc(data: rawptr) -> rl.Font {
    state := cast(^State)data
    if state != nil && state.font.texture.id != 0 { return state.font }
    return rl.GetFontDefault()
}
api := gfx.API{draw_box = draw_box, draw_text = draw_text, measure_text = measure_text}

as_color :: proc(c: gfx.Color) -> rl.Color { return rl.Color{c.r, c.g, c.b, c.a} }
draw_box :: proc(data: rawptr, rect: gfx.Rect, background, border: gfx.Color, radius, border_width: f64) {
    if rect.width <= 0 || rect.height <= 0 { return }
    r := rl.Rectangle{f32(rect.x), f32(rect.y), f32(rect.width), f32(rect.height)}
    shortest := min(rect.width, rect.height)
    roundness := f32(clamp(radius, 0, shortest / 2) / (shortest / 2))
    if background.a != 0 {
        if roundness > 0 { rl.DrawRectangleRounded(r, roundness, 8, as_color(background)) }
        else { rl.DrawRectangleRec(r, as_color(background)) }
    }
    if border.a != 0 && border_width > 0 {
        if roundness > 0 { rl.DrawRectangleRoundedLinesEx(r, roundness, 8, f32(border_width), as_color(border)) }
        else { rl.DrawRectangleLinesEx(r, f32(border_width), as_color(border)) }
    }
}
draw_text :: proc(data: rawptr, text: string, x, y, font_size, spacing: f64, color: gfx.Color) {
    cstr := strings.clone_to_cstring(text)
    defer delete(cstr)
    rl.DrawTextEx(get_font(data), cstr, rl.Vector2{f32(x), f32(y)}, f32(font_size), f32(spacing), as_color(color))
}
measure_text :: proc(data: rawptr, text: string, font_size, spacing: f64) -> f64 {
    cstr := strings.clone_to_cstring(text)
    defer delete(cstr)
    return f64(rl.MeasureTextEx(get_font(data), cstr, f32(font_size), f32(spacing)).x)
}
