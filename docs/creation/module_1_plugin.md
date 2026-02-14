# Module 1: `plugin/nvim-typer.lua` — Command Registration

## File

```lua
vim.api.nvim_create_user_command("TypeTest", function(opts)
  ---@cast opts NvimTyperCmdOpts
  require("nvim-typer").start(opts)
end, { range = true, desc = "Start a typing test from buffer content or visual selection" })
```

## How Neovim discovers plugins

When your plugin is in the **runtimepath** (via lazy.nvim's `dir = ...` or `set rtp+=...`), Neovim scans for a `plugin/` directory and **auto-sources every file inside it** at startup. You don't `require()` this file — Neovim runs it for you.

This is the only directory with that behavior. Files in `lua/` are never auto-run; they're loaded lazily via `require()`.

## `nvim_create_user_command` — the 3 arguments

1. **`"TypeTest"`** — The command name. Users type `:TypeTest` in command mode. Convention is PascalCase for plugin commands.

2. **`function(opts)`** — The callback. Neovim passes an `opts` table with metadata about how the command was invoked:
   - `opts.range` — `0` if no range, `1` if a single line address, `2` if a visual range
   - `opts.line1` / `opts.line2` — The line range (1-indexed)

3. **`{ range = true, desc = "..." }`** — Options. `range = true` tells Neovim "this command accepts a line range." Without this, `:'<,'>TypeTest` would error. `desc` shows up in `:help` and command completion.

## Lazy-loading pattern

`require("nvim-typer")` is inside the callback, not at the top of the file. Since `plugin/` files run at startup, putting `require` at the top would force-load all plugin code immediately — even if the user never runs `:TypeTest`. By putting it inside the callback, `lua/nvim-typer/init.lua` only loads when the command is actually invoked.

## The `require()` path

`require("nvim-typer")` tells Lua to find `lua/nvim-typer/init.lua` in the runtimepath. The mapping:

- `require("nvim-typer")` → `lua/nvim-typer/init.lua`
- `require("nvim-typer.config")` → `lua/nvim-typer/config.lua`
- `require("nvim-typer.ui")` → `lua/nvim-typer/ui.lua`

Lua's `require` caches modules — the first call runs the file and returns the module table, subsequent calls return the cached result.

## `---@cast` annotation

`---@cast opts NvimTyperCmdOpts` tells `lua_ls` to treat the `opts` parameter (which Neovim types generically) as our custom `NvimTyperCmdOpts` type. This gives us hover information and autocomplete on `opts.range`, `opts.line1`, etc.
