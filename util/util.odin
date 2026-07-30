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
// Must be converted to ColorU32 when drawing on framebuffer.
Color4b :: [4]u8

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
	case .Lose_Focus:
		input^ = {}
	}
}

Pixmap :: struct #all_or_none {
    pixels: rawptr,
    w, h: i32,
    // bytes in row of pixels
    pitch: i32,
    format: Pixel_Format,
}

// Allocate pixmap
make_pixmap :: proc(
    w, h: i32,
    format: Pixel_Format,
    allocator := context.allocator) -> (Pixmap, bool) #optional_ok
{
	assert(format.bytes_per_pixel == 1 || format.bytes_per_pixel == 4)
	pitch := w*format.bytes_per_pixel
	mod_16 := pitch % 16
	if mod_16 != 0 {
		pitch += 16 - mod_16
	}
    pixels, err := mem.alloc(
    	cast(int)(pitch * h),
     	alignment=16,
      	allocator=allocator
    )
    return Pixmap {
        pixels=pixels,
        w=w,
        h=h,
        pitch=w*format.bytes_per_pixel,
        format=format,
    }, err == nil
}

Pixel_Format :: struct {
	using layout: Pixel_Layout,
	bytes_per_pixel: i32,
}

// Defines bit shift for each color channel
Pixel_Layout :: struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
}

// BGRA (from lowest to highest shift)
// Used for Win32 DIB
DEFAULT_PIXEL_LAYOUT :: Pixel_Layout {
    r=16,
    g=8,
    b=0,
    a=24,
}

pack_color_4b :: #force_inline proc "contextless" (
    rgba: Color4b,
    format: Pixel_Format) -> ColorU32
{
    color_u32: ColorU32
    color_u32 |= cast(u32)(rgba.r) << format.r
    color_u32 |= cast(u32)(rgba.g) << format.g
    color_u32 |= cast(u32)(rgba.b) << format.b
    color_u32 |= cast(u32)(rgba.a) << format.a
    return color_u32
}

// Internal/Native representation of pixel color
ColorU32 :: u32

pack_color_4f :: proc "contextless" (
	color: Color4f,
	format: Pixel_Format) -> ColorU32
{
    color_u32: ColorU32
    color_u32 |= ((cast(u32)math.round(color.r * 255.0)) & 0xff) << format.r
    color_u32 |= ((cast(u32)math.round(color.g * 255.0)) & 0xff) << format.g
    color_u32 |= ((cast(u32)math.round(color.b * 255.0)) & 0xff) << format.b
    color_u32 |= ((cast(u32)math.round(color.a * 255.0)) & 0xff) << format.a

    return color_u32
}

pack_color :: proc {
    pack_color_4f,
    pack_color_4b,
}

unpack_color_4b :: proc "contextless" (
	color: ColorU32,
	format: Pixel_Format) -> Color4b
{
	return Color4b {
		cast(u8)((color >> format.r) & 0xff),
		cast(u8)((color >> format.g) & 0xff),
		cast(u8)((color >> format.b) & 0xff),
		cast(u8)((color >> format.a) & 0xff),
	}
}

unpack_alpha_4b :: #force_inline proc "contextless" (
    color: ColorU32,
    format: Pixel_Format) -> u8
{
    return cast(u8)((color >> format.a) & 0xff)
}

unpack_color_4f :: proc "contextless" (
	color: ColorU32,
	format: Pixel_Format) -> Color4f
{
    color4f: Color4f = {
        (cast(f32)((color >> format.r) & 0xff) / 255.0),
        (cast(f32)((color >> format.g) & 0xff) / 255.0),
        (cast(f32)((color >> format.b) & 0xff) / 255.0),
        (cast(f32)((color >> format.a) & 0xff) / 255.0),
    }
    return color4f
}

// Used after swap_buffers or framebuffer blit to window
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

Ring_Buffer :: struct($T: typeid) {
	buffer: []T,
	head, tail: int,
}

ring_buffer_push :: proc(rb: ^Ring_Buffer($T), elem: T) {
	rb.buffer[rb.tail] = elem
	rb.tail = (rb.tail + 1) % len(rb.buffer)
	if rb.tail == rb.head {
		rb.head = (rb.head + 1) % len(rb.buffer)
	}
}

ring_buffer_clear :: proc(rb: ^Ring_Buffer($T)) {
	mem.zero_slice(rb.buffer)
	rb.head = 0
	rb.tail = 0
}

ring_buffer_pop :: proc(rb: ^Ring_Buffer($T)) -> (T, bool) {
	// TODO:
}

// Sound_Resolution :: enum i32 {
//     U8  = 8,
//     S8  = SOUND_RES_SIGNED | 8,
//     U16 = 16,
//     S16 = SOUND_RES_SIGNED | 16,
// }
