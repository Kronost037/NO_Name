package ui

// All coordinates use the host's UI coordinate space. The host maps device/DPI
// coordinates and supplies explicit button edges, once per update.
Input :: struct {
    pointer_x, pointer_y: f64,
    pointer_down, pointer_pressed, pointer_released: bool,
    cancel: bool, // window focus loss, paused game, or pointer cancellation
}
Event_Kind :: enum { None, Click }
Event :: struct {
    kind: Event_Kind,
    target: ^Node,
    handled: bool, // suppress game-world pointer actions when true
}
contains :: proc(rect: Rect, x, y: f64) -> bool {
    return rect.width > 0 && rect.height > 0 && x >= rect.x && y >= rect.y &&
        x < rect.x + rect.width && y < rect.y + rect.height
}
// Reverse painter order: an overlapping panel blocks controls underneath.
hit_test :: proc(node: ^Node, x, y: f64) -> ^Node {
    if node == nil { return nil }
    for i := len(node.children) - 1; i >= 0; i -= 1 {
        if hit := hit_test(node.children[i], x, y); hit != nil { return hit }
    }
    if contains(node.rect, x, y) { return node }
    return nil
}
clear_interaction :: proc(node: ^Node) {
    if node == nil { return }
    node.interaction = {}
    for child in node.children { clear_interaction(child) }
}
update :: proc(doc: ^Document, input: Input, viewport: Rect) -> Event {
    layout(doc, viewport)
    clear_interaction(doc.root)
    if input.cancel {
        doc.captured = nil
        layout(doc, viewport)
        return Event{}
    }
    hit := hit_test(doc.root, input.pointer_x, input.pointer_y)
    button: ^Node
    for current := hit; current != nil; current = current.parent {
        current.interaction.hover = true
        if button == nil && current.primitive == .Button { button = current }
    }
    if input.pointer_pressed { doc.captured = button }
    event := Event{handled = hit != nil || doc.captured != nil}
    if input.pointer_released {
        if doc.captured != nil && doc.captured == button { event = Event{kind = .Click, target = button, handled = true} }
        doc.captured = nil
    } else if !input.pointer_down { doc.captured = nil }
    if doc.captured != nil { doc.captured.interaction.pressed = doc.captured == button }
    // State properties may affect layout, so reflow before drawing.
    layout(doc, viewport)
    return event
}
