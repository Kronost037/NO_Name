# Host integration

The UI never creates a window, polls a device, begins/ends a frame, clears the host framebuffer, or runs an event loop. The standalone `main.odin` does those things as an ordinary host.

The public flow is: **load → update → handle events/update data → layout if needed → draw → destroy**.

## API

| Call | Purpose |
| --- | --- |
| `load_file(path)` / `load_source(source)` | Return `(^Document, error_string)`. Source is copied; the caller may discard its buffer. All screens/components validate before success. |
| `destroy(doc)` | Release source, syntax, definitions, runtime trees, and host text. Accepts nil. |
| `preferred_size(doc)` | Active screen's requested dimensions, as a Rect at the origin. |
| `update(doc, Input, viewport)` | Layout, pointer interaction/capture, state reflow; return an Event. Call once per input sample. |
| `layout(doc, viewport)` | Recompute geometry after host changes to screen/theme or geometry-related properties. Also useful for noninteractive rendering. |
| `draw(doc, &graphics)` | Emit boxes/text; return false for a missing/incomplete backend. No frame or window ownership. |
| `find_child(parent, id)` | Find a direct child using a local ID; nil if absent. |
| `find_node_by_id(root, id)` | First depth-first match; use local lookup for repeated components. |
| `set_text(doc, node, text)` | Copy a host string onto Text/Button; return false for nil/nontext nodes, NUL, or invalid UTF-8. |
| `show_screen(doc, name)` | Change active screen; cancel capture and clear old interaction. Return false without changing it for an unknown name. |
| `set_theme(doc, name)` | Switch to a validated theme; return false for an unknown name. |

Load errors are allocated with the caller's allocator; delete the string after reporting it. Successful documents own their internal storage. Host text is separately replaced/freed on updates, so updating a score each frame does not grow the document arena. Passing unchanged text avoids reallocating it.

A Document must stay at the address returned by load. Node/event pointers stay valid until its document is destroyed. All Node arguments must belong to that document. Do not copy the Document value or hold node pointers after destruction. Document access is single-threaded; separate documents can be used on separate threads with suitable allocators/backends.

## Inputs and outputs

`Input` contains pointer coordinates, down/pressed/released edges, and a cancel flag. Map your engine's input into logical UI coordinates. Supply `cancel = true` on focus loss or input cancellation. The host is responsible for camera transforms and DPI mapping. Keep viewport and pointer coordinates in the same space.

`Event.kind` is `None` or `Click`. A click's target is a stable node pointer, so the host can inspect its ID and parent. `Event.handled` indicates the pointer hit UI geometry or an existing UI capture; use it to suppress game-world pointer actions during UI interaction, even before a click is completed. A transparent root still participates in hit testing inside its viewport. Choose a small overlay viewport when the game world should receive pointer input outside it.

```odin
row := ui.find_child(doc.root, "first")
ui.set_text(doc, ui.find_child(row, "player"), player_name)
ui.set_text(doc, ui.find_child(row, "score"), formatted_score)

if event.kind == .Click {
    switch event.target.instance_id {
    case "resume": game.paused = false
    case "leaders": ui.show_screen(doc, "Leaderboard")
    }
}
```

Screens are instantiated once. Changing screens preserves their host text. Change screens/themes and text on the host's thread; after a screen/theme change call `layout` before drawing, or let the next `update` perform it. If there is no input, use `layout` then `draw` directly.

## Renderer contract

Only `graphics/api.odin` is shared between the UI renderer and backend:

```odin
Context :: struct { data: rawptr, api: ^API }
API :: struct {
    draw_box: proc(data: rawptr, rect: Rect, background, border: Color, radius, border_width: f64),
    draw_text: proc(data: rawptr, text: string, x, y, font_size, spacing: f64, color: Color),
    measure_text: proc(data: rawptr, text: string, font_size, spacing: f64) -> f64,
}
```

Implement those three procedures for SDL, another game engine, or a software renderer. Supply your state through `Context.data`. Both that state and the API table must outlive all calls. No raylib types appear in the UI or graphics contract. Raylib is not imported or linked by core tests/the checker.

Callbacks are synchronous; text arguments are borrowed only for the call. A backend retaining text must copy it, as the recording backend does. Drawing and measuring must use the same font, size, and letter spacing. Colors use straight RGBA bytes; radius and border width are logical units. Respect alpha and clamp corner radius to the box's dimensions. The host owns any graphics state save/restore needed by its engine.

`backends/raylib` adapts only these primitives and borrows a font from its optional `State`; it owns no window or font lifetime. `backends/recording` is an independent headless implementation that copies draw commands for inspection. Its text measurement is explicitly approximate and monospaced, for tests/tools. An SDL backend is not implemented in this prototype.

See [the complete host example](../examples/embedded/main.odin) and [standalone host](../main.odin).
