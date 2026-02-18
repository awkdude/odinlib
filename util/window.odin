package util

Window_ID :: uintptr

Renderer_Backend :: enum {
    Software,
    Opengl,
}

Window_Event :: struct {
    type: Window_Event_Type,
    source_window: Window_ID,
    using data: struct #raw_union {
        key: struct {
            keycode: u32,
            pressed, repeated: bool,
        },
        char_codepoint: rune,
        mouse_button: struct {
            button: Mouse_Button,
            pressed: bool,
            position: vec2,
        },
        vec2: vec2,
        files: []string,
    },
}

Window_Event_Type :: enum {
    Key,
    Char_Input,
    Window_Resize,
    Mouse_Button,
    Mouse_Move,
    Mouse_Wheel,
    Need_Repaint,
    Gain_Focus,
    Lose_Focus,
    Window_Close,
    Drop,
}

Mouse_Button :: enum {
    Left,
    Middle,
    Right,
    X1,
    X2,
}

Mouse_Cursor_Type :: enum {
    Normal,
    Wait,
    IBeam,
    Hand,
}

Platform_Command :: struct {
    type: enum {
        Rename_Window,
        Change_Mouse_Cursor,
        Resize_Window,
        Set_Window_Min_Size,
        Set_Window_Max_Size,
        Change_Window_Icon,
        Quit,
    },
    window: Window_ID,
    using data: struct #raw_union {
        size: Maybe(vec2),
        cursor_type: Mouse_Cursor_Type,
        title, path: string,
    },
}

