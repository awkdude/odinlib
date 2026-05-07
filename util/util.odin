// Personal general purpose utility package
package util

import "core:unicode"
import "core:math"
import "core:log"
import "core:time"
import "core:mem"
import "base:runtime"

Keyboard_State :: [32]u8

// Used to represent color using RGBA, 8 bits per channel.
// Must be converted to Color4b when drawing on framebuffer.
Color_RGBA :: [4]u8

Input_State :: struct {
    keyboard: Keyboard_State,
    mouse_position: vec2,
    mouse_buttons: bit_set[Mouse_Button],
    // This struct should be cleared at end of every frame
    using transient: struct {
        keys_pressed, keys_released: Keyboard_State,
        mouse_wheel_delta, mouse_delta: vec2,
        buttons_pressed, buttons_released: bit_set[Gamepad_Button],
    },
    gamepad: Gamepad_State,
}

set_input_state_from_event :: proc "contextless" (
    input: ^Input_State,
    event: Window_Event) 
{
	#partial switch event.type {
	case .Key:
		if event.key.keycode < 256 {
			bit_modify(input.keyboard[:], event.key.keycode, event.key.pressed)
			if event.key.pressed {
				bit_modify(input.keys_pressed[:], event.key.keycode, true)
			} else {
				bit_modify(input.keys_released[:], event.key.keycode, true)
			}
		}
	case .Mouse_Move:
		input.mouse_position = event.vec2
	case .Mouse_Button:
		if event.mouse_button.pressed {
			input.mouse_buttons += {event.mouse_button.button}
		} else {
			input.mouse_buttons -= {event.mouse_button.button}
		}
	case .Mouse_Wheel:
		input.mouse_wheel_delta += event.vec2
	}
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
    return Pixmap {
        pixels=pixels,
        w=w,
        h=h,
        pitch=w*bytes_per_pixel,
        bytes_per_pixel=bytes_per_pixel
    }, err == .None
}

wait_frame_interval :: proc "contextless"(
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

// Defines bit shift for each color channel
// TODO: Maybe rename to Pixel_Layout?
Pixel_Format :: struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
}

// ARGB
DEFAULT_PIXEL_FORMAT :: Pixel_Format {
    r=16,
    g=8,
    b=0,
    a=24,
}

pack_color_rgba :: #force_inline proc(
    rgba: Color_RGBA,
    format: Pixel_Format = DEFAULT_PIXEL_FORMAT) -> Color4b
{
    color4b: Color4b
    color4b |= cast(u32)(rgba.r) << format.r
    color4b |= cast(u32)(rgba.g) << format.g
    color4b |= cast(u32)(rgba.b) << format.b
    color4b |= cast(u32)(rgba.a) << format.a
    return color4b
}

// Internal/Native representation of pixel color
Color4b :: u32

color4f_to_4b :: proc "contextless" (
	color: Color4f,
	format: Pixel_Format = DEFAULT_PIXEL_FORMAT) -> Color4b
{
    color4b: Color4b
    color4b |= ((cast(u32)(color.r * 255.0)) & 0xff) << format.r
    color4b |= ((cast(u32)(color.g * 255.0)) & 0xff) << format.g
    color4b |= ((cast(u32)(color.b * 255.0)) & 0xff) << format.b
    color4b |= ((cast(u32)(color.a * 255.0)) & 0xff) << format.a

    return color4b
}

pack_color :: proc {
    color4b_to_4f,
    pack_color_rgba,
}

unpack_color_rgba :: proc "contextless" (
	color: Color4b,
	format: Pixel_Format = DEFAULT_PIXEL_FORMAT) -> Color_RGBA
{
	return Color_RGBA {
		cast(u8)((color >> format.r) & 0xff),
		cast(u8)((color >> format.g) & 0xff),
		cast(u8)((color >> format.b) & 0xff),
		cast(u8)((color >> format.a) & 0xff),
	}
}

color4b_to_4f :: proc "contextless" (
	color: Color4b,
	format: Pixel_Format = DEFAULT_PIXEL_FORMAT) -> Color4f
{
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
