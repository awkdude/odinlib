package file_load

import "../util"
import "core:os"
import "core:mem"
import "core:slice"
import "core:log"

QOI_Header :: struct #packed {
    magic: [4]u8,
    width, height: u32be,
    channels, colorspace: u8,
}


// Set true to log
when false { 
    qoi_debug :: log.debug
} else {
    qoi_debug :: proc(_: ..any, sep := "", location := #caller_location) {}
}

@(private="file")
hash_index :: proc "contextless" (color: util.Color4b) -> int {
    return (int)(color.r*3 + color.g*5 + color.b*7 + color.a*11) % 64
}

load_qoi :: proc(
    path: string,
    pixel_format: util.Pixel_Format,
    allocator := context.allocator) -> (Pixmap, bool) 
{
    magic := [4]u8 {'q', 'o', 'i', 'f'}
    data, load_err := os.read_entire_file_from_path(path, allocator)
    if load_err != nil do return {}, false
    header: ^QOI_Header = transmute(^QOI_Header)raw_data(data)
    if !slice.equal(header.magic[:], magic[:]) do return {}, false
    pixmap, pix_ok := util.make_pixmap(
        cast(i32)header.width,
        cast(i32)header.height,
        pixel_format, allocator
    )
    pixel_area := (int)(pixmap.w * pixmap.h)
    if !pix_ok do return {}, false
    prev_color := util.Color4b {0, 0, 0, 255}
    color_array: [64]util.Color4b
    byte_index := size_of(QOI_Header)
    assert(byte_index == 14)
    pix_row := cast([^]u8)pixmap.pixels
    end := mem.ptr_offset(pix_row, pixmap.h*pixmap.pitch)
    x_off: i32 = 0
    run_length := 0
    for pix_row < end {
        if run_length > 0 {
            run_length -= 1
        } else if byte_index < (len(data) - 8) {
            switch b0 := data[byte_index]; {
            case b0 == 0b11111110: // QOI_OP_RGB
                qoi_debug("QOI_OP_RGB")
                prev_color.r = data[byte_index+1]
                prev_color.g = data[byte_index+2]
                prev_color.b = data[byte_index+3]
                byte_index += 4
            case b0 == 0b11111111: // QOI_OP_RGBA
                qoi_debug("QOI_OP_RGBA")
                prev_color.r = data[byte_index+1]
                prev_color.g = data[byte_index+2]
                prev_color.b = data[byte_index+3]
                prev_color.a = data[byte_index+4]
                byte_index += 5
            case b0 >> 6 == 0: // QOI_OP_INDEX
                qoi_debug("QOI_OP_INDEX")
                prev_color = color_array[b0 & 0x3f]
                byte_index += 1
            case b0 >> 6 == 1: // QOI_OP_DIFF
                qoi_debug("QOI_OP_DIFF")
                prev_color.r += (b0 >> 4) & 0x3 - 2
                prev_color.g += (b0 >> 2) & 0x3 - 2
                prev_color.b += (b0 >> 0) & 0x3 - 2
                byte_index += 1
            case b0 >> 6 == 2: // QOI_OP_LUMA
                qoi_debug("QOI_OP_LUMA")
                b1 := data[byte_index+1]
                dg := (b0 & 0x3f) - 32
                prev_color.r += (dg - 8) + ((b1 >> 4) & 0xf)
                prev_color.g += dg
                prev_color.b += (dg - 8) + ((b1 >> 0) & 0xf)
                byte_index += 2
            case b0 >> 6 == 3: // QOI_OP_RUN
                qoi_debug("QOI_OP_RUN")
                run_length = (int)(b0 & 0x3f)
                byte_index += 1
            }
            color_array[hash_index(prev_color)] = prev_color
        }
        (cast([^]ColorU32)pix_row)[x_off] = util.pack_color(prev_color, pixel_format)
        /* There should be some simple expression to index into pitch-aligned pixmap 
           with a pixel index but I'm too dumb 
           so this is the best I can think of right now
        */
        x_off += 1
        if x_off >= pixmap.w {
            pix_row = mem.ptr_offset(pix_row, pixmap.pitch)
            x_off = 0
        }
    }

    return pixmap, true
}
