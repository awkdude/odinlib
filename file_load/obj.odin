package file_load

import "core:os"
import "core:mem"
import "core:log"
import "core:strconv"
import "core:strings"
import "base:runtime"
import "base:intrinsics"
import "../util"

// Set true to log
when true { 
    obj_debug :: log.debug
} else {
    obj_debug :: proc(_: ..any, sep := "", location := #caller_location) {}
}

OBJ_Vertex :: struct {
    position, normal: util.vec3f,
    tex_coords: util.vec2f,
}

OBJ_Mesh :: struct {
    vertices: [dynamic]OBJ_Vertex,
    indices: [dynamic]u32,
    // textures: [dynamic; 8]Texture,
}

OBJ_Model :: struct {
    meshes: [dynamic]OBJ_Mesh,
}

Scanner :: struct {
    start, end, pointer: [^]u8,
    line, column: int,
}

scanner_init :: proc "contextless"(s: ^Scanner, source: string) {
    s.start = raw_data(source)
    s.end = mem.ptr_offset(s.start, len(source))
    s.pointer = s.start
    s.line = 1
    s.column = 1
}

Lexeme :: struct {
    str: string,
    line, column: int,
}

char_is_whitespace :: proc "contextless" (c: rune) -> bool {
    switch c {
    case ' ', '\t', '\n', '\r':
        return true
    }
    return false
}

scanner_next_word :: proc "contextless"(s: ^Scanner) -> (Lexeme, bool) {
    if s.pointer < s.start || s.pointer >= s.end {
        return {}, false
    }
    for c in scanner_peek_char(s) {
        if !char_is_whitespace(c) {
            break
        }
        scanner_advance_char(s)
    }
    lex_start := s.pointer
    lexeme := Lexeme{
        line=s.line,
        column=s.column,
    }
    for c in scanner_peek_char(s) {
        if char_is_whitespace(c) {
            break
        }
        scanner_advance_char(s)
    }
    lex_end := s.pointer
    lexeme.str = transmute(string)runtime.Raw_String{data=lex_start, len=mem.ptr_sub(lex_end, lex_start)}

    return lexeme, len(lexeme.str) > 0
}

scanner_peek_char :: proc "contextless"(s: ^Scanner) -> (rune, bool) {
    if s.pointer < s.start || s.pointer >= s.end {
        return 0, false
    }
    return cast(rune)s.pointer[0], true 
}

scanner_advance_char :: proc "contextless"(s: ^Scanner) -> (rune, bool) {
    if s.pointer < s.start || s.pointer >= s.end {
        return 0, false
    }
    c := s.pointer[0]
    s.column += 1
    if c == '\n' {
        s.line += 1
        s.column = 1
    }
    s.pointer = &s.pointer[1]
    return cast(rune)c, true
}

scanner_goto_next_line :: proc "contextless" (s: ^Scanner) -> bool {
    for {
        c, ok := scanner_advance_char(s) 
        if !ok do return false
        if c == '\n' do break
    }
    return true
}

string_split_into_buf :: proc(str, sep: string, slice_buf: []string) -> []string 
{
    slice_idx := 0
    start := 0
    for pointer := 0; pointer < len(str); {
        if strings.starts_with(str[pointer:], sep) {
            slice_buf[slice_idx] = str[start:pointer]
            slice_idx += 1
            if slice_idx >= len(slice_buf) {
                break
            }
            pointer += len(sep)
            start = pointer
        } else {
            pointer += 1
        }
    }
    if slice_idx < len(slice_buf) {
        slice_buf[slice_idx] = str[start:]
    }
    return slice_buf
}

load_obj :: proc(path: string, allocator := context.allocator) -> (OBJ_Mesh, bool) {
    data, file_err := os.read_entire_file_from_path(path, allocator)
    if file_err != nil {
        return {}, false
    }
    defer delete(data)
    scanner: Scanner
    scanner_init(&scanner, cast(string)data)
    positions: [dynamic]util.vec3f
    defer delete(positions)
    normals: [dynamic]util.vec3f
    defer delete(normals)
    uvs: [dynamic]util.vec2f
    defer delete(uvs)
    vertices: [dynamic]OBJ_Vertex
    for {
        if first_char := scanner_peek_char(&scanner) or_break; first_char == '#' {
            scanner_goto_next_line(&scanner)
            continue
        }
        command := scanner_next_word(&scanner) or_break
        switch command.str {
        case "mtllib":
            log.debug("material path:", scanner_next_word(&scanner) or_break)
        case "o":
            log.debug("object name:", scanner_next_word(&scanner) or_break)
        case "v":
            lex: Lexeme
            lex = scanner_next_word(&scanner) or_break
            x := strconv.parse_f32(lex.str) or_break
            lex = scanner_next_word(&scanner) or_break
            y := strconv.parse_f32(lex.str) or_break
            lex = scanner_next_word(&scanner) or_break
            z := strconv.parse_f32(lex.str) or_break
            v := util.vec3f{x, y, z}
            append(&positions, v)
            log.debug("Vertex:", v)
        case "vn":
            lex: Lexeme
            lex = scanner_next_word(&scanner) or_break
            x := strconv.parse_f32(lex.str) or_break
            lex = scanner_next_word(&scanner) or_break
            y := strconv.parse_f32(lex.str) or_break
            lex = scanner_next_word(&scanner) or_break
            z := strconv.parse_f32(lex.str) or_break
            n := util.vec3f{x, y, z}
            append(&normals, n)
            log.debug("Normal:", n)
        case "vt":
            lex: Lexeme
            lex = scanner_next_word(&scanner) or_break
            x := strconv.parse_f32(lex.str) or_break
            lex = scanner_next_word(&scanner) or_break
            y := strconv.parse_f32(lex.str) or_break
            // lex = scanner_next_word(&scanner) or_break
            // z := strconv.parse_f32(lex.str) or_break
            uv := util.vec2f{x, y}
            append(&uvs, uv)
            log.debug("Tex coord:", uv)
        case "f":
            buf: [4]string
            for _ in 0..<4 {
                v0 := scanner_next_word(&scanner) or_break
                refs0 := string_split_into_buf(v0.str, "/", buf[:])
                pos_idx := strconv.parse_int(refs0[0]) or_break
                uv_idx := strconv.parse_int(refs0[1]) or_break
                norm_idx := strconv.parse_int(refs0[2]) or_break
                append(
                    &vertices,
                    OBJ_Vertex{
                        position=positions[pos_idx-1],
                        tex_coords=uvs[uv_idx-1],
                        normal=normals[norm_idx-1],
                    }
                )
            }

            // v1 := scanner_next_word(&scanner) or_break
            // refs1 := string_split_into_buf(v0.str, "/", buf[:])
            // v2 := scanner_next_word(&scanner) or_break
            // refs2 := string_split_into_buf(v0.str, "/", buf[:])
            // v3 := scanner_next_word(&scanner) or_break
            // refs3 := string_split_into_buf(v0.str, "/", buf[:])

        }
        
    }
    log.debug("Num vertices:", len(vertices))
    return OBJ_Mesh{vertices=vertices}, true

}
