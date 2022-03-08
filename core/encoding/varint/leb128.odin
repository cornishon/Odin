/*
	Copyright 2022 Jeroen van Rijn <nom@duclavier.com>.
	Made available under Odin's BSD-3 license.

	List of contributors:
		Jeroen van Rijn: Initial implementation.
*/

// package varint implements variable length integer encoding and decoding using
// the LEB128 format as used by DWARF debug info, Android .dex and other file formats.
package varint

// In theory we should use the bigint package. In practice, varints bigger than this indicate a corrupted file.
// Instead we'll set limits on the values we'll encode/decode
// 18 * 7 bits = 126, which means that a possible 19th byte may at most be `0b0000_0011`.
LEB128_MAX_BYTES    :: 19

Error :: enum {
	None             = 0,
	Buffer_Too_Small = 1,
	Value_Too_Large  = 2,
}

// Decode a slice of bytes encoding an unsigned LEB128 integer into value and number of bytes used.
// Returns `size` == 0 for an invalid value, empty slice, or a varint > 18 bytes.
decode_uleb128 :: proc(buf: []u8) -> (val: u128, size: int, err: Error) {
	more := true

	for v, i in buf {
		size = i + 1

		if size == LEB128_MAX_BYTES && v > 0b0000_0011 {
			return 0, 0, .Value_Too_Large
		}

		val |= u128(v & 0x7f) << uint(i * 7)

		if v < 128 {
			more = false
			break
		}
	}

	// If the buffer runs out before the number ends, return an error.
	if more {
		return 0, 0, .Buffer_Too_Small
	}
	return
}

// Decode a slice of bytes encoding a signed LEB128 integer into value and number of bytes used.
// Returns `size` == 0 for an invalid value, empty slice, or a varint > 18 bytes.
decode_ileb128 :: proc(buf: []u8) -> (val: i128, size: int, err: Error) {
	shift: uint

	if len(buf) == 0 {
		return 0, 0, .Buffer_Too_Small
	}

	for v in buf {
		size += 1

		// 18 * 7 bits = 126, which means that a possible 19th byte may at most be 0b0000_0011.
		if size == LEB128_MAX_BYTES && v > 0b0000_0011 {
			return 0, 0, .Value_Too_Large
		}

		val |= i128(v & 0x7f) << shift
		shift += 7

		if v < 128 { break }
	}

	if buf[size - 1] & 0x40 == 0x40 {
		val |= max(i128) << shift
	}
	return
}

// Encode `val` into `buf` as an unsigned LEB128 encoded series of bytes.
// `buf` must be appropriately sized.
encode_uleb128 :: proc(buf: []u8, val: u128) -> (size: int, err: Error) {
	val := val

	for {
		size += 1

		if size > len(buf) {
			return 0, .Buffer_Too_Small
		}

		low := val & 0x7f
		val >>= 7

		if val > 0 {
			low |= 0x80 // more bytes to follow
		}
		buf[size - 1] = u8(low)

		if val == 0 { break }
	}
	return
}

@(private)
SIGN_MASK :: (i128(1) << 121) // sign extend mask

// Encode `val` into `buf` as a signed LEB128 encoded series of bytes.
// `buf` must be appropriately sized.
encode_ileb128 :: proc(buf: []u8, val: i128) -> (size: int, err: Error) {
	val      := val
	more     := true

	for more {
		size += 1

		if size > len(buf) {
			return 0, .Buffer_Too_Small
		}

		low := val & 0x7f
		val >>= 7

		low = (low ~ SIGN_MASK) - SIGN_MASK

		if (val == 0 && low & 0x40 != 0x40) || (val == -1 && low & 0x40 == 0x40) {
			more = false
		} else {
			low |= 0x80
		}

		buf[size - 1] = u8(low)
	}
	return
}