package util

import "core:unicode"
import "core:math"
import "core:time"
import "core:mem"
import "base:runtime"

PLATFORM_BACKEND :: #config(BACKEND, "native")

Keyboard_State :: [32]u8

Input_State :: struct {
    keyboard: Keyboard_State,
    mouse_position: vec2,
    mouse_buttons: bit_set[Mouse_Button],
    using transient: struct {
        keys_pressed, keys_released: Keyboard_State,
        mouse_wheel_delta, mouse_delta: vec2,
        buttons_pressed, buttons_released: bit_set[Gamepad_Button],
    },
    gamepad: Gamepad_State,
}


// NOTE: The ordering is dependent on target platform
// when ODIN_OS == .Windows {
Color_4b :: struct {
    b, g, r, a: u8,
}
// }

Pixmap :: struct {
    pixels: rawptr,
    w, h, bytes_per_pixel: i32,
}

make_pixmap :: proc(
    w, h: i32,
    bytes_per_pixel: i32 = 4,
    allocator := context.allocator) -> (Pixmap, bool) #optional_ok 
{
    pixels, err := mem.alloc(cast(int)(w * h * bytes_per_pixel), allocator=allocator)
    return Pixmap {pixels=pixels, w=w, h=h, bytes_per_pixel=bytes_per_pixel}, err == .None
}

wait_frame_interval :: proc(
    previous_frame_tick: ^time.Tick,
    target_frame_interval: time.Duration)
{
    now := time.tick_now()
    time_elapsed_duration := time.tick_diff(previous_frame_tick^, now)
    time_elapsed_usec := cast(i64)time.duration_microseconds(time_elapsed_duration)
    target_frame_interval_usec := cast(i64)time.duration_microseconds(target_frame_interval)
    if time_elapsed_usec < target_frame_interval_usec {
        sleep_time := time.Duration(
            max(
                1,
                target_frame_interval_usec - time_elapsed_usec
            )
        )
        time.sleep(sleep_time * time.Microsecond)
    }
    previous_frame_tick^ = now
}


// Sound_Resolution :: enum i32 {
//     U8  = 8,
//     S8  = SOUND_RES_SIGNED | 8,
//     U16 = 16,
//     S16 = SOUND_RES_SIGNED | 16,
// }

