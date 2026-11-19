// LZ-String's compressToBase64 and decompressFromBase64, the algorithm the
// Obsidian Excalidraw plugin stores drawings with. A port of lz-string 1.5.0
// (https://github.com/pieroxy/lz-string, MIT), checked bit for bit against the
// package in the tests. Strings are read as UTF-16 code units, as in JavaScript.

///|
const BASE64 : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="

///|
/// The index of a base 64 character. Anything else gives 0, which is what
/// lz-string's lookup of an unknown character amounts to.
fn base64_value(unit : Int32) -> Int32 {
  let mut i = 0
  while i < 65 {
    if BASE64[i].to_int() == unit {
      return i
    }
    i += 1
  }
  0
}

///|
/// Appends `count` low bits of `value` (lowest first) to the output.
priv struct BitWriter {
  out : StringBuilder
  mut value : Int32
  mut position : Int32
  bits_per_char : Int32
}

///|
fn BitWriter::push_bit(self : BitWriter, bit : Int32) -> Unit {
  self.value = (self.value << 1) | bit
  if self.position == self.bits_per_char - 1 {
    self.position = 0
    self.out.write_char(BASE64[self.value].to_int().unsafe_to_char())
    self.value = 0
  } else {
    self.position += 1
  }
}

///|
fn BitWriter::push_bits(self : BitWriter, value : Int32, count : Int32) -> Unit {
  let mut v = value
  for _ in 0..<count {
    self.push_bit(v & 1)
    v = v >> 1
  }
}

///|
/// `LZString.compressToBase64`.
pub fn compress_to_base64(input : String) -> String {
  let w = { out: StringBuilder(), value: 0, position: 0, bits_per_char: 6, }
  // Single characters seen so far, and those not yet written out in full.
  let chars : Map[Int32, Int32] = Map([])
  let unit_of : Map[Int32, Int32] = Map([])
  let to_create : @hashset.HashSet[Int32] = @hashset.HashSet([])
  // A longer string is the string `prefix` followed by one more unit.
  let pairs : Map[(Int32, Int32), Int32] = Map([])
  let mut dict_size = 3
  let mut enlarge_in = 2
  let mut num_bits = 2
  // The current string, as a dictionary number; -1 is the empty string.
  let mut cur = -1
  // Writes the code for the string `id`.
  fn emit(id : Int32) -> Unit {
    if to_create.contains(id) {
      let unit = unit_of[id]
      if unit < 256 {
        w.push_bits(0, num_bits)
        w.push_bits(unit, 8)
      } else {
        w.push_bits(1, num_bits)
        w.push_bits(unit, 16)
      }
      enlarge_in -= 1
      if enlarge_in == 0 {
        enlarge_in = 1 << num_bits
        num_bits += 1
      }
      to_create.remove(id)
    } else {
      w.push_bits(id, num_bits)
    }
    enlarge_in -= 1
    if enlarge_in == 0 {
      enlarge_in = 1 << num_bits
      num_bits += 1
    }
  }

  for i in 0..<input.length() {
    let c = input[i].to_int()
    let cid = match chars.get(c) {
      Some(id) => id
      None => {
        let id = dict_size
        dict_size += 1
        chars[c] = id
        unit_of[id] = c
        to_create.add(id)
        id
      }
    }
    if cur == -1 {
      cur = cid
    } else {
      match pairs.get((cur, c)) {
        Some(id) => cur = id
        None => {
          emit(cur)
          pairs[(cur, c)] = dict_size
          dict_size += 1
          cur = cid
        }
      }
    }
  }
  if cur != -1 {
    emit(cur)
  }
  // The end of the stream, then flush the last character.
  w.push_bits(2, num_bits)
  while true {
    w.value = w.value << 1
    if w.position == w.bits_per_char - 1 {
      w.out.write_char(BASE64[w.value].to_int().unsafe_to_char())
      break
    }
    w.position += 1
  }
  let res = w.out.to_string()
  match res.length() % 4 {
    1 => res + "==="
    2 => res + "=="
    3 => res + "="
    _ => res
  }
}

