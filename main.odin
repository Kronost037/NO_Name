package main
import ui "ui"
import backend "backends/raylib"
import rl "vendor:raylib"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

// A complete standalone host. The UI package itself knows nothing about raylib.
main :: proc() {
    path := "design.rss"
    frame_limit := 0
    screenshot := ""
    for i := 1; i < len(os.args); i += 1 {
        switch os.args[i] {
        case "--frames":
            i += 1
            if i < len(os.args) { frame_limit, _ = strconv.parse_int(os.args[i]) }
        case "--screenshot":
            i += 1
            if i < len(os.args) { screenshot = os.args[i] }
        case: path = os.args[i]
        }
    }
    doc, err := ui.load_file(path)
    if err != "" { fmt.eprintln(err); delete(err); os.exit(1) }
    defer ui.destroy(doc)
    size := ui.preferred_size(doc)
    rl.InitWindow(i32(size.width), i32(size.height), "NO NAME / Desktop UI prototype")
    if !rl.IsWindowReady() { os.exit(1) }
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    font := rl.LoadFontEx("assets/DejaVuSans.ttf", 48, nil, 0)
    defer rl.UnloadFont(font)
    rl.SetTextureFilter(font.texture, .BILINEAR)
    renderer := backend.State{font = font}
    graphics := backend.create(&renderer)
    points := 5000
    light := false
    frames := 0
    quit := false
    for !quit && !rl.WindowShouldClose() {
        viewport := ui.Rect{width = f64(rl.GetScreenWidth()), height = f64(rl.GetScreenHeight())}
        event := ui.update(doc, ui.Input{
            pointer_x = f64(rl.GetMouseX()), pointer_y = f64(rl.GetMouseY()),
            pointer_down = rl.IsMouseButtonDown(.LEFT),
            pointer_pressed = rl.IsMouseButtonPressed(.LEFT),
            pointer_released = rl.IsMouseButtonReleased(.LEFT), cancel = !rl.IsWindowFocused(),
        }, viewport)
        if event.kind == .Click {
            switch event.target.instance_id {
            case "play": ui.show_screen(doc, "Session")
            case "leaders": ui.show_screen(doc, "Leaderboard")
            case "back": ui.show_screen(doc, "Menu")
            case "quit": quit = true
            case "score", "refresh": points += 100
            case "theme_toggle":
                light = !light
                ui.set_theme(doc, light ? "Daylight" : "Midnight")
            }
        }
        // Feed host-owned values into whichever screen is active.
        label := fmt.aprintf("Score: %d", points)
        ui.set_text(doc, ui.find_node_by_id(doc.root, "points"), label)
        delete(label)
        if doc.root.origin_definition == "Leaderboard" {
            set_player(doc, "first", "YOU", points)
            set_player(doc, "second", "NOVA", 4200)
            set_player(doc, "third", "ORION", 3100)
        }
        ui.layout(doc, viewport)
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        ui.draw(doc, &graphics)
        rl.EndDrawing()
        frames += 1
        if frame_limit > 0 && frames >= frame_limit {
            if screenshot != "" {
                cpath := strings.clone_to_cstring(screenshot)
                rl.TakeScreenshot(cpath)
                delete(cpath)
            }
            quit = true
        }
    }
}
set_player :: proc(doc: ^ui.Document, row_id, name: string, score: int) {
    row := ui.find_child(doc.root, row_id)
    ui.set_text(doc, ui.find_child(row, "player"), name)
    value := fmt.aprintf("%d", score)
    defer delete(value)
    ui.set_text(doc, ui.find_child(row, "score"), value)
}
