# Module 6: `lua/nvim-typer/renderer.lua` — Extmark Overlay Engine

## Overview

This is the visual core of the plugin. The buffer contains only spaces — **everything the user sees** comes from extmark overlays. This module handles both the initial "all dimmed" render and per-keystroke updates that paint characters green, red, or gray.

## Key Concepts

### What are extmarks?

Extmarks are Neovim's mechanism for attaching metadata to buffer positions. They can:
- Track positions as text changes (they "stick" to their location)
- Display virtual text (text that isn't actually in the buffer)
- Apply highlights to real buffer text

We use them for **virtual text overlays** — text drawn on top of the buffer content (our spaces) at exact positions.

### `render_target()` — Initial render

```lua
vim.api.nvim_buf_set_extmark(state.buf, state.ns, i - 1, 0, {
  virt_text = { { line, "NvimTyperDimmed" } },
  virt_text_pos = "overlay",
  hl_mode = "combine",
})
```

`nvim_buf_set_extmark` arguments:

1. **`state.buf`** — Which buffer to place the mark in
2. **`state.ns`** — Namespace ID (from `nvim_create_namespace`). Scopes this mark so we can later clear all our marks without affecting other plugins
3. **`i - 1`** — Row (0-indexed line number)
4. **`0`** — Column (start of line)
5. **Options table** — The interesting part:

   - **`virt_text`** — An array of `{text, highlight_group}` tuples called "chunks." Each chunk is a piece of text with a highlight applied. Multiple chunks render side by side:
     ```lua
     { { "he", "NvimTyperCorrect" }, { "llo", "NvimTyperDimmed" } }
     -- renders: "he" in green, "llo" in gray
     ```

   - **`virt_text_pos = "overlay"`** — This is critical. It means "draw this text **on top of** the actual buffer content at this position." The spaces in our buffer are hidden behind the virtual text. Other options like `"eol"` (end of line) or `"inline"` behave very differently.

   - **`hl_mode = "combine"`** — How to blend the virtual text highlight with any existing highlights. `"combine"` merges them (e.g., if the buffer had a background color, it would show through). `"replace"` would fully override.

### `update_line()` — Per-keystroke re-render

Called every time the user types a character. It rebuilds the chunks for a single line:

1. **Clear existing marks** on that line using `nvim_buf_get_extmarks` + `nvim_buf_del_extmark`
2. **Calculate how many chars** on this line have been typed (using `cursor_pos` and line offsets)
3. **Build chunks array:**
   - Typed chars that match target → `{ char, "NvimTyperCorrect" }` (green)
   - Typed chars that don't match → `{ char, "NvimTyperIncorrect" }` (red)
   - Untyped chars → `{ remaining_text, "NvimTyperDimmed" }` (gray)
4. **Set one extmark** with the full chunks array

The remaining untyped characters are batched into a single chunk for efficiency — no need to create individual extmarks for each untyped character.

### Clearing extmarks on a line

```lua
local marks = vim.api.nvim_buf_get_extmarks(
  state.buf, state.ns,
  { line_idx, 0 }, { line_idx, -1 },
  {}
)
for _, mark in ipairs(marks) do
  vim.api.nvim_buf_del_extmark(state.buf, state.ns, mark[1])
end
```

`nvim_buf_get_extmarks` takes a range: `{ line, col_start }` to `{ line, col_end }`. Using `-1` for `col_end` means "end of line." Each returned mark is `{ id, row, col }` — we use `mark[1]` (the ID) to delete it. The namespace ensures we only see and delete our own marks.

## Position Mapping: `cursor_pos` ↔ `(line, col)`

The `state.cursor_pos` is a single 0-indexed integer into `target_flat` (all lines joined by `\n`). We need helpers to convert between this flat position and line/column coordinates.

### Example

Target lines: `{ "hello", "world" }`
Target flat: `"hello\nworld"` (length 11)

```
Position:  0 1 2 3 4 5 6 7 8 9 10
Character: h e l l o \n w o r l d
Line:      0 0 0 0 0  - 1 1 1 1 1
Column:    0 1 2 3 4  - 0 1 2 3 4
```

### `_line_start_offset(state, line_idx)`

Returns where a given line begins in `target_flat`. Accumulates `#line + 1` for each prior line (the `+1` accounts for the `\n` separator).

- Line 0 starts at offset 0
- Line 1 starts at offset 6 (`#"hello" + 1`)

### `pos_to_line(state, pos)`

Iterates through lines, accumulating offsets until `pos` falls within a line's range. Returns the 0-indexed line number.

### `pos_to_col(state, pos)`

Subtracts the line's start offset from `pos` to get the column within that line.

## Why rebuild the whole line?

We could try to update individual characters, but extmarks with `virt_text_pos = "overlay"` replace the **entire visual content** at their position. A single extmark with multiple chunks is cleaner and avoids z-ordering issues from overlapping marks. One extmark per line keeps things simple and predictable.
