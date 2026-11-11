package ui


Property_Value_Kind :: enum {
	Number,
	String,
	Identifier,
	Theme_Ref,
	Color,
}

Property_Value :: struct {
	kind: Property_Value_Kind,
	data: string,
}

Property_Decl :: struct {
	name:  string,
	value: Property_Value,
	row:   int,
	col:   int,
}

State_Decl :: struct {
	name:       string,
	properties: [dynamic]Property_Decl,
	row:        int,
	col:        int,
}

Node_Decl :: struct {
	type_name:  string,
	id:         string,
	properties: [dynamic]Property_Decl,
	states:     [dynamic]State_Decl,
	children:   [dynamic]Node_Decl,
	row:        int,
	col:        int,
}

Theme_Decl :: struct {
	name:   string,
	active: bool,
	values: [dynamic]Property_Decl,
	row:    int,
	col:    int,
}

Component_Decl :: struct {
	name:       string,
	parent:     string,
	properties: [dynamic]Property_Decl,
	states:     [dynamic]State_Decl,
	children:   [dynamic]Node_Decl,
	row:        int,
	col:        int,
}

Screen_Decl :: struct {
	name:       string,
	active:     bool,
	properties: [dynamic]Property_Decl,
	states:     [dynamic]State_Decl,
	children:   [dynamic]Node_Decl,
	row:        int,
	col:        int,
}

Design :: struct {
	themes:     [dynamic]Theme_Decl,
	components: [dynamic]Component_Decl,
	screens:    [dynamic]Screen_Decl,
}
