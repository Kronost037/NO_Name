package ui


Semantic_Severity :: enum {
	Error,
	Warning,
}

Semantic_Diagnostic :: struct {
	severity: Semantic_Severity,
	message:  string,
	row:      int,
	col:      int,
}

Semantic_Result :: struct {
	design:      Design,
	diagnostics: [dynamic]Semantic_Diagnostic,
}

Property_Type :: enum {
	Number,
	String,
	Color,
	Enum,
}

Property_Capability :: enum {
	Any_Node,
	Text_Capable,
	Text_Or_Button,
	Image,
	Layout_Parent,
	Free_Position,
}

Property_Spec :: struct {
	name:          string,
	type:          Property_Type,
	inherited:     bool,
	default_value: string,
	capability:    Property_Capability,
}

Render_Kind :: enum {
	Generic,
	Text,
	Image,
}

Effective_Node :: struct {
	type_name:     string,
	definition_id: string,
	properties:    [dynamic]Property_Decl,
	states:        [dynamic]State_Decl,
	children:      [dynamic]Effective_Node,
}

Theme_Definition :: struct {
	name:   string,
	active: bool,
	values: [dynamic]Property_Decl,
}

Component_Definition :: struct {
	name:           string,
	parent:         string,
	row:            int,
	col:            int,
	own_properties: [dynamic]Property_Decl,
	own_states:     [dynamic]State_Decl,
	own_children:   [dynamic]Node_Decl,
	render_kind:    Render_Kind,
	effective:      Effective_Node,
	resolved:       bool,
}

Screen_Definition :: struct {
	name:       string,
	active:     bool,
	properties: [dynamic]Property_Decl,
	states:     [dynamic]State_Decl,
	children:   [dynamic]Node_Decl,
}

Definition_Set :: struct {
	themes:        [dynamic]Theme_Definition,
	components:    [dynamic]Component_Definition,
	screens:       [dynamic]Screen_Definition,
	active_theme:  int,
	active_screen: int,
}

Semantic_Error :: struct {
	message: string,
	row:     int,
	col:     int,
}
