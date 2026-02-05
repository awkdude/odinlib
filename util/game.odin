package util

Game_Init :: struct {
    gl_set_proc_address: proc(p: rawptr, name: cstring),
    platform_command_proc: proc(_: Platform_Command),
    set_gamepad_rumble_proc: proc(weak, strong: f32),
    get_window_dpi: proc() -> i32,
    window_size: vec2,
}

Game_Update :: struct {
    window_size: vec2,
    gamepad_state: Gamepad_State,
    is_gamepad_connected: bool,
}

