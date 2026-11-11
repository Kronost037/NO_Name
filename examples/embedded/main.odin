package main
import ui "../../ui"
import backend "../../backends/raylib"
import rl "vendor:raylib"
import "core:fmt"

// Run from the repository root: odin run examples/embedded
// Replace this tiny game with your own. The UI never takes over its window.
VIEW :: `
theme Game active { ink: #edf2fa accent: #bded82 }
screen HUD active {
    width: 260 height: 240 padding: 20 background: #192238ee radius: 12
    layout: vertical gap: 14 text_color: $ink
    Text { height: 30 content: "GAME OVERLAY" font_size: 20 }
    Text #score { height: 30 content: "Score: 0" }
    Button #earn {
        height: 44 background: $accent text_color: black
        content: "Earn points" text_align: center text_vertical_align: middle
        hover { background: #d7ffa6 } pressed { background: #8db95b }
    }
    Text #result { height: 40 content: "Clicks return to your game." font_size: 14 }
}
`
main :: proc() {
    doc, err := ui.load_source(VIEW)
    if err != "" { fmt.eprintln(err); delete(err); return }
    defer ui.destroy(doc)
    rl.InitWindow(800, 600, "Embedding NO NAME in a game")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    graphics := backend.create()
    score := 0
    for !rl.WindowShouldClose() {
        // INPUT into the UI: pointer state and the host's desired viewport.
        event := ui.update(doc, ui.Input{
            pointer_x = f64(rl.GetMouseX()), pointer_y = f64(rl.GetMouseY()),
            pointer_down = rl.IsMouseButtonDown(.LEFT),
            pointer_pressed = rl.IsMouseButtonPressed(.LEFT),
            pointer_released = rl.IsMouseButtonReleased(.LEFT), cancel = !rl.IsWindowFocused(),
        }, ui.Rect{x = 500, y = 40, width = 260, height = 240})
        // OUTPUT to the game: the UI reports intent; the game decides what it means.
        if event.kind == .Click && event.target.instance_id == "earn" { score += 100 }
        value := fmt.aprintf("Score: %d", score)
        ui.set_text(doc, ui.find_child(doc.root, "score"), value)
        delete(value)
        rl.BeginDrawing()
        rl.ClearBackground(rl.Color{14, 20, 36, 255})
        // Your world renders first. Then draw the UI, within the same frame.
        rl.DrawCircle(230, 300, 100, rl.Color{36, 49, 75, 255})
        ui.draw(doc, &graphics)
        rl.EndDrawing()
    }
}
