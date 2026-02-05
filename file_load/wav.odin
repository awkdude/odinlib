#+build !windows
package file_load

import "core:os"
import "core:mem"
import "core:log"
import "../util"

Audio_Buffer :: util.Audio_Buffer

is_wav :: proc(path: string) -> bool {
    file, open_err := os.open(path)
    if open_err != nil {
        return false
    }
    defer os.close(file)

    header_buf: [16]u8
    os.read(file, header_buf[:])

    return mem.compare(header_buf[:4], transmute([]u8)string("RIFF")) == 0 &&
        mem.compare(header_buf[8:12], transmute([]u8)string("WAVE")) == 0
}

load_wav :: proc(path: string) -> (Audio_Buffer, bool) #optional_ok {
    file, open_err := os.open(path)
    if open_err != nil {
        return {}, false
    }
    defer os.close(file)

    header_buf: [64]u8
    os.read(file, header_buf[:44])

    if mem.compare(header_buf[:4], transmute([]u8)string("RIFF")) != 0 ||
        mem.compare(header_buf[8:12], transmute([]u8)string("WAVE")) != 0 {
        log.error("Invalid header!\n")
        return {}, false
    }

    data_size :=  cast(uint)u32_from_le_bytes(header_buf[40:44])
    bits_per_sample := cast(i32)u16_from_le_bytes(header_buf[34:36])
    bit_format: util.Audio_Resolution
    if bits_per_sample == 8 {
        bit_format = .U8
    } else if bits_per_sample == 16 {
        bit_format = .S16
    }
    num_channels := cast(i32)u16_from_le_bytes(header_buf[22:24])
    sample_rate := cast(i32)u32_from_le_bytes(header_buf[24:28])

    audio_buf := Audio_Buffer {
        data            = make([]u8, data_size),
        num_channels    = num_channels,
        sample_rate     = sample_rate,
        bit_format      = bit_format,
    }

    audio_buf.sample_count = data_size / cast(uint)(audio_buf.num_channels * (bits_per_sample / 8))

    log.debugf("Channels: %d\nSample rate: %dHz\nBits per sample: %d\nSample count: %d\n",
           audio_buf.num_channels, audio_buf.sample_rate,
           bits_per_sample, audio_buf.sample_count)
    os.read(file, audio_buf.data[:])

    return audio_buf, true
}
