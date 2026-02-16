local M = {}

---@class NvimTyperResults
---@field gross_wpm integer All typed characters counted
---@field net_wpm integer Only correct characters counted
---@field accuracy number Percentage (0-100)
---@field elapsed_sec number Seconds with one decimal
---@field total_chars integer Length of target text
---@field typed_chars integer How many characters were typed
---@field correct_chars integer How many matched the target

---Calculate typing test results from state.
---@param state NvimTyperState
---@return NvimTyperResults
function M.calculate(state)
  local elapsed_ns = (state.end_time or vim.loop.hrtime()) - (state.start_time or vim.loop.hrtime())
  local elapsed_sec = elapsed_ns / 1e9
  local elapsed_min = elapsed_sec / 60

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

---Display results in a centered floating window.
---@param results NvimTyperResults
---@param state NvimTyperState
function M.display(results, state)
  local ui = require("nvim-typer.ui")
  ui.close(state)

  local lines = {
    "",
    "  nvim-typer Results",
    "  --------------------",
    string.format("  WPM (net):    %d", results.net_wpm),
    string.format("  WPM (gross):  %d", results.gross_wpm),
    string.format("  Accuracy:     %.1f%%", results.accuracy),
    string.format("  Time:         %.1fs", results.elapsed_sec),
    string.format("  Characters:   %d / %d", results.correct_chars, results.total_chars),
    "",
    "  Press q or <Enter> to close",
    "",
  }

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false

  local width = 34
  local height = #lines
  local editor_w = vim.o.columns
  local editor_h = vim.o.lines
  local row = math.floor((editor_h - height) / 2)
  local col = math.floor((editor_w - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    border = "rounded",
    title = " Results ",
    title_pos = "center",
    style = "minimal",
  })

  ---@param close_win integer
  local function close(close_win)
    return function()
      if vim.api.nvim_win_is_valid(close_win) then
        vim.api.nvim_win_close(close_win, true)
      end
    end
  end

  vim.keymap.set("n", "q", close(win), { buffer = buf })
  vim.keymap.set("n", "<CR>", close(win), { buffer = buf })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    once = true,
    callback = close(win),
  })
end

return M
