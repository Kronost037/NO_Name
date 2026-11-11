package ui
import "core:testing"
import "core:strings"

PREFIX :: `theme T active { ink: #ffffff }
`
@(test)
components_expand_at_every_depth :: proc(t: ^testing.T) {
    doc, err := load_source(PREFIX + `
component Label : Text { width: 140 height: 24 content: "base" }
component Group { width: 180 height: 80 Label #label {} }
component Outer { width: 200 height: 100 Group #group {} }
screen Main active { width: 400 height: 300 Outer #outer {} Button #plain { content: "builtin" } }
`)
    if !testing.expect(t, err == "", err) { delete(err); return }
    defer destroy(doc)
    outer := find_child(doc.root, "outer")
    group := find_child(outer, "group")
    label := find_child(group, "label")
    if !testing.expect(t, label != nil) { return }
    testing.expect_value(t, label.primitive, Primitive.Text)
    testing.expect_value(t, get_resolved_property(label, "content", doc.theme), "base")
    testing.expect_value(t, find_child(doc.root, "plain").primitive, Primitive.Button)
}
@(test)
inheritance_and_instance_overrides :: proc(t: ^testing.T) {
    doc, err := load_source(PREFIX + `
component Base : Button {
 width: 100 height: 40 content: "base" background: black
 hover { background: white text_color: black }
 pressed { background: #ff0000 }
}
component Derived : Base { content: "derived" hover { background: #00ff00 } }
component Box {
 width: 200 height: 100
 Text #label { content: "old" }
}
component NewBox : Box { Text #label { content: "new" } }
screen Main active {
 width: 400 height: 300
 Derived #button { content: "instance" hover { background: #0000ff } }
 NewBox #box { Text #label { content: "final" } }
}
`)
    if !testing.expect(t, err == "", err) { delete(err); return }
    defer destroy(doc)
    button := find_child(doc.root, "button")
    testing.expect_value(t, get_resolved_property(button, "content", doc.theme), "instance")
    button.interaction.hover = true
    testing.expect_value(t, get_resolved_property(button, "background", doc.theme), "0000ff")
    testing.expect_value(t, get_resolved_property(button, "text_color", doc.theme), "black")
    button.interaction.pressed = true
    testing.expect_value(t, get_resolved_property(button, "background", doc.theme), "ff0000")
    box := find_child(doc.root, "box")
    testing.expect_value(t, len(box.children), 1)
    testing.expect_value(t, get_resolved_property(find_child(box, "label"), "content", doc.theme), "final")
}
@(test)
invalid_programs_fail_before_rendering :: proc(t: ^testing.T) {
    cases := []struct{source, message: string}{
        {`screen Main active { width: 100 height: 100 Image { source: "icon.png" } }`, "Image rendering is not supported"},
        {`screen Main active { width: 100 height: 100 font: "custom.ttf" }`, "font resources are not supported"},
        {`screen Main active { width: 100 height: 100 typo: 2 }`, "unknown property"},
        {`component A { nope: 1 } screen Main active { width: 100 height: 100 }`, "unknown property"},
        {`screen Main active { width: "bad" height: 100 }`, "expects number"},
        {`component A : B {} component B : A {} screen Main active { width: 100 height: 100 }`, "circular"},
        {`component A { B {} } component B { A {} } screen Main active { width: 100 height: 100 }`, "recursive component composition"},
        {`screen Main active { width: 100 height: 100 Button #b {} Text #b {} }`, "duplicate definition ID"},
        {`screen Main active { width: 100 height: 100 Button { width: 1 width: 2 } }`, "duplicate property"},
        {`screen Main active { width: 100 height: 100 Text { content: $missing } }`, "missing referenced token"},
        {`screen Main active { width: 100 height: 100 Text { font_size: 0 } }`, "greater than zero"},
        {`screen Main active { width: 100 height: 100 background: #abc }`, "6 or 8"},
        {`screen Main active { width: 100 height: 100 Button { hover { bad: 1 } } }`, "unknown property"},
        {`screen Main active { width: 100 height: 100 Button { hover {} hover {} } }`, "duplicate state"},
        {`screen Main active { width: 100 height: 100 } screen Other active { width: 1 height: 1 }`, "more than one active screen"},
        {"screen Main active { width: 100 height: 100 }\x00ignored", "NUL"},
    }
    for c in cases {
        source := strings.concatenate({PREFIX, c.source})
        doc, err := load_source(source)
        delete(source)
        testing.expect(t, doc == nil, c.source)
        testing.expect(t, strings.contains(err, c.message), err)
        if doc != nil { destroy(doc) }
        delete(err)
    }
}
@(test)
escaped_strings_crlf_and_theme_domains :: proc(t: ^testing.T) {
    doc, err := load_source("theme T active { ink: #ffffff }\r\nscreen Main active { width: 10 height: 10 Text #label { content: \"say \\\"hi\\\" \\\\ path\" } }")
    if !testing.expect(t, err == "", err) { delete(err); return }
    defer destroy(doc)
    testing.expect_value(t, get_resolved_property(find_child(doc.root, "label"), "content", doc.theme), "say \"hi\" \\ path")
    invalid, bad := load_source(`theme T active { alignment: sideways } screen Main active { width: 10 height: 10 Text { text_align: $alignment } }`)
    testing.expect(t, invalid == nil)
    testing.expect(t, strings.contains(bad, "invalid text_align"), bad)
    delete(bad)
}
@(test)
inherited_typography_and_local_ids :: proc(t: ^testing.T) {
    doc, err := load_source(PREFIX + `
component Row { width: 100 height: 40 Text #score { height: 20 } }
screen Main active { width: 400 height: 200 font_size: 22 text_color: $ink Row #a {} Row #b {} }
`)
    if !testing.expect(t, err == "", err) { delete(err); return }
    defer destroy(doc)
    a := find_child(find_child(doc.root, "a"), "score")
    b := find_child(find_child(doc.root, "b"), "score")
    testing.expect(t, a != b)
    testing.expect_value(t, get_resolved_property(a, "font_size", doc.theme), "22")
    testing.expect_value(t, get_resolved_property(b, "text_color", doc.theme), "ffffff")
    testing.expect(t, set_text(doc, a, "900"))
    testing.expect_value(t, get_resolved_property(a, "content", doc.theme), "900")
    testing.expect_value(t, get_resolved_property(b, "content", doc.theme), "")
}
