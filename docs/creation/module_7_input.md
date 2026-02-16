# Module 7: `lua/nvim-typer/input.lua` — Keystroke Tracking

## Overview

This module captures every keypress during a typing test. It uses two different mechanisms: an **autocmd** for regular character input and **buffer-local keymaps** for special keys (`<CR>`, `<BS>`, `<Esc>`). Every keystroke updates the state, re-renders the affected line, and moves the cursor.

## Key Concepts

### Why `InsertCharPre`?

Neovim fires many events during editing, but `InsertCharPre` is special:

- Fires **exactly once** per character the user physically types
- Exposes `vim.v.char` — the actual character about to be inserted
- Lets you **suppress** the insertion by setting `vim.v.char = ""`
- Does NOT fire for special keys like Enter, Backspace, Escape

This is perfect for us. We want to intercept every printable character, record it, and prevent it from actually modifying the buffer (which is full of spaces we want to keep intact).

Other events we could have used and why they're worse:

- **`TextChangedI`** — Fires after text changes, not before. We'd have to undo the change. Also fires for pastes, autocomplete, etc.
- **`InsertEnter`/`InsertLeave`** — Only fire when entering/leaving insert mode, not per character
- **`CursorMovedI`** — Fires on cursor movement, not character input. Can fire from things like auto-pairs

### `vim.v.char = ""` — Suppressing insertion

```lua
local char = vim.v.char
vim.v.char = ""
```

`vim.v.char` is writable during `InsertCharPre`. Setting it to `""` tells Neovim "don't actually insert anything into the buffer." The character is captured in our `char` variable but the buffer stays as spaces. This is the key trick that lets extmarks handle all visual output.

### `vim.schedule()` — Escaping textlock

```lua
vim.schedule(function()
  M._update_and_move(state)
end)
```

During `InsertCharPre`, Neovim is in a **textlock** — a state where certain API calls (like `nvim_win_set_cursor`, `nvim_buf_set_extmark`) are forbidden because Neovim is in the middle of processing input. If you call them directly, you get an error like `E565: Not allowed to change text or change window`.

`vim.schedule()` defers the function to the next event loop iteration, after the textlock is released. It's like `setTimeout(fn, 0)` in JavaScript — "run this as soon as you're free." This is a very common pattern in Neovim plugin development.

### Buffer-local keymaps vs autocmds

For regular characters (a-z, 0-9, symbols), `InsertCharPre` works great. But it **doesn't fire** for special keys. So we use buffer-local keymaps for those:

```lua
vim.keymap.set("i", "<CR>", function() ... end, { buffer = state.buf })
vim.keymap.set("i", "<BS>", function() ... end, { buffer = state.buf })
vim.keymap.set("i", "<Esc>", function() ... end, { buffer = state.buf })
```

`vim.keymap.set` arguments:

1. **`"i"`** — Insert mode only. These keymaps only apply when the user is in insert mode
2. **`"<CR>"`** — The key to intercept. `<CR>` = Enter, `<BS>` = Backspace, `<Esc>` = Escape
3. **`function() ... end`** — The handler. Replaces the default behavior entirely
4. **`{ buffer = state.buf }`** — **Buffer-local**. This keymap only exists in our typing test buffer. It won't affect any other buffer. When the buffer is wiped, the keymap is automatically cleaned up

Without `buffer = state.buf`, the keymap would be global — pressing Enter in any buffer would run our handler.

### Enter key — the newline boundary

```lua
local expected = state.target_flat:sub(state.cursor_pos + 1, state.cursor_pos + 1)
if expected ~= "\n" then
  return
end
```

In `target_flat`, line breaks are literal `\n` characters. When the cursor is at a `\n` position, only Enter should advance — regular characters are ignored by the `InsertCharPre` handler (which checks `if expected == "\n" then return end`). This ensures the user must explicitly press Enter to move to the next line.

Enter re-renders **two lines** — the line being completed and the next line the cursor moves to:

```lua
local prev_line = renderer.pos_to_line(state, state.cursor_pos - 1)
local curr_line = renderer.pos_to_line(state, state.cursor_pos)
renderer.update_line(state, prev_line)
if curr_line ~= prev_line then
  renderer.update_line(state, curr_line)
end
```

### Backspace — undo last character

```lua
state.cursor_pos = state.cursor_pos - 1
table.remove(state.typed)
```

`table.remove` with no index removes the last element (like `Array.pop()` in JavaScript). The cursor moves back one position, and we re-render. Note backspace does NOT decrement `total_keystrokes` or `correct_keystrokes` — those only count forward progress. This matches MonkeyType's behavior.

Backspace also handles the two-line case (backspacing from the start of a line back to the previous line).

### Escape — quit early

Sets `end_time`, marks `finished = true`, and calls `stop()` via `vim.schedule`. The `require("nvim-typer").stop(state)` call goes through the orchestrator, which detaches input, calculates stats, and displays results.

### `BufWipeout` autocmd — safety net

```lua
vim.api.nvim_create_autocmd("BufWipeout", {
  buffer = state.buf,
  callback = function() ... end,
})
```

If the user closes the tab/window externally (`:q`, `:bd`, etc.), the buffer gets wiped and this fires. It marks the test as finished and cleans up autocmds. Without this, our `InsertCharPre` autocmd would error on the next keystroke because it references a deleted buffer.

### `detach()` — Cleanup

```lua
for _, id in ipairs(state.autocmd_ids) do
  pcall(vim.api.nvim_del_autocmd, id)
end
```

`pcall` (protected call) wraps each deletion — if an autocmd was already removed (e.g., buffer was wiped), it silently fails instead of erroring. Buffer-local keymaps don't need manual cleanup; they're destroyed automatically when the buffer is wiped.

### `_move_cursor()` — Keeping the cursor in sync

```lua
local line = renderer.pos_to_line(state, state.cursor_pos)
local col = renderer.pos_to_col(state, state.cursor_pos)
vim.api.nvim_win_set_cursor(state.win, { line + 1, col })
```

Converts the flat `cursor_pos` to `(line, col)` using the renderer's helpers, then positions the Neovim cursor. `nvim_win_set_cursor` takes **1-indexed line** and **0-indexed column**, which is why we do `line + 1` but not `col + 1`.

### `_check_finished()` — Detecting completion

```lua
if state.cursor_pos >= #state.target_flat then
```

When the cursor has advanced past every character in the target text, the test is complete. Sets `end_time` and calls `stop()` to show results.
