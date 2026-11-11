package ui
import "core:testing"
import "core:unicode/utf8"
import recording "../backends/recording"

@(test)
render_without_raylib_and_preserve_alignment :: proc(t: ^testing.T) {
    doc, err := load_source(PREFIX + `
component Action : Button { width: 100 height: 40 content: "Go" text_align: left }
component Label : Text { width: 100 height: 30 content: "héllo" }
screen Main active { width: 300 height: 200 background: black Action #a { x: 10 } Label #label { y: 50 } }
`)
    if !testing.expect(t, err == "", err) { delete(err); return }
    defer destroy(doc)
    recorder: recording.Recorder
    graphics := recording.init(&recorder)
    defer recording.destroy(&recorder)
    layout(doc, preferred_size(doc))
    testing.expect(t, draw(doc, &graphics))
    labels := 0
    for command in recorder.commands {
        if command.kind == .Text {
            labels += 1
            testing.expect(t, utf8.valid_string(command.text))
            if command.text == "Go" { testing.expect_value(t, command.rect.x, f64(10)) }
        }
    }
    testing.expect_value(t, labels, 2)
    testing.expect(t, !draw(doc, nil))
    testing.expect(t, !draw(doc, &Graphics_Context{}))
    recording.reset(&recorder)
    // Wrapping never cuts a UTF-8 sequence, even when one glyph exceeds width.
    graphics_draw_wrapped_text(&graphics, "é界é", 0, 0, 1, 100, 10, 15, 0, Color{255,255,255,255}, "left")
    testing.expect_value(t, len(recorder.commands), 3)
    for command in recorder.commands { testing.expect(t, utf8.valid_string(command.text)) }
}
@(test)
host_strings_are_copied_and_rejected_if_invalid :: proc(t: ^testing.T) {
    doc, err := load_source(PREFIX + `screen Main active { width: 100 height: 100 Text #label {} }`)
    if !testing.expect(t, err == "", err) { delete(err); return }
    defer destroy(doc)
    node := find_child(doc.root, "label")
    bytes := [3]u8{'1','0','0'}
    testing.expect(t, set_text(doc, node, string(bytes[:])))
    bytes[0] = '9'
    testing.expect_value(t, get_resolved_property(node, "content", doc.theme), "100")
    testing.expect(t, !set_text(doc, node, "bad\x00text"))
    testing.expect(t, !set_text(doc, node, "\xff"))
    testing.expect_value(t, get_resolved_property(node, "content", doc.theme), "100")
}
