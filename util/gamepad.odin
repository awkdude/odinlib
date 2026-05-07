package util

// TODO: Make all variants uppercase

Gamepad_Button :: enum i32 {
    SOUTH,
    EAST,
    WEST,
    NORTH,
    START,
    SELECT,
    GUIDE,
    BUMPER_LEFT,
    BUMPER_RIGHT,
    THUMB_LEFT,
    THUMB_RIGHT,
}

Gamepad_Hat :: enum i32 {
    UP,
    RIGHT,
    DOWN,
    LEFT,
}

Gamepad_Axis :: enum i32 {
    LEFT_X,
    LEFT_Y,
    RIGHT_X,
    RIGHT_Y,
    TRIGGER_LEFT,
    TRIGGER_RIGHT,
}

Gamepad_State_Buttons :: bit_set[Gamepad_Button; u32]
Gamepad_State_Hats :: bit_set[Gamepad_Hat; u32]

Gamepad_State :: struct {
    buttons: Gamepad_State_Buttons,
    hat: Gamepad_State_Hats,
    axes: [Gamepad_Axis]f32,
}
