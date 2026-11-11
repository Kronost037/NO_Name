package ui
import gfx "../graphics"

Rect :: gfx.Rect
Color :: gfx.Color
Graphics_Context :: gfx.Context

graphics_draw_box :: proc(ctx: ^Graphics_Context, rect: Rect, background, border: Color, radius, border_width: f64) {
    ctx.api.draw_box(ctx.data, rect, background, border, radius, border_width)
}
graphics_draw_text :: proc(ctx: ^Graphics_Context, text: string, x, y, font_size, spacing: f64, color: Color) {
    ctx.api.draw_text(ctx.data, text, x, y, font_size, spacing, color)
}
graphics_measure_text :: proc(ctx: ^Graphics_Context, text: string, font_size, spacing: f64) -> f64 {
    return ctx.api.measure_text(ctx.data, text, font_size, spacing)
}

graphics_context_valid :: gfx.valid
