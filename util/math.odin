package util
import "core:math"
import "base:intrinsics"
import "core:unicode"

Rect :: struct {
    x, y, w, h: i32,
}

Rectf :: struct {
    x, y, w, h: f32,
}

BBox :: struct {
    x0, y0, x1, y1 : i32,
}

BBoxf :: struct {
    x0, y0, x1, y1 : f32,
}

vec2    :: [2]i32
vec2f   :: [2]f32
vec3f   :: [3]f32
mat3    :: matrix[3, 3]f32
mat4    :: matrix[4, 4]f32
Color_f :: [4]f32 // TODO: Remove
Color3f :: [3]f32
Color4f :: [4]f32


normalize_to_range :: proc(value, mini, maxi, minf, maxf: f32) -> f32 {
    return ((value - mini) / (maxi - mini)) * (maxf - minf) + minf;
}

point_in_rect_i :: proc(p: vec2, rect: Rect) -> bool {
    return p.x >= rect.x && p.x < (rect.x + rect.w) && 
        p.y >= rect.y && p.y < (rect.y + rect.h)
}

point_in_rect_f :: proc(p: vec2f, rect: Rectf) -> bool {
    return p.x >= rect.x && p.x < (rect.x + rect.w) && 
        p.y >= rect.y && p.y < (rect.y + rect.h)
}

point_in_rect :: proc {
    point_in_rect_i,
    point_in_rect_f 
}

dip_to_px :: proc(dip, dots_per_inch: i32) -> i32 {
    return i32(cast(f32)dip / 96.0 * cast(f32)dots_per_inch)
}

size_to_rect :: proc(size: vec2) -> Rect {
    return Rect { w=size.x, h=size.y }
}

scale_vec2_s :: proc(v: vec2, s: f32) -> vec2 {
    return vec2 {
        cast(i32)(cast(f32)v.x * s),
        cast(i32)(cast(f32)v.y * s),
    }
}

scale_vec2_v :: proc(v: vec2, sv: vec2f) -> vec2 {
    return vec2 {
        cast(i32)(cast(f32)v.x * sv.x),
        cast(i32)(cast(f32)v.y * sv.y),
    }
}

scale_vec2 :: proc {
    scale_vec2_s,
    scale_vec2_v,
}

pos_size_to_rect :: proc(pos, size: vec2) -> Rect {
    return Rect {x=pos.x, y=pos.y, w=size.x, h=size.y}
}

// bbox rect conversion {{{
bbox_to_rect_i :: proc(bbox: BBox) -> Rect {
    return Rect {
        x=min(bbox.x0, bbox.x1),
        y=min(bbox.y0, bbox.y1),
        w=math.abs(bbox.x1 - bbox.x0),
        h=math.abs(bbox.y1 - bbox.y0),
    }
}

bbox_to_rect_f :: proc(bbox: BBoxf) -> Rectf {
    return Rectf {
        x=min(bbox.x0, bbox.x1),
        y=min(bbox.y0, bbox.y1),
        w=math.abs(bbox.x1 - bbox.x0),
        h=math.abs(bbox.y1 - bbox.y0),
    }
}

bbox_to_rect :: proc {
    bbox_to_rect_i, 
    bbox_to_rect_f, 
}

rect_to_bbox_i :: proc(rect: Rect) -> BBox {
    bbox := BBox {
        x0=rect.x,
        y0=rect.y,
        x1=rect.x+rect.w,
        y1=rect.y+rect.h,
    }
    if rect.w < 0 {
        bbox.x0, bbox.x1 = bbox.x1, bbox.x0
    }
    if rect.h < 0 {
        bbox.y0, bbox.y1 = bbox.y1, bbox.y0
    }
    return bbox
}

rect_to_bbox_f :: proc(rect: Rectf) -> BBoxf {
    bbox := BBoxf {
        x0=rect.x,
        y0=rect.y,
        x1=rect.x+rect.w,
        y1=rect.y+rect.h,
    }
    if rect.w < 0 {
        bbox.x0, bbox.x1 = bbox.x1, bbox.x0
    }
    if rect.h < 0 {
        bbox.y0, bbox.y1 = bbox.y1, bbox.y0
    }
    return bbox
}

rect_to_bbox :: proc {
    rect_to_bbox_i,
    rect_to_bbox_f,
}


// }}}

rect_centered_in_rect :: proc(inner_rect, outer_rect: Rect) -> Rect {
    outer_center := vec2{outer_rect.w / 2, outer_rect.h/2}
    return Rect {
        outer_center.x - (inner_rect.w / 2),
        outer_center.y - (inner_rect.h / 2),
        inner_rect.w,
        inner_rect.h,
    }
}

union_rect_i :: proc(r0, r1: Rect) -> Rect {
    // TODO: This seems kinda redundant. Optimize!
    bbox0 := rect_to_bbox(r0)
    bbox1 := rect_to_bbox(r1)
    return bbox_to_rect(BBox {
        x0=min(bbox0.x0, bbox1.x0),
        y0=min(bbox0.y0, bbox1.y0),
        x1=max(bbox0.x1, bbox1.x1),
        y1=max(bbox0.y1, bbox1.y1),
    })
}

union_rect_f :: proc(r0, r1: Rectf) -> Rectf {
    // TODO: This seems kinda redundant. Optimize!
    bbox0 := rect_to_bbox(r0)
    bbox1 := rect_to_bbox(r1)
    return bbox_to_rect(BBoxf {
        x0=min(bbox0.x0, bbox1.x0),
        y0=min(bbox0.y0, bbox1.y0),
        x1=max(bbox0.x1, bbox1.x1),
        y1=max(bbox0.y1, bbox1.y1),
    })
}

union_rect :: proc {
    union_rect_i, 
    union_rect_f,
}

Radix :: enum int {
    Binary = 2,
    Octal = 8,
    Decimal = 10,
    Hex = 16,
}

is_digit_in_radix :: proc(c: rune, radix: Radix) -> bool {
    result: bool
    switch radix {
    case .Binary:
        result = c == '0' || c == '1'
    case .Octal:
        result = c >= '0' && c <= '7'
    case .Decimal:
        result = c >= '0' && c <= '9'
    case .Hex:
        result = unicode.is_digit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
    }
    return result
}


wrap :: proc(x, y: $T) -> T
where intrinsics.type_is_integer(T), !intrinsics.type_is_array(T) 
{
    res := x % y
    return res + y if res < 0 else res
}

bit_modify :: proc(bits: []u8, bit_idx: uint, set: bool) {
    byte_idx := bit_idx / 8
    bit := bit_idx % 8
    if set {
        bits[byte_idx] |= (1 << bit)
    } else {
        bits[byte_idx] &= ~(1 << bit)
    }
}

bit_test :: proc(bits: []u8, bit_idx: uint) -> bool {
    byte_idx := bit_idx / 8
    bit := bit_idx % 8
    return (bits[byte_idx] & (1 << bit)) != 0
}