///|
/// One entry of the decompression dictionary: the entry it extends, its last
/// code unit, and its first code unit.
priv struct Entry {
  parent : Int32
  last : Int32
  first : Int32
}

///|
/// Appends the code units of entry `id` to `out`.
fn write_entry(entries : Array[Entry], id : Int32, out : Array[Int32]) -> Unit {
  let tail = []
  let mut i = id
  while i != -1 {
    tail.push(entries[i].last)
    i = entries[i].parent
  }
  let mut k = tail.length() - 1
  while k >= 0 {
    out.push(tail[k])
    k -= 1
  }
}

///|
/// Code units to a String; a surrogate pair becomes one character.
fn units_to_string(units : Array[Int32]) -> String {
  let out = StringBuilder()
  let mut i = 0
  while i < units.length() {
    let u = units[i]
    if u >= 0xD800 && u < 0xDC00 && i + 1 < units.length() {
      let low = units[i + 1]
      if low >= 0xDC00 && low < 0xE000 {
        out.write_char(
          (0x10000 + ((u - 0xD800) << 10) + (low - 0xDC00)).unsafe_to_char(),
        )
        i += 2
        continue
      }
    }
    out.write_char(u.unsafe_to_char())
    i += 1
  }
  out.to_string()
}

///|
/// `LZString.decompressFromBase64`. None where lz-string gives null: an empty
/// input or a stream that is not valid.
pub fn decompress_from_base64(input : String) -> String? {
  let length = input.length()
  if length == 0 {
    return None
  }
  let reset = 32
  // `data.val` and `data.position` of lz-string; reading past the end gives 0.
  let mut val = base64_value(input[0].to_int())
  let mut position = reset
  let mut index = 1
  fn read_bits(count : Int32) -> Int32 {
    let mut bits = 0
    let mut power = 1
    let max_power = 1 << count
    while power != max_power {
      let resb = val & position
      position = position >> 1
      if position == 0 {
        position = reset
        val = if index < length {
          base64_value(input[index].to_int())
        } else {
          0
        }
        index += 1
      }
      bits = bits | ((if resb > 0 { 1 } else { 0 }) * power)
      power = power << 1
    }
    bits
  }

  // Entries 0..2 are the control codes; 3 onwards are strings.
  let entries : Array[Entry] = [
    { parent: -1, last: 0, first: 0, },
    { parent: -1, last: 0, first: 0, },
    { parent: -1, last: 0, first: 0, },
  ]
  let mut enlarge_in = 4
  let mut num_bits = 3
  let out : Array[Int32] = []
  let first = match read_bits(2) {
    0 => read_bits(8)
    1 => read_bits(16)
    _ => return Some("")
  }
  entries.push({ parent: -1, last: first, first, })
  let mut w = 3
  out.push(first)
  while true {
    if index > length {
      return Some("")
    }
    let mut c = read_bits(num_bits)
    match c {
      0 | 1 => {
        let unit = read_bits(if c == 0 { 8 } else { 16 })
        entries.push({ parent: -1, last: unit, first: unit, })
        c = entries.length() - 1
        enlarge_in -= 1
      }
      2 => return Some(units_to_string(out))
      _ => ()
    }
    if enlarge_in == 0 {
      enlarge_in = 1 << num_bits
      num_bits += 1
    }
    let entry = if c < entries.length() {
      // The entry is known; the dictionary gains w plus its first unit.
      entries.push({
        parent: w,
        last: entries[c].first,
        first: entries[w].first,
      })
      c
    } else if c == entries.length() {
      // The entry being defined right now: w plus its own first unit. Adding
      // w plus the first unit of the entry is the same string.
      entries.push({
        parent: w,
        last: entries[w].first,
        first: entries[w].first,
      })
      c
    } else {
      return None
    }
    write_entry(entries, entry, out)
    enlarge_in -= 1
    w = entry
    if enlarge_in == 0 {
      enlarge_in = 1 << num_bits
      num_bits += 1
    }
  }
  None
}
