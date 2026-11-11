package recording
import gfx "../../graphics"
import "core:strings"
import "core:unicode/utf8"
import "core:mem"

// A second backend, useful for headless tests, tools, and inspecting UI output.
// Measurement is deliberately monospaced; it is not a raster renderer.
Kind :: enum { Box, Text }
Command :: struct {
    kind: Kind,
    rect: gfx.Rect,
    color, border: gfx.Color,
    radius, border_width, font_size, spacing: f64,
    text: string,
}
Recorder :: struct { commands: [dynamic]Command, allocator: mem.Allocator }
init :: proc(recorder: ^Recorder) -> gfx.Context {
    recorder.allocator = context.allocator
    recorder.commands.allocator = context.allocator
    return gfx.Context{data = recorder, api = &api}
}
reset :: proc(recorder: ^Recorder) {
    for command in recorder.commands { if command.kind == .Text { delete(command.text, recorder.allocator) } }
    clear(&recorder.commands)
}
destroy :: proc(recorder: ^Recorder) { reset(recorder); delete(recorder.commands) }
api := gfx.API{draw_box = draw_box, draw_text = draw_text, measure_text = measure_text}
draw_box :: proc(data: rawptr, rect: gfx.Rect, background, border: gfx.Color, radius, border_width: f64) {
    recorder := cast(^Recorder)data
    append(&recorder.commands, Command{kind = .Box, rect = rect, color = background,
        border = border, radius = radius, border_width = border_width})
}
draw_text :: proc(data: rawptr, text: string, x, y, font_size, spacing: f64, color: gfx.Color) {
    recorder := cast(^Recorder)data
    append(&recorder.commands, Command{kind = .Text, rect = gfx.Rect{x = x, y = y},
        text = strings.clone(text, recorder.allocator), color = color, font_size = font_size, spacing = spacing})
}
measure_text :: proc(data: rawptr, text: string, font_size, spacing: f64) -> f64 {
    count := utf8.rune_count_in_string(text)
    return f64(count) * font_size * 0.6 + f64(max(0, count - 1)) * spacing
}
