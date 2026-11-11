package ui
import "core:testing"

@(test)
click_capture_drag_cancel_and_painter_order :: proc(t: ^testing.T) {
    doc, err := load_source(PREFIX + `screen Main active {
        width: 300 height: 200
        Button #lower { width: 100 height: 40 }
        Button #upper { x: 20 width: 100 height: 40 }
    }`)
    if !testing.expect(t, err == "", err) { delete(err); return }
    defer destroy(doc)
    view := Rect{width = 300, height = 200}
    down := Input{pointer_x = 30, pointer_y = 10, pointer_down = true, pointer_pressed = true}
    up := Input{pointer_x = 30, pointer_y = 10, pointer_released = true}
    event := update(doc, down, view)
    testing.expect_value(t, event.kind, Event_Kind.None)
    testing.expect(t, find_child(doc.root, "upper").interaction.pressed)
    testing.expect(t, !find_child(doc.root, "lower").interaction.hover)
    event = update(doc, up, view)
    testing.expect_value(t, event.kind, Event_Kind.Click)
    testing.expect_value(t, event.target.instance_id, "upper")
    testing.expect_value(t, update(doc, up, view).kind, Event_Kind.None)
    update(doc, down, view)
    testing.expect_value(t, update(doc, Input{pointer_x = 200, pointer_y = 100, pointer_released = true}, view).kind, Event_Kind.None)
    // Press outside, drag in, release: never activates a button.
    update(doc, Input{pointer_x = 200, pointer_y = 100, pointer_down = true, pointer_pressed = true}, view)
    testing.expect_value(t, update(doc, up, view).kind, Event_Kind.None)
    update(doc, down, view)
    update(doc, Input{cancel = true}, view)
    testing.expect_value(t, update(doc, up, view).kind, Event_Kind.None)
}
@(test)
host_viewport_navigation_and_live_updates :: proc(t: ^testing.T) {
    doc, err := load_source(PREFIX + `
screen Main active {
 width: 400 height: 200 padding: 10 layout: vertical gap: 5
 Text #score { height: 20 content: "0" }
 Button #next { width: 100 height: 30 }
}
screen Other { width: 300 height: 200 Text #title { content: "Other" } }
`)
    if !testing.expect(t, err == "", err) { delete(err); return }
    defer destroy(doc)
    view := Rect{x = 50, y = 60, width = 500, height = 300}
    update(doc, Input{}, view)
    score := find_child(doc.root, "score")
    testing.expect_value(t, score.rect.x, f64(60))
    testing.expect_value(t, score.rect.y, f64(70))
    testing.expect_value(t, score.rect.width, f64(480))
    testing.expect_value(t, find_child(doc.root, "next").rect.y, f64(95))
    testing.expect(t, set_text(doc, score, "100"))
    testing.expect(t, set_text(doc, score, "200"))
    testing.expect_value(t, get_resolved_property(score, "content", doc.theme), "200")
    update(doc, Input{pointer_x = 70, pointer_y = 100, pointer_down = true, pointer_pressed = true}, view)
    testing.expect(t, show_screen(doc, "Other"))
    testing.expect_value(t, update(doc, Input{pointer_x = 70, pointer_y = 100, pointer_released = true}, view).kind, Event_Kind.None)
    testing.expect(t, !show_screen(doc, "Missing"))
    testing.expect_value(t, doc.root.origin_definition, "Other")
    testing.expect(t, show_screen(doc, "Main"))
    testing.expect_value(t, get_resolved_property(score, "content", doc.theme), "200")
}
@(test)
geometry_state_reflows_in_the_same_update :: proc(t: ^testing.T) {
    doc, err := load_source(PREFIX + `screen Main active {
      width: 300 height: 200 layout: vertical
      Button #b { width: 100 height: 40 hover { height: 60 } }
      Text #after { height: 20 }
    }`)
    if !testing.expect(t, err == "", err) { delete(err); return }
    defer destroy(doc)
    update(doc, Input{pointer_x = 10, pointer_y = 10}, preferred_size(doc))
    testing.expect_value(t, find_child(doc.root, "after").rect.y, f64(60))
}

@(test)
zero_dimensions_and_negative_free_offsets :: proc(t: ^testing.T) {
    doc, err := load_source(PREFIX + `screen Main active {
        width: 300 height: 200
        Panel #v { width: 200 height: 100 layout: vertical
            Text #fill { height: 20 }
            Text #zero { width: 0 height: 20 }
        }
        Text #offset { x: -10 y: -5 width: 20 height: 20 }
    }`)
    if !testing.expect(t, err == "", err) { delete(err); return }
    defer destroy(doc)
    layout(doc, preferred_size(doc))
    vertical := find_child(doc.root, "v")
    testing.expect_value(t, find_child(vertical, "fill").rect.width, f64(200))
    testing.expect_value(t, find_child(vertical, "zero").rect.width, f64(0))
    testing.expect_value(t, find_child(doc.root, "offset").rect.x, f64(-10))
    testing.expect_value(t, find_child(doc.root, "offset").rect.y, f64(-5))
}
