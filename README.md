# Declarative UI Language

A small declarative UI language written in Odin.

The idea is simple: describe an interface in a `.rss` file, and let the program parse, validate, resolve, lay out, and render it.

The project is still in early development.

## Example

A simple component can look like this:

```rss
theme Dark active {
    background: #101820
    text: #ffffff
    accent: #4f8cff
}

component Card {
    width: 300
    height: 160
    padding: 20
    background: $background
    layout: vertical
    gap: 10

    Text {
        height: 30
        content: "Hello"
        font_size: 24
        text_color: $text
    }

    Button {
        width: 260
        height: 44
        content: "Continue"
        text_align: left
        background: $accent

        hover {
            background: #6aa0ff
            text_vertical_align: middle
        }

        pressed {
            background: #cc3f67
        }
    }
} 

screen Main active {
    width: 800
    height: 600
    background: $background

    Card {
        x: 100
        y: 100
    }
}
```

The language uses a CSS-like property syntax, but its structure is based around components, screens, states, and nested UI nodes.

##### Output of design.rss:
![alt text](design.rss.png)

## What it currently supports

* Themes and theme references such as `$background`
* Components
* Component inheritance
* Screens
* Nested UI nodes
* Instance-level property and state overrides
* `hover` and `pressed` states
* Typed properties and semantic validation
* Free, vertical, and horizontal layouts
* Padding and layout gaps
* Background colors, borders, and rounded corners
* Text alignment and vertical alignment
* Basic text wrapping
* Mouse hover and press detection
* Raylib rendering

The built-in UI types are:

* `Text`
* `Button`
* `Panel`

An `Image` type is defined in the language, but image rendering is not implemented yet.

## How it works

The current pipeline is roughly:

```text
design.rss
    ↓
Lexer
    ↓
Parser
    ↓
Semantic validation
    ↓
Component / property resolution
    ↓
Runtime UI tree
    ↓
Layout
    ↓
Raylib rendering
```

The project is written fully in Odin, with raylib used for the current rendering backend.

## Running

### Requirements

* [Odin](https://odin-lang.org/)

From the repository directory:

```bash
odin run .
```

The example interface is defined in:

```text
design.rss
```

Edit that file to experiment with the language.

## Project structure

```text
lexer.odin       Tokenization
parser.odin      Parsing and syntax structures
semantic.odin    Validation and component resolution
resolver.odin    Runtime property resolution
runtime.odin     Runtime UI tree
layout.odin      UI layout
graphics.odin    Graphics abstraction
raylib.odin      Raylib rendering backend
design.rss       Example UI written in the language
```

## Current limitations

This is still a small language rather than a complete UI framework.

It currently does not provide:

* Application scripting or event callbacks
* Navigation or application state
* Animation
* A visual editor
* Responsive layout
* Custom image rendering
* A complete widget library

The focus for now is the language and the UI pipeline itself.

## Why this exists

This started as an experiment in building a declarative UI system from scratch.

The main goal is to explore how a UI description can move from source text to a validated runtime tree and finally to something rendered on screen, without relying on an existing UI framework.

## License

MIT License
