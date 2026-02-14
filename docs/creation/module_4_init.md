# Module 4: `lua/nvim-typer/init.lua` — Public API / Orchestrator

## File

```lua
local config = require("nvim-typer.config")
local highlight = require("nvim-typer.highlight")

local M = {}

---@param opts? NvimTyperOpts
function M.setup(opts)
  config.merge(opts)
  highlight.setup(config.options)
end

---@param cmd_opts NvimTyperCmdOpts
function M.start(cmd_opts)
  local lines = M._get_source_lines(cmd_opts)
  if #lines == 0 or (#lines == 1 and lines[1] == "") then
    vim.notify("nvim-typer: No text to test", vim.log.levels.WARN)
    return
  end

  local ui = require("nvim-typer.ui")
  local renderer = require("nvim-typer.renderer")
  local input = require("nvim-typer.input")

  local state = ui.open(config.options, lines)
  renderer.render_target(state)
  input.attach(state)
end

---@param state NvimTyperState
function M.stop(state)
  local input = require("nvim-typer.input")
  local stats = require("nvim-typer.stats")

  input.detach(state)
  local results = stats.calculate(state)
  stats.display(results, state)
end

---@param cmd_opts NvimTyperCmdOpts
---@return string[]
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

## Top-level vs inside-function `require`

```lua
-- Top of file — loaded when this module is first required
local config = require("nvim-typer.config")
local highlight = require("nvim-typer.highlight")

-- Inside start() — loaded only when a test begins
local ui = require("nvim-typer.ui")
```

`config` and `highlight` are at the top because `setup()` needs them at Neovim startup. Heavier modules (`ui`, `renderer`, `input`, `stats`) are required inside their functions so they only load when someone actually starts a typing test. Since `require()` caches, repeated calls don't re-parse files.

## `setup()` — One-time initialization

Called once in the user's Neovim config. Merges user preferences with defaults and registers highlight groups. Nothing visible happens yet.

## `start()` — Per-test lifecycle

Sequence every time `:TypeTest` runs:

1. **Extract text** — `_get_source_lines()` grabs buffer content or visual selection
2. **Guard** — Empty text gets a warning notification, no window opened
3. **Open UI** — Creates a new tab/float with a scratch buffer, returns the `state` table
4. **Render** — Fills the buffer with dimmed overlay text via extmarks
5. **Attach input** — Hooks up keystroke handlers

## `_get_source_lines()` — Range handling

```lua
if cmd_opts.range == 2 then
  return vim.api.nvim_buf_get_lines(buf, cmd_opts.line1 - 1, cmd_opts.line2, false)
```

`line1`/`line2` are 1-indexed from Neovim, but `nvim_buf_get_lines` wants 0-indexed start and exclusive end. So `line1 - 1` converts to 0-indexed, and `line2` without `-1` works as the exclusive end. For no range (`0`), `0, -1` grabs the whole buffer (`-1` means "last line").

## `stop()` — Teardown

Called when the user finishes or presses `<Esc>`. Order matters: detach input first (no more keystrokes), then calculate stats, then display results.

## The `_` prefix convention

`M._get_source_lines` has an underscore prefix. Lua has no private access, but `_` is a convention meaning "internal — don't call from outside." The public API is `M.setup()`, `M.start()`, and `M.stop()`.
