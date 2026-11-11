package ui
import "core:fmt"

Primitive :: enum { Panel, Text, Button, Image }
Interaction_State :: struct { hover, pressed: bool }
Computed_Style :: struct {
    properties: [dynamic]Property_Decl,
    states: [dynamic]State_Decl,
}
Node :: struct {
    origin_definition, instance_id: string,
    primitive: Primitive,
    host_content: string,
    has_host_content: bool,
    parent: ^Node,
    children: [dynamic]^Node,
    computed_style: Computed_Style,
    rect: Rect,
    interaction: Interaction_State,
}
primitive_for :: proc(name: string, components: [dynamic]Component_Definition) -> Primitive {
    current := name
    for _ in 0 ..= len(components) {
        switch current {
        case "Text": return .Text
        case "Button": return .Button
        case "Image": return .Image
        case "Panel": return .Panel
        }
        index, found := find_definition_component(components, current)
        if !found { break }
        current = components[index].parent
    }
    return .Panel
}
// Expand definitions at every depth, preserving primitive identity and local IDs.
instantiate_decl :: proc(decl: Node_Decl, components: [dynamic]Component_Definition, stack: []string = nil) -> (^Node, Semantic_Error) {
    for name in stack {
        if name == decl.type_name {
            return nil, make_semantic_error(fmt.aprintf("recursive component composition involving '%s'", name), decl.row, decl.col)
        }
    }
    node := new(Node)
    node.origin_definition = decl.type_name
    node.instance_id = decl.id
    node.primitive = primitive_for(decl.type_name, components)
    if node.primitive == .Image {
        return nil, make_semantic_error("Image rendering is not supported by this prototype", decl.row, decl.col)
    }
    _, builtin := builtin_render_kind(decl.type_name)
    if !builtin {
        index, found := find_definition_component(components, decl.type_name)
        if !found {
            return nil, make_semantic_error(fmt.aprintf("unknown component '%s'", decl.type_name), decl.row, decl.col)
        }
        effective := components[index].effective
        node.computed_style.properties = copy_properties(effective.properties)
        node.computed_style.states = copy_states(effective.states)
        path := make([]string, len(stack) + 1)
        defer delete(path)
        copy(path, stack)
        path[len(stack)] = decl.type_name
        for child in effective.children {
            child_node, err := instantiate_decl(effective_as_decl(child), components, path)
            if err.message != "" { return nil, err }
            child_node.parent = node
            append(&node.children, child_node)
        }
    }
    node.computed_style.properties = merge_properties(node.computed_style.properties, decl.properties)
    node.computed_style.states = merge_states(node.computed_style.states, decl.states)
    for child in decl.children {
        // Matching local IDs replace inherited children in place, like inheritance.
        replacement := -1
        for existing, i in node.children {
            if child.id != "" && child.id == existing.instance_id {
                if child.type_name != existing.origin_definition {
                    return nil, make_semantic_error("identified child override cannot change type", child.row, child.col)
                }
                replacement = i
                break
            }
        }
        child_node, err := instantiate_decl(child, components, stack)
        if err.message != "" { return nil, err }
        child_node.parent = node
        if replacement >= 0 { node.children[replacement] = child_node }
        else { append(&node.children, child_node) }
    }
    return node, Semantic_Error{}
}
effective_as_decl :: proc(node: Effective_Node) -> Node_Decl {
    result := Node_Decl{type_name = node.type_name, id = node.definition_id,
        properties = node.properties, states = node.states}
    for child in node.children { append(&result.children, effective_as_decl(child)) }
    return result
}
instantiate_screen :: proc(screen: Screen_Definition, components: [dynamic]Component_Definition, definitions: Definition_Set) -> (^Node, Semantic_Error) {
    root := new(Node)
    root.origin_definition = screen.name
    root.computed_style.properties = copy_properties(screen.properties)
    root.computed_style.states = copy_states(screen.states)
    for child in screen.children {
        child_node, err := instantiate_decl(child, components)
        if err.message != "" { return nil, err }
        child_node.parent = root
        append(&root.children, child_node)
    }
    return root, Semantic_Error{}
}
// IDs are local to a parent; direct lookup avoids ambiguity across repeated components.
find_child :: proc(parent: ^Node, id: string) -> ^Node {
    if parent != nil {
        for child in parent.children { if child.instance_id == id { return child } }
    }
    return nil
}
find_node_by_id :: proc(node: ^Node, id: string) -> ^Node {
    if node == nil || id == "" { return nil }
    if node.instance_id == id { return node }
    for child in node.children {
        if result := find_node_by_id(child, id); result != nil { return result }
    }
    return nil
}
