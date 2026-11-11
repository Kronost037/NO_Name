# Decisions and resolved inconsistencies

The goal is a native desktop view language with the convenience of HTML structure and CSS-style properties, usable both inside games and in its own host. Existing `.rss` syntax is preserved. Application state, score calculation, callbacks, and navigation decisions belong to Odin; there is no second application scripting language.

| Original inconsistency | Prototype behavior |
| --- | --- |
| Built-ins passed semantics but runtime searched only user components. | Built-ins instantiate directly at every nesting depth. |
| Nested custom nodes copied declarations without expanding their referenced components. | Every instance expands component defaults, inheritance, states, and nested children. |
| Nested runtime nodes lost definition IDs. | IDs survive expansion and are local to a parent. |
| Renderer recognized only the exact names Text and Button. | Primitive identity follows inheritance, including custom buttons. |
| Instance children appended while inherited children replaced matching IDs. | Both use same-type, whole-child replacement in place; anonymous/new-ID children append. |
| Custom text-component instances could be checked as generic containers. | Capability validation follows their inherited render kind. |
| Typography inherited at runtime but was prohibited on containers. | Inheritable typography can be set on containers/screens. |
| Unknown/incorrectly typed screen and component properties slipped through. | All property scopes validate names, types, numeric domains, and enum values. |
| Theme-based alignment values bypassed enum checks. | Tokens undergo the same property-domain validation as literals, in every theme. |
| Lexer accepted string escapes but rendering received their raw spelling. | Supported escapes decode once during parsing. CRLF is accepted. |
| Negative free offsets passed validation but became zero during layout. | Signed x/y survive into geometry. |
| A zero cross-axis size was treated as missing. | Omitted cross-axis sizes fill; explicit zero remains zero. |
| Hover/press geometry never recomputed after initial layout. | State changes reflow in the current update. |
| All overlapping nodes became pressed merely from holding the mouse over them. | Painter-order targeting, press capture, release click, and cancellation live in the UI. |
| An explicit left-aligned button was centered by the renderer. | Computed alignment is honored. |
| Text wrapping and drawing mixed byte and glyph boundaries. | Wrapping preserves UTF-8 boundaries; raylib uses matched DrawTextEx/MeasureTextEx. |
| Graphics wrappers directly called raylib; text flow, hit testing, and UI traversal were raylib code. | Independent graphics contract; backend-neutral renderer/input/layout; separate raylib and recording adapters. |
| Semantic analysis contained main/window lifecycle and files grew to 1823/864 lines. | Library, standalone host, checker, adapters, and tests are separate; responsibilities split across small files. |

Screen dimensions remain explicit in source and supply a preferred standalone size. The host can override the viewport. Root width/height declarations are not responsive constraints; percentage/flex/grid layout is deferred.

State precedence is per property, with pressed before hover, then base/inheritance/defaults. Child replacement follows the original component inheritance rule rather than introducing a new patch syntax. Inherited child IDs are not global selectors; repeated rows use scoped lookup.

`Image`, `source`, and `font` originated as schema placeholders. Image rendering and document-selected fonts are not implemented; loading such unsupported features fails clearly. The host supplies one font per raylib context. No claim is made that all HTML/CSS behavior is supported.

Remaining work includes keyboard/gamepad focus, input widgets, clipping/scrolling, flexible sizing, resource management and images, more event types, an SDL adapter, performance work on large documents, and broader platform testing. The current renderer performs on-demand property lookup and text measurement; it is intended as a small working foundation.

## Validation

Regression tests exercise declaration errors, theme domains, CRLF and escapes, nested expansion, inherited primitives, override order, local IDs, copied host strings, repeated updates, viewport offsets, explicit zero/negative geometry, pointer capture/cancellation/overlap, navigation, state reflow, and rendering through a headless backend. The standalone host and embedding example also build, and the standalone menu/session/leaderboard/theme path was exercised with real X11 pointer events and screenshots on Linux.
