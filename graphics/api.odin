package graphics

// No window, widget, or vendor types cross this interface. The host owns its
// window/frame lifecycle; the backend only draws and measures in host coordinates.
Rect :: struct { x, y, width, height: f64 }
Color :: struct { r, g, b, a: u8 }
Context :: struct {
    data: rawptr,
    api: ^API,
}
API :: struct {
    draw_box: proc(data: rawptr, rect: Rect, background, border: Color, radius, border_width: f64),
    draw_text: proc(data: rawptr, text: string, x, y, font_size, spacing: f64, color: Color),
    measure_text: proc(data: rawptr, text: string, font_size, spacing: f64) -> f64,
}
valid :: proc(ctx: ^Context) -> bool {
    return ctx != nil && ctx.api != nil && ctx.api.draw_box != nil &&
        ctx.api.draw_text != nil && ctx.api.measure_text != nil
}
