# nvim-typer

A MonkeyType-style typing test plugin for Neovim. Takes your current buffer content (or visual selection) and lets you practice typing it — tracking WPM, accuracy, and time.

## Features

- Use any buffer content or visual selection as typing test material
- Real-time feedback: correct characters turn green, mistakes turn red, untyped text stays dimmed
- Timer starts on first keypress (no countdown pressure)
- Results screen with net WPM, gross WPM, accuracy, and elapsed time
- Opens in a new tab by default (floating window optional)

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  dir = "~/Developer/nvim-typer",  -- or use a git URL once published
  cmd = "TypeTest",
  opts = {},
}
```

Or manually add to runtimepath:

```vim
set rtp+=~/Developer/nvim-typer
```

## Usage

```vim
" Test against entire current buffer
:TypeTest

" Test against visual selection
:'<,'>TypeTest
```

### Controls

| Key     | Action                                    |
|---------|-------------------------------------------|
| Any key | Starts the timer (on first keypress)      |
| `<BS>`  | Delete last typed character               |
| `<CR>`  | Advance through newlines in multi-line text |
| `<Esc>` | Quit early and show stats                 |

### Results Screen

After completing the test (or pressing `<Esc>`), a floating results window shows:
- **Net WPM** — only correctly typed characters count
- **Gross WPM** — all typed characters count
- **Accuracy** — correct keystrokes / total forward keystrokes
- **Time** — elapsed seconds

Press `q` or `<CR>` to dismiss and return to your original tab.

## Configuration

```lua
require("nvim-typer").setup({
  window = {
    style = "tab",         -- "tab" (default) or "float"
    width = 0.6,           -- fraction of editor width (float only)
    height = 0.4,          -- fraction of editor height (float only)
    border = "rounded",    -- border style (float only)
  },
  highlights = {
    dimmed    = { fg = "#555555" },
    correct   = { fg = "#a6e3a1" },
    incorrect = { fg = "#f38ba8", undercurl = true },
  },
})
```

---

# Implementation Plan

Everything below is the technical design spec for building this plugin. It should be sufficient to implement from scratch with minimal additional guidance.

## File Structure

```
nvim-typer/
  plugin/nvim-typer.lua           -- :TypeTest command registration (range=true)
  lua/nvim-typer/
    init.lua                      -- Public API: setup(), start(), stop()
    config.lua                    -- Default config + merge
    highlight.lua                 -- Highlight group definitions
    ui.lua                        -- Tab/float window + state table creation
    renderer.lua                  -- Extmark overlay rendering (dimmed/correct/incorrect)
    input.lua                     -- Keystroke tracking (InsertCharPre + keymaps)
    stats.lua                     -- WPM/accuracy calculation + results display
```

## Module Details

### `plugin/nvim-typer.lua` — Command Registration

Single responsibility: register the `:TypeTest` user command.

```lua
vim.api.nvim_create_user_command("TypeTest", function(opts)
  require("nvim-typer").start(opts)
end, { range = true, desc = "Start a typing test from buffer content or visual selection" })
```

- `range = true` makes Neovim pass `opts.range` (0 = no range, 2 = visual range) plus `opts.line1` / `opts.line2` (1-indexed).

### `lua/nvim-typer/config.lua` — Configuration

```lua
local M = {}

M.defaults = {
  window = {
    style = "tab",         -- "tab" or "float"
    width = 0.6,           -- float only
    height = 0.4,          -- float only
    border = "rounded",    -- float only
  },
  highlights = {
    dimmed    = { fg = "#555555" },
    correct   = { fg = "#a6e3a1" },
    incorrect = { fg = "#f38ba8", undercurl = true },
  },
}

M.options = vim.deepcopy(M.defaults)

function M.merge(user_opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, user_opts or {})
end

return M
```

### `lua/nvim-typer/highlight.lua` — Highlight Groups

Creates named highlight groups referenced by extmarks.

```lua
local M = {}

function M.setup(opts)
  vim.api.nvim_set_hl(0, "NvimTyperDimmed", opts.highlights.dimmed)
  vim.api.nvim_set_hl(0, "NvimTyperCorrect", opts.highlights.correct)
  vim.api.nvim_set_hl(0, "NvimTyperIncorrect", opts.highlights.incorrect)
end

return M
```

### `lua/nvim-typer/init.lua` — Public API / Orchestrator

```lua
local config = require("nvim-typer.config")
local ui = require("nvim-typer.ui")
local renderer = require("nvim-typer.renderer")
local input = require("nvim-typer.input")
local highlight = require("nvim-typer.highlight")

local M = {}

function M.setup(opts)
  config.merge(opts)
  highlight.setup(config.options)
end

