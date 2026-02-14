# Module 5: `lua/nvim-typer/ui.lua` — Window & State Management

## Overview

Creates either a new tab or floating window with a scratch buffer. The buffer is filled with **spaces** (not target text) — all visible text comes from overlay extmarks. Returns the `state` table that every other module operates on.

## Key Concepts

### Tab mode: `_open_tab()`

```lua
vim.cmd("tabnew")
local buf = vim.api.nvim_get_current_buf()
local win = vim.api.nvim_get_current_win()
```

`tabnew` creates a new tab with an empty buffer. Since it immediately becomes active, `get_current_buf()` and `get_current_win()` grab the **handles** — integer IDs that Neovim uses to reference buffers and windows across all `nvim_buf_*` / `nvim_win_*` APIs.

### Float mode: `_open_float()`

```lua
local buf = vim.api.nvim_create_buf(false, true)
```

Two args: `listed` and `scratch`. `false, true` means "unlisted scratch buffer" — won't show in `:ls`, has no file association. Perfect for temporary UI.

```lua
local win = vim.api.nvim_open_win(buf, true, { ... })
```

The second arg `true` means "enter the window immediately" (make it focused). The config table:

- **`relative = "editor"`** — Positioned relative to the entire editor, not a window or cursor
- **`width`/`height`** — Calculated as fractions of `vim.o.columns` and `vim.o.lines` (editor dimensions in cells)
- **`row`/`col`** — Centered with `(total - size) / 2`
- **`style = "minimal"`** — No line numbers, no statusline, no fold column
- **`title`/`title_pos`** — Rendered in the border (Neovim 0.9+)

### Buffer setup: `_setup_buffer()`

```lua
vim.bo[buf].buftype = "nofile"
vim.bo[buf].bufhidden = "wipe"
vim.bo[buf].swapfile = false
vim.bo[buf].filetype = "nvim-typer"
```

**`vim.bo[buf]`** is shorthand for buffer-local options:

- **`buftype = "nofile"`** — Not associated with any file. Prevents "save?" prompts and undo file creation
- **`bufhidden = "wipe"`** — When the buffer is no longer displayed, destroy it completely (free memory, fire `BufWipeout`)
- **`swapfile = false`** — No `.swp` file. Swap files are for crash recovery of real files
- **`filetype = "nvim-typer"`** — Custom filetype. Other plugins (e.g., statusline) can detect our buffer

### The space-filling trick

```lua
local empty_lines = {}
for i, line in ipairs(target_lines) do
  empty_lines[i] = string.rep(" ", #line)
end
vim.api.nvim_buf_set_lines(buf, 0, -1, false, empty_lines)
```

The buffer is filled with spaces matching target line lengths, not actual text. All visible text comes from extmark overlays. This avoids fighting with Neovim's text editing, undo history, and syntax highlighting.

### The state table

The central data structure passed to every module:

- **`ns`** — `nvim_create_namespace("nvim_typer")` returns a namespace ID. Namespaces scope extmarks so you can clear "our" marks without touching other plugins' marks
- **`target_flat`** — `table.concat(target_lines, "\n")` joins lines with newlines. A single `cursor_pos` integer tracks position across all lines
- **`cursor_pos = 0`** — 0-indexed into `target_flat`. Position 0 = first char of first line. `\n` characters in `target_flat` represent line breaks
- **`original_tab`** — Saved *before* creating the new tab, so `close()` can return the user to where they were

### `M.close()` — Teardown

```lua
if vim.api.nvim_buf_is_valid(state.buf) then
  vim.api.nvim_buf_delete(state.buf, { force = true })
end
```

The validity check prevents errors if the user manually closed the tab (buffer already gone). `force = true` skips "unsaved changes" prompts.
