# Module 3: `lua/nvim-typer/highlight.lua` — Highlight Groups

## File

```lua
local M = {}

---@param opts NvimTyperOpts
function M.setup(opts)
  vim.api.nvim_set_hl(0, "NvimTyperDimmed", opts.highlights.dimmed)
  vim.api.nvim_set_hl(0, "NvimTyperCorrect", opts.highlights.correct)
  vim.api.nvim_set_hl(0, "NvimTyperIncorrect", opts.highlights.incorrect)
end

return M
```

## `nvim_set_hl` — Defining highlight groups

`vim.api.nvim_set_hl(ns_id, name, opts)` registers a **highlight group** — a named style definition referenced later by extmarks, syntax rules, statuslines, etc.

### Arguments

1. **`0` (namespace)** — Namespace `0` means "global." The highlight is available everywhere, not scoped to a specific buffer or window.

2. **`"NvimTyperDimmed"` (name)** — The group name. Convention is to prefix with your plugin name to avoid collisions with other plugins.

3. **`opts` (style table)** — The visual properties from config:
   - `{ fg = "#555555" }` — Foreground color (dimmed gray)
   - `{ fg = "#a6e3a1" }` — Green foreground (correct)
   - `{ fg = "#f38ba8", undercurl = true }` — Red foreground + wavy underline (incorrect)
   - Other available properties: `bg`, `bold`, `italic`, `strikethrough`, `sp` (special color for underlines)

## How these get used

These group names are just definitions — they don't do anything visible on their own. In `renderer.lua`, extmarks reference them by name:

```lua
{ "h", "NvimTyperCorrect" }    -- renders "h" in green
{ "x", "NvimTyperIncorrect" }  -- renders "x" in red with undercurl
{ "ello", "NvimTyperDimmed" }  -- renders "ello" in gray
```

This decoupling means the renderer doesn't know about colors, and users can customize colors without touching rendering logic.

## When does `M.setup()` run?

Called from `init.lua`'s `setup()`, which the user triggers with `require("nvim-typer").setup({})`. Highlights are registered once at startup, before any typing test begins.
