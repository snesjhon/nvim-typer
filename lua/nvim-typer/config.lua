---@class NvimTyperWindowOpts
---@field style "tab" | "float"
---@field width number Fraction of editor width (float only)
---@field height number Fraction of editor height (float only)
---@field border string Border style (float only)

---@class NvimTyperHighlightOpts
---@field dimmed vim.api.keyset.highlight
---@field correct vim.api.keyset.highlight
---@field incorrect vim.api.keyset.highlight

---@class NvimTyperOpts
---@field window NvimTyperWindowOpts
---@field highlights NvimTyperHighlightOpts

---@class NvimTyperState
---@field buf integer Buffer handle for the typing test
---@field win integer Window handle for the typing test
---@field ns integer Namespace ID for extmarks
---@field target_lines string[] Original text split by line
---@field target_flat string Full text joined with newlines
---@field typed string[] Characters typed so far
---@field cursor_pos integer 0-indexed position in target_flat
---@field start_time integer? hrtime of first keypress (nil until started)
---@field end_time integer? hrtime when test ended
---@field total_keystrokes integer Every forward keypress (not backspace)
---@field correct_keystrokes integer Only keystrokes matching the target
---@field finished boolean Whether the test has ended
---@field autocmd_ids integer[] Autocmd IDs for cleanup
---@field original_tab integer Tabpage to return to after test

---@class NvimTyperCmdOpts
---@field range integer 0 = no range, 2 = visual range
---@field line1 integer Start line (1-indexed)
---@field line2 integer End line (1-indexed)

local M = {}

---@type NvimTyperOpts
M.defaults = {
  window = {
    style = "tab",
    width = 0.6,
    height = 0.4,
    border = "rounded",
  },
  highlights = {
    dimmed = { fg = "#555555" },
    correct = { fg = "#a6e3a1" },
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
