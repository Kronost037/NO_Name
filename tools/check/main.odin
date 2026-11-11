package main
import ui "../../ui"
import "core:fmt"
import "core:os"

main :: proc() {
    path := "design.rss"
    if len(os.args) > 1 { path = os.args[1] }
    doc, err := ui.load_file(path)
    if err != "" { fmt.eprintln(err); delete(err); os.exit(1) }
    defer ui.destroy(doc)
    ui.layout(doc, ui.preferred_size(doc))
    fmt.printf("Valid: %s (%d screens, %d components, %d themes)\n", path,
        len(doc.definitions.screens), len(doc.definitions.components), len(doc.definitions.themes))
}
