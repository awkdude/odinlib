package util

Audio_Buffer :: struct {
    data: []u8,
    num_channels, sample_rate: i32, 
    bit_format: Audio_Resolution, 
    sample_count: uint,
}

Audio_Resolution :: enum i32 {
    U8,
    S16,
}
