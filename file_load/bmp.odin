package file_load

import "../util"
import "core:os"
import "core:slice"
import "core:log"

Pixmap :: util.Pixmap

compression_method_strs := []string {"BI_RGB",
                                         "BI_RLE8",
                                         "BI_RLE4",
                                         "BI_BITFIELDS",
                                         "BI_JPEG",
                                         "BI_PNG",
                                         "BI_ALPHABITFIELDS",
                                         "?",
                                         "?",
                                         "?",
                                         "?",
                                         "BI_CMYKRLE8",
                                         "BI_CMYKRLE4"}

u32_from_le_bytes :: proc (bytes: []u8) -> u32le {
    return (^u32le)(slice.as_ptr(bytes))^
}

u16_from_le_bytes :: proc(bytes: []u8) -> u16le {
    return (^u16le)(slice.as_ptr(bytes))^
} 

load_bmp :: proc(path: string) -> (Pixmap, bool) {
    file, open_err := os.open(path)
    if open_err != nil do return {}, false
    defer os.close(file)

    buffer: [128]u8
    os.read(file, buffer[:18])

    if slice.cmp(transmute(string)buffer[:2], "BM") != .Equal {
        return {}, false
    }

    image_data_offset := u32_from_le_bytes(buffer[0xa:])
    bmp_header_size := u32_from_le_bytes(buffer[0xe:])

    if bmp_header_size != 124 {
        log.warn("NOT BITMAPV5HEADER!")
        return {}, false
    }

    os.read(file, buffer[:16])
    
    width := i32(u32_from_le_bytes(buffer[:]))
    height := i32(u32_from_le_bytes(buffer[4:]))
    bits_per_pixel := u16(u16_from_le_bytes(buffer[0xa:]))
    compression_method := u16(u16_from_le_bytes(buffer[0xc:]))

    log.debugf("Header size: %v\nWidth: %v\nHeight: %v\nBits per pixel: %v\n" + 
        "Compression method: %v\n",
           bmp_header_size, width, height, bits_per_pixel,
           compression_method_strs[compression_method])

    if compression_method != 0 && compression_method != 3 {
        log.error("Compression method is not Bi_RGB")
        return {}, false
    }

    os.read(file, buffer[:bmp_header_size - 20])
    // log.debugf("%.8x %.8x %.8x\n", u32_from_le_bytes(buffer[20:]),
    //        u32_from_le_bytes(buffer[24:]), u32_from_le_bytes(buffer[28:]))

    os.seek(file, i64(image_data_offset), os.SEEK_SET)

    read_fn: proc(os.Handle, ^util.Pixmap)
    switch bits_per_pixel {
        case 16: read_fn = read_pixels_16
        case 24: read_fn = read_pixels_24
        case 32: read_fn = read_pixels_32
        case: 
            return {}, false
    }
    pixmap, alloc_ok := util.make_pixmap(width, height)
    if !alloc_ok {
        return {}, false
    }

    read_fn(file, &pixmap)
    return pixmap, true
}

read_pixels_16 :: proc(file: os.Handle, pixmap: ^Pixmap) {
    pixel: u16
    color: util.Color_4b
    pixels := cast([^]Color_4b)pixmap.pixels
    row := pixmap.w * pixmap.h - pixmap.w

    for y := pixmap.h - 1; y >= 0; y-= 1 {
        for x in 0..<pixmap.w {
            os.read_ptr(file, cast(^u8) &pixel, 2)
            pixels[row + x] = Color_4b {
                b = 8 * u8(pixel & 0x1f),
                g = 8 * u8((pixel >> 5) & 0x1f),
                r = 8 * u8((pixel >> 10) & 0x1f),
                a=0xff,
            }
        }
        row -= pixmap.w
    }
}

read_pixels_24 :: proc(file: os.Handle, pixmap: ^Pixmap) {
    pixel: [3]u8
    
    pixels := cast([^]util.Color_4b)pixmap.pixels
    row := pixmap.w * pixmap.h - pixmap.w
    for y := pixmap.h - 1; y >= 0; y -= 1 {
        for x in 0..<pixmap.w {
            os.read(file, pixel[:])
            pixels[row + x] = Color_4b{r=pixel[2], g=pixel[1], b=pixel[0], a=0xff}
            // draw.plot_pixel(pixmap, x, y, draw.color(pixel[2], pixel[1], pixel[0]))
        }
        if ((pixmap.w * 3) % 4) != 0 {
            os.seek(file, i64(4 - ((pixmap.w * 3) % 4)), os.SEEK_CUR)
        }
        row -= pixmap.w
    }
}

read_pixels_32 :: proc(file: os.Handle, pixmap: ^Pixmap) {
    pixel: [4]u8
    row := pixmap.w * pixmap.h - pixmap.w
    pixels := cast([^]Color_4b)pixmap.pixels

    for y := pixmap.h - 1; y >= 0; y -= 1 {
        for x in 0..<pixmap.w {
            os.read(file, pixel[:])
            pixels[row + x] = Color_4b {
                r=pixel[2],
                g=pixel[1],
                b=pixel[0],
                a=pixel[3],
            }
        }
        row -= pixmap.w
    }
}