function M.start(cmd_opts)
  -- 1. Extract source text
  local lines = M._get_source_lines(cmd_opts)
  if #lines == 0 or (#lines == 1 and lines[1] == "") then
    vim.notify("nvim-typer: No text to test", vim.log.levels.WARN)
    return
  end

  -- 2. Create UI (tab or float) — returns state table
  local state = ui.open(config.options, lines)

  -- 3. Render dimmed target text via extmarks
  renderer.render_target(state)

  -- 4. Attach input handlers
  input.attach(state)
end

function M.stop(state)
  input.detach(state)
  local results = require("nvim-typer.stats").calculate(state)
  require("nvim-typer.stats").display(results, state)
end

function M._get_source_lines(cmd_opts)
  local buf = vim.api.nvim_get_current_buf()
  if cmd_opts.range == 2 then
    return vim.api.nvim_buf_get_lines(buf, cmd_opts.line1 - 1, cmd_opts.line2, false)
  else
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end
end

return M
```

### `lua/nvim-typer/ui.lua` — Window & State Management

Creates either a new tab or floating window with a scratch buffer. The buffer is filled with **spaces** (not target text) — all visible text comes from overlay extmarks.

**Tab mode:**
```lua
vim.cmd("tabnew")
local buf = vim.api.nvim_get_current_buf()
local win = vim.api.nvim_get_current_win()
```

**Float mode:**
```lua
local buf = vim.api.nvim_create_buf(false, true)
local win = vim.api.nvim_open_win(buf, true, {
  relative = "editor",
  width = win_w, height = win_h,
  row = row, col = col,
  border = opts.window.border,
  title = " nvim-typer ", title_pos = "center",
  style = "minimal",
})
```

**Buffer setup (both modes):**
```lua
vim.bo[buf].buftype = "nofile"
vim.bo[buf].bufhidden = "wipe"
vim.bo[buf].swapfile = false
vim.bo[buf].filetype = "nvim-typer"

