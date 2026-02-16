# Module 8: `lua/nvim-typer/stats.lua` — Calculation & Display

## Overview

The final module. It takes the raw state data from a completed typing test, crunches it into human-readable stats, and displays them in a floating results window.

## Key Concepts

### `calculate()` — The math

#### `vim.loop.hrtime()` — High-resolution timer

```lua
local elapsed_ns = (state.end_time or vim.loop.hrtime()) - (state.start_time or vim.loop.hrtime())
```

`vim.loop.hrtime()` returns nanoseconds from a monotonic clock — it always moves forward and isn't affected by system clock changes. We set `start_time` on first keypress and `end_time` when the test finishes.

The `or vim.loop.hrtime()` fallback handles edge cases: if the user somehow triggers `calculate()` without having started (both times would be "now," giving 0 elapsed).

#### WPM formula — The "5 characters = 1 word" standard

```lua
local gross_wpm = (#state.typed / 5) / math.max(elapsed_min, 0.01)
local net_wpm = (state.correct_keystrokes / 5) / math.max(elapsed_min, 0.01)
```

This is the universal typing test standard (used by MonkeyType, TypeRacer, etc.):

- Divide total characters by 5 to get "words"
- Divide by elapsed minutes to get words-per-minute
- **Gross WPM** counts all typed characters (including mistakes)
- **Net WPM** counts only correct characters

`math.max(elapsed_min, 0.01)` prevents division by zero if the test completes in under a millisecond.

#### Rounding pattern

```lua
math.floor(gross_wpm + 0.5)           -- round to nearest integer
math.floor(accuracy * 10 + 0.5) / 10  -- round to one decimal place
```

Lua doesn't have a built-in `round()`. This is the standard workaround:

- Adding 0.5 then flooring is equivalent to rounding to nearest integer
- Multiply by 10, round, divide by 10 gives one decimal place

### `display()` — The results window

#### Flow

1. Close the typing test window via `ui.close(state)`
2. Create a new floating window with formatted stats
3. Set up dismissal keymaps

#### `string.format` — Formatted output

```lua
string.format("  WPM (net):    %d", results.net_wpm)
string.format("  Accuracy:     %.1f%%", results.accuracy)
```

Lua's `string.format` works like C's `printf`:

- `%d` — integer
- `%.1f` — float with 1 decimal place
- `%%` — literal percent sign (escaped because `%` is special in format strings)

#### `vim.bo[buf].modifiable = false`

After setting the buffer content, we lock it. This prevents the user from accidentally editing the results. The buffer is read-only from this point on.

#### The `close()` closure pattern

```lua
local function close(close_win)
  return function()
    if vim.api.nvim_win_is_valid(close_win) then
      vim.api.nvim_win_close(close_win, true)
    end
  end
end

vim.keymap.set("n", "q", close(win), { buffer = buf })
vim.keymap.set("n", "<CR>", close(win), { buffer = buf })
```

`close()` is a **factory function** that returns a closure. The inner function "captures" `close_win` from the outer scope. This way, each keymap and autocmd gets its own function that knows which window to close.

The validity check prevents errors if the window was already closed by another path (e.g., user pressed `q` and `BufLeave` also fires).

#### Normal mode keymaps (not insert)

Notice these keymaps use `"n"` (normal mode), not `"i"` (insert mode). After the typing test ends and the results window opens, the user is back in normal mode. `q` and `<CR>` are natural dismissal keys in normal mode.

#### `BufLeave` with `once = true`

```lua
vim.api.nvim_create_autocmd("BufLeave", {
  buffer = buf,
  once = true,
  callback = close(win),
})
```

`once = true` means the autocmd fires at most one time, then automatically removes itself. This is a safety net — if the user navigates away from the results buffer (`:wincmd w`, for example) without pressing `q`, the window still closes. Without `once`, it would fire every time any buffer is left, which we don't want.

### Why always a float for results?

Regardless of whether the typing test used tab or float mode, results always display in a small centered float. This is a UX decision — a full tab for a few lines of stats feels excessive, and a float visually signals "this is a temporary overlay, press a key to dismiss."
