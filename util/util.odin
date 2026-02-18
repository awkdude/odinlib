package util

import "core:unicode"
import "core:math"
import "core:log"
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

Pixmap :: struct {
    pixels: rawptr,
    w, h, bytes_per_pixel, pitch: i32,
    pixel_format: Pixel_Format, 
}

make_pixmap :: proc(
    w, h: i32,
    bytes_per_pixel: i32 = 4,
    allocator := context.allocator) -> (Pixmap, bool) #optional_ok 
{
    pixels, err := mem.alloc(cast(int)(w * h * bytes_per_pixel), allocator=allocator)
    // FIXME: Set pitch to be multiple of 4 or 8
    return Pixmap {pixels=pixels, w=w, h=h, pitch=w,bytes_per_pixel=bytes_per_pixel}, err == .None
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
        // log.debugf("dt: %v usec", target_frame_interval_usec - time_elapsed_usec)
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

Pixel_Format :: struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
}

DEFAULT_PIXEL_FORMAT :: Pixel_Format {
    r=16,
    g=8,
    b=0,
    a=24,
}

Color4b :: u32

color4f_to_4b :: proc(color: Color4f, format: Pixel_Format = DEFAULT_PIXEL_FORMAT) -> Color4b {
    color4b: Color4b
    color4b |= (cast(u32)(color.r * 255.0)) << format.r
    color4b |= (cast(u32)(color.g * 255.0)) << format.g
    color4b |= (cast(u32)(color.b * 255.0)) << format.b
    color4b |= (cast(u32)(color.a * 255.0)) << format.a

    return color4b
}

color4b_to_4f :: proc(color: Color4b, format: Pixel_Format = DEFAULT_PIXEL_FORMAT) -> Color4f {
    color4f: Color4f = {
    cast(f32)(((color >> format.r) & 0xff) / 255.0),
        cast(f32)(((color >> format.g) & 0xff) / 255.0),
        cast(f32)(((color >> format.b) & 0xff) / 255.0),
        cast(f32)(((color >> format.a) & 0xff) / 255.0),
    }
    return color4f
}


// Sound_Resolution :: enum i32 {
//     U8  = 8,
//     S8  = SOUND_RES_SIGNED | 8,
//     U16 = 16,
//     S16 = SOUND_RES_SIGNED | 16,
// }