-- Fill with spaces matching target line lengths
local empty_lines = {}
for i, line in ipairs(target_lines) do
  empty_lines[i] = string.rep(" ", #line)
end
vim.api.nvim_buf_set_lines(buf, 0, -1, false, empty_lines)
```

**State table returned:**
```lua
{
  buf = buf,
  win = win,
  ns = vim.api.nvim_create_namespace("nvim_typer"),
  target_lines = target_lines,
  target_flat = table.concat(target_lines, "\n"),  -- flattened with newlines
  typed = {},              -- list of typed characters in order
  cursor_pos = 0,          -- 0-indexed position in target_flat
  start_time = nil,        -- set on first keypress via vim.loop.hrtime()
  end_time = nil,
  total_keystrokes = 0,
  correct_keystrokes = 0,
  finished = false,
  autocmd_ids = {},        -- for cleanup
  original_tab = vim.api.nvim_get_current_tabpage(),  -- to return to after
}
```

After creating the buffer, enter insert mode and place cursor at (1, 0):
```lua
vim.cmd("startinsert")
vim.api.nvim_win_set_cursor(win, { 1, 0 })
```

**`ui.close(state)`** — closes the tab/float and returns to the original tab.

### `lua/nvim-typer/renderer.lua` — Extmark Overlay Engine

This is the visual core. All text the user sees comes from overlay extmarks.

**Initial render — all dimmed:**
```lua
function M.render_target(state)
  for i, line in ipairs(state.target_lines) do
    if #line > 0 then
      vim.api.nvim_buf_set_extmark(state.buf, state.ns, i - 1, 0, {
        virt_text = { { line, "NvimTyperDimmed" } },
        virt_text_pos = "overlay",
        hl_mode = "combine",
      })
    end
  end
end
```

**Per-keystroke update — rebuild one line:**
```lua
function M.update_line(state, line_idx)
  -- 1. Clear existing extmarks on this line
  -- 2. Get the target line text
  -- 3. Determine how many chars on this line have been typed (from cursor_pos)
  -- 4. Build chunks array:
  --    - For each typed char: compare to target char
  --      - Match:    { typed_char, "NvimTyperCorrect" }
  --      - Mismatch: { typed_char, "NvimTyperIncorrect" }
  --    - For each untyped char: { target_char, "NvimTyperDimmed" }
  -- 5. Set one extmark with virt_text = chunks, virt_text_pos = "overlay"
end
```

**Key concept — mapping `cursor_pos` to `(line, col)`:**
- `target_flat` is the target text joined with `\n`
- `cursor_pos` is a 0-indexed offset into `target_flat`
- To find which line: iterate `target_lines`, accumulating `#line + 1` (for `\n`) until `cursor_pos` falls within a line's range
- Column within that line: `cursor_pos - accumulated_offset`

Helper functions needed:
- `_pos_to_line(state, pos)` — returns 0-indexed line number
- `_pos_to_col(state, pos)` — returns 0-indexed column within that line
- `_typed_col_for_line(state, line_idx)` — how many chars of this line have been typed
- `_get_typed_char(state, line_idx, col)` — what char was typed at this position

### `lua/nvim-typer/input.lua` — Keystroke Tracking

**Why `InsertCharPre`:** Fires exactly once per user-typed character, exposes `vim.v.char`, and allows suppressing insertion by setting `vim.v.char = ""`. The buffer stays as spaces; all visual output is extmark-driven. This avoids fighting with undo history or buffer change callbacks.

**Character input (`InsertCharPre` autocmd):**
1. On first keypress, set `state.start_time = vim.loop.hrtime()`
2. Read `vim.v.char` — the character the user typed
3. Compare to `state.target_flat:sub(cursor_pos + 1, cursor_pos + 1)`
4. Record in `state.typed`, increment `cursor_pos`, update keystroke counts
5. Set `vim.v.char = ""` to prevent actual buffer insertion
6. `vim.schedule()` to re-render current line and move cursor (avoids textlock)
7. If `cursor_pos >= #target_flat`, mark finished and call `stop()`

**Enter key (`<CR>` buffer-local keymap):**
- Same logic as character input, but the "expected" character is `\n`
- Must re-render both the current line and the next line
- Moves cursor to start of next line

**Backspace (`<BS>` buffer-local keymap):**
- Decrement `cursor_pos`, remove last from `state.typed`
- Counts as a keystroke but NOT as correct
- Re-render the affected line, move cursor back

**Escape (`<Esc>` buffer-local keymap):**
- Set `end_time`, mark `finished = true`, call `stop()`

**Cleanup (`BufWipeout` autocmd):**
- Delete all autocmds in `state.autocmd_ids`
- Buffer-local keymaps are cleaned up automatically when buffer is wiped

**Cursor movement — `_move_cursor(state)`:**
- Convert `cursor_pos` to `(line, col)` using the line length accumulation
- Call `vim.api.nvim_win_set_cursor(state.win, { line + 1, col })` (1-indexed line)

### `lua/nvim-typer/stats.lua` — Calculation & Display

**Calculation:**
```lua
function M.calculate(state)
  local elapsed_ns = (state.end_time or vim.loop.hrtime()) - (state.start_time or vim.loop.hrtime())
  local elapsed_sec = elapsed_ns / 1e9
  local elapsed_min = elapsed_sec / 60

  -- Standard MonkeyType formula: (characters / 5) / minutes
  -- "5 characters = 1 word" is the universal typing test standard
  local gross_wpm = (#state.typed / 5) / math.max(elapsed_min, 0.01)
  local net_wpm = (state.correct_keystrokes / 5) / math.max(elapsed_min, 0.01)

  local accuracy = #state.typed > 0
    and (state.correct_keystrokes / #state.typed * 100)
    or 0

  return {
    gross_wpm = math.floor(gross_wpm + 0.5),
    net_wpm = math.floor(net_wpm + 0.5),
    accuracy = math.floor(accuracy * 10 + 0.5) / 10,
    elapsed_sec = math.floor(elapsed_sec * 10 + 0.5) / 10,
    total_chars = #state.target_flat,
    typed_chars = #state.typed,
    correct_chars = state.correct_keystrokes,
  }
end
```

**Display:**
- Close the typing tab/window first via `ui.close(state)`
- Open a small centered floating window (always float for results, regardless of typing window style)
- Show formatted stats lines
- Buffer-local keymaps: `q` and `<CR>` close the results window
- `BufLeave` autocmd as fallback cleanup

**Results format:**
```
  nvim-typer Results
  --------------------
  WPM (net):    62
  WPM (gross):  68
  Accuracy:     91.2%
  Time:         45.3s
  Characters:   187 / 210

  Press q or <Enter> to close
```

## Edge Cases

| Scenario | Handling |
|---|---|
| Empty buffer / selection | `vim.notify` warning, no window opened |
| Trailing whitespace in source | Preserved in target; user must type it |
| User types past end of line without Enter | Clamped; extra chars ignored |
| Multiple `:TypeTest` calls | Guard in `start()` — stop any active test first |
| Buffer closed externally | `BufWipeout` autocmd handles cleanup |
| Single-line text | Works fine; no newlines in `target_flat` |

## Verification Steps

1. Add to runtimepath: `set rtp+=~/Developer/nvim-typer` (or use lazy.nvim `dir` option)
2. Open any file with text, run `:TypeTest` — new tab should open with dimmed text
3. Type characters — correct ones turn green, incorrect ones turn red
4. Press `<BS>` — should undo last character, re-dim it
5. Press `<Esc>` — should show stats float
6. Test with visual selection: select some lines, run `:'<,'>TypeTest`
7. Type to completion — stats should auto-display when all characters are typed
