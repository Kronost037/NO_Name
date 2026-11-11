package ui
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import "core:unicode/utf8"

// Stable address: allocate with load_source/load_file and release with destroy.
Document :: struct {
    arena: mem.Dynamic_Arena,
    owner: mem.Allocator,
    definitions: Definition_Set,
    screens: [dynamic]^Node,
    root: ^Node,
    theme: Theme_Definition,
    captured: ^Node,
}
// On failure the caller owns the returned error string (delete it when done).
load_source :: proc(source: string, filename := "<memory>") -> (^Document, string) {
    doc := new(Document)
    doc.owner = context.allocator
    mem.dynamic_arena_init(&doc.arena)
    error := compile_document(doc, source, filename)
    if error.message != "" {
        // Copy diagnostic out of the arena before destroying it.
        message := fmt.aprintf("%s:%d:%d: %s", filename, error.row, error.col, error.message)
        destroy(doc)
        return nil, message
    }
    return doc, ""
}
load_file :: proc(path: string) -> (^Document, string) {
    data, err := os.read_entire_file(path, context.allocator)
    if err != os.ERROR_NONE { return nil, fmt.aprintf("cannot read '%s': %v", path, err) }
    defer delete(data)
    return load_source(string(data), path)
}
compile_document :: proc(doc: ^Document, source, filename: string) -> Semantic_Error {
    context.allocator = mem.dynamic_arena_allocator(&doc.arena)
    owned_source := strings.clone(source)
    design, parse_err := parse_source(owned_source, filename)
    if parse_err.message != "" { return Semantic_Error{parse_err.message, parse_err.row, parse_err.col} }
    definitions, err := semantic_analyze(design)
    if err.message != "" { return err }
    doc.definitions = definitions
    // Also expand unused components, detecting recursive composition before a frame runs.
    for component in definitions.components {
        _, err = instantiate_decl(Node_Decl{type_name = component.name, row = component.row, col = component.col}, definitions.components)
        if err.message != "" { return err }
    }
    for screen in definitions.screens {
        root: ^Node
        root, err = instantiate_screen(screen, definitions.components, definitions)
        if err.message != "" { return err }
        append(&doc.screens, root)
    }
    doc.root = doc.screens[definitions.active_screen]
    doc.theme = definitions.themes[definitions.active_theme]
    return Semantic_Error{}
}
destroy :: proc(doc: ^Document) {
    if doc == nil { return }
    for root in doc.screens { release_host_text(root, doc.owner) }
    mem.dynamic_arena_destroy(&doc.arena)
    free(doc, doc.owner)
}
release_host_text :: proc(node: ^Node, allocator: mem.Allocator) {
    if node == nil { return }
    if node.has_host_content { delete(node.host_content, allocator) }
    for child in node.children { release_host_text(child, allocator) }
}
// Copies host data; safe to pass a temporary formatted score or player name.
set_text :: proc(doc: ^Document, node: ^Node, text: string) -> bool {
    if !utf8.valid_string(text) { return false }
    for ch in text { if ch == 0 { return false } }
    if node == nil || (node.primitive != .Text && node.primitive != .Button) { return false }
    if node.has_host_content && node.host_content == text { return true }
    if node.has_host_content { delete(node.host_content, doc.owner) }
    node.host_content = strings.clone(text, doc.owner)
    node.has_host_content = true
    return true
}
show_screen :: proc(doc: ^Document, name: string) -> bool {
    for screen, i in doc.definitions.screens {
        if screen.name == name {
            clear_interaction(doc.root)
            doc.root = doc.screens[i]
            doc.captured = nil
            return true
        }
    }
    return false
}
set_theme :: proc(doc: ^Document, name: string) -> bool {
    for theme in doc.definitions.themes {
        if theme.name == name { doc.theme = theme; return true }
    }
    return false
}
preferred_size :: proc(doc: ^Document) -> Rect {
    return Rect{width = parse_number(get_resolved_property(doc.root, "width", doc.theme)),
        height = parse_number(get_resolved_property(doc.root, "height", doc.theme))}
}
// Call after changing data/theme when no input update is needed.
layout :: proc(doc: ^Document, viewport: Rect) {
    doc.root.rect = viewport
    layout_tree(doc.root, doc.theme)
}
draw :: proc(doc: ^Document, graphics: ^Graphics_Context) -> bool {
    if !graphics_context_valid(graphics) { return false }
    render_node_tree(graphics, doc.root, doc.theme)
    return true
}
