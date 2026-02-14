# Module 2: `lua/nvim-typer/config.lua` — Configuration

## File

```lua
local M = {}

---@type NvimTyperOpts
M.defaults = {
  window = { style = "tab", width = 0.6, height = 0.4, border = "rounded" },
  highlights = {
    dimmed    = { fg = "#555555" },
    correct   = { fg = "#a6e3a1" },
    incorrect = { fg = "#f38ba8", undercurl = true },
  },
}

---@type NvimTyperOpts
M.options = vim.deepcopy(M.defaults)

---@param user_opts? NvimTyperOpts
function M.merge(user_opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, user_opts or {})
end

return M
```

## The `local M = {} ... return M` pattern

The standard Lua module pattern in Neovim. Every module:

1. Creates a local table `M`
2. Attaches functions and data to it
3. Returns it at the end

When another file calls `require("nvim-typer.config")`, they get back this `M` table.

## `M.defaults` vs `M.options`

- **`M.defaults`** — Never mutated. Source of truth for default config.
- **`M.options`** — The "live" config the rest of the plugin reads from. Starts as a copy of defaults, overwritten when the user calls `setup()`.

## `vim.deepcopy(M.defaults)`

Creates a **deep clone** — a completely independent copy. Without this, `M.options` would be a reference to the same table as `M.defaults`, and mutating one would mutate the other.

## `vim.tbl_deep_extend("force", M.defaults, user_opts or {})`

The workhorse of Neovim plugin configuration. **Recursively merges** tables.

- **`"force"`** — When both tables have the same key, the later table wins. Other options are `"keep"` (first wins) and `"error"` (throw on conflict).
- **`M.defaults`** — The base. Every key the user doesn't specify falls back to this.
- **`user_opts or {}`** — The user's overrides. `or {}` handles `setup()` called with no arguments.

The "deep" part means it merges nested tables recursively. So a user passing `{ highlights = { correct = { fg = "#00ff00" } } }` only overrides that one nested value — everything else stays at defaults.

## Why merge against `M.defaults` (not `M.options`)

Always merging against `M.defaults` means calling `setup()` twice starts fresh each time — no accumulated state from a previous call.

## Type definitions

This file also houses all `---@class` definitions for the project:

- **`NvimTyperOpts`** — Config shape (window + highlights)
- **`NvimTyperState`** — The state table passed between modules. `?` suffix marks nullable fields (`integer?` = `integer | nil`)
- **`NvimTyperCmdOpts`** — What Neovim passes to command callbacks

`lua_ls` resolves these globally — any file can reference `NvimTyperState` without importing.
