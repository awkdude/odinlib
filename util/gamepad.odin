package util

// TODO: Make all variants uppercase 

Gamepad_Button :: enum i32 {
    // TODO: Rename to south, east, west, north respectively
    South,
    East,
    West,
    North,
    Start,
    Select,
    Guide,
    Bumper_Left,
    Bumper_Right,
    Thumb_Left,
    Thumb_Right,
}

Gamepad_Hat :: enum i32 {
    Up,
    Right,
    Down,
    Left,
}

Gamepad_Axis :: enum i32 {
    Left_X,
    Left_Y,
    Right_X,
    Right_Y,
    Trigger_Left,
    Trigger_Right,
}

Gamepad_State_Buttons :: bit_set[Gamepad_Button; u32]
Gamepad_State_Hats :: bit_set[Gamepad_Hat; u32]

Gamepad_State :: struct {
    buttons: Gamepad_State_Buttons, 
    hat: Gamepad_State_Hats,
    axes: [Gamepad_Axis]f32,
}
