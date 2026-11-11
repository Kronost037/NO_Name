# Language guide

A document describes views. It does not execute game logic. The host feeds values into nodes and receives interaction events.

## Structure and grammar

Names are case-sensitive. Keywords are lowercase; built-ins are `Panel`, `Text`, `Button`, and reserved `Image`. Components can be declared before or after the place they are used.

```ebnf
document  = { theme | component | screen } ;
theme     = "theme", identifier, ["active"], "{", {property}, "}" ;
component = "component", identifier, [":", identifier], block ;
screen    = "screen", identifier, ["active"], block ;
block     = "{", {property | state | node}, "}" ;
node      = identifier, ["#", identifier], block ;
state     = ("hover" | "pressed"), "{", {property}, "}" ;
property  = identifier, ":", value ;
value     = number | string | identifier | color | ("$", identifier) ;
identifier = (letter | "_"), {letter | digit | "_"} ;
color     = "#", (hex6 | hex8) ;
number    = ["+" | "-"], (digits, [".", digits] | ".", digits),
            [("e" | "E"), ["+" | "-"], digits] ;
```

`letter` means ASCII A–Z/a–z. Strings contain UTF-8 and may span lines. Only `\\` and `\"` escapes are supported, and they are decoded into literal backslashes and quotation marks. Newlines may be written literally inside a quoted string. Invalid UTF-8 and NUL bytes are rejected.

Spaces, tabs, LF/CRLF, and `//` comments separate tokens. Newlines have no syntactic meaning. No semicolons, commas, or XML closing tags are needed. The `#` means a local ID after a node type, and a color in a property value; these positions are unambiguous.

Exactly one theme and one screen must be marked `active`, including documents without `$` references. Other screens/themes can be selected by the host. Theme values are literals; tokens cannot reference other tokens. Every referenced token must exist in every theme with a compatible type and valid domain, so switching themes remains predictable.

Keywords `theme`, `component`, `screen`, `active`, `hover`, `pressed`, `edit`, and `delete` are reserved as declaration names and IDs. `edit` and `delete` have no statement syntax in this prototype.

## Components and overrides

```rss
component Action : Button {
    width: 240 height: 48 content: "Continue"
    hover { background: #cceeff }
}
component Primary : Action { background: #78acff }
```

A component without a parent is a generic container. Single inheritance may target another component or a built-in. Derived text and button components retain their primitive behavior regardless of their names. Inheritance cycles and recursive component composition are errors, including unused components.

Property precedence is:

1. An active `pressed` property's value, then an active `hover` property's value.
2. The instance's base declaration.
3. The derived component's base declaration, then its ancestors' declarations.
4. The parent's final value for inherited typography properties.
5. The property's default.

State lookup is per property: a pressed state without `text_color` still permits the hover state's `text_color`. Instance and derived states merge by state name and property name. Active state values override base values, including instance base values. Host-provided text via `set_text` overrides the declarative `content` value until the document is destroyed.

Duplicate properties or duplicate states within a single block are errors. Overrides belong in a derived component or an instance, which keeps accidental duplicates distinguishable from intentional overrides.

```rss
component Card {
    width: 300 height: 100
    Text #title { content: "Default" }
}
screen Main active {
    width: 800 height: 600
    Card #card {
        Text #title { content: "Replacement child" }
    }
}
```

Children without IDs append in source order. A child with the same ID as an inherited/definition child **replaces that child in place**, retaining its position in the child list. Replacement must use the same declared type. Its declaration is complete; omitted old instance properties are not retained, though its component defaults still apply. This rule is the same for component inheritance and instance overrides.

IDs are local to a parent, like fields in an object. Siblings cannot share an ID; repeated component instances can each have a `#score`. In Odin, use `find_child(row, "score")` for local lookup. `find_node_by_id` is a convenience depth-first search and returns the first match; avoid it for repeated local IDs.

## Properties

| Properties | Values and defaults |
| --- | --- |
| `width`, `height` | Nonnegative finite numbers. Required on screens; other node defaults depend on layout below. |
| `x`, `y` | Finite numbers, default 0; negatives are allowed in free layout. Invalid on screen roots. |
| `layout` | `free` (default), `vertical`, `horizontal` |
| `padding`, `gap` | Nonnegative numbers, default 0 |
| `background`, `border_color` | Color, default `transparent` |
| `radius`, `border_width` | Nonnegative numbers, default 0; radius clamps to half the shorter side when drawn. |
| `content` | String, default empty; only Text/Button and components derived from them. |
| `font_size` | Positive number, default 18; inherited |
| `text_color` | Color, default `white`; inherited |
| `text_align` | `left` (default), `center`, `right`; inherited |
| `text_vertical_align` | `top` (default), `middle`, `bottom`; inherited |
| `line_height`, `letter_spacing` | Nonnegative numbers, default 0; inherited. Zero line height uses 1.25 × font size. |
| `font`, `source` | Reserved for future font/image resources; unsupported values/images fail loading. |

Colors are `#RRGGBB`, `#RRGGBBAA` (alpha last), `white`, `black`, or `transparent`. Numbers are logical UI units supplied in the host's coordinate space; no unit suffixes, arithmetic expressions, percentages, or `auto` keyword exist yet. `$token` may supply any property if the token's literal has the right type and domain.

Inherited typography can be set on containers/screens to style descendants. `content` does not inherit. Text nodes wrap within their content rectangle; button labels are a single line. Explicit left alignment stays left on buttons. Vertical middle/bottom alignment for Text anchors the first line; full multiline block alignment is not implemented.

## Layout

A screen's dimensions supply the standalone window's preferred size. An embedded host may supply a different viewport, including a nonzero origin. The root uses that viewport; it does not resize or move the host window.

Padding shrinks the content rectangle and offsets children. Interior dimensions clamp to zero.

- `free`: child `x`/`y` are relative to the parent's content origin. Omitted width/height become zero.
- `vertical`: children stack top to bottom, separated by `gap`. Omitted width fills content width; omitted height is zero. Child x/y have no effect.
- `horizontal`: children stack left to right. Omitted height fills content height; omitted width is zero. Child x/y have no effect.

Explicit zero stays zero. Inherited component dimensions count as explicit. There is no automatic main-axis distribution, shrink-to-fit, overflow clipping, or scrolling. Content may extend beyond a parent, and painter-order hit testing follows the rendered tree.

State blocks may change geometry as well as colors. `update` hit-tests the existing layout, applies states, and recomputes layout before drawing. Geometry-dependent hover can oscillate if a style moves its own target away from the pointer; prefer visual state changes for stable controls.

## Input and application logic

Hover follows the topmost hit node and its ancestors. Later siblings draw on top and block earlier siblings. The nearest Button ancestor is the action target. A primary pointer press captures that button. Releasing over the same button emits one `Click`; releasing outside, pressing outside and dragging in, focus cancellation, or changing screens does not emit a click. `pressed` is visible while the captured button is under the pointer; dragging out and back retains capture until release/cancel.

The language has no `on_click` expressions or script interpreter. Give a button an ID and handle `event.target.instance_id` in Odin. That keeps a menu usable inside an existing game's state and input systems.
