local M = {}

---@param opts NvimTyperOpts
---@param target_lines string[]
---@return NvimTyperState
function M.open(opts, target_lines)
  local original_tab = vim.api.nvim_get_current_tabpage()
  local buf, win

  if opts.window.style == "float" then
    buf, win = M._open_float(opts)
  else
    buf, win = M._open_tab()
  end

  M._setup_buffer(buf, target_lines)

  vim.api.nvim_win_set_cursor(win, { 1, 0 })
  vim.cmd("startinsert")

  ---@type NvimTyperState
  local state = {
    buf = buf,
    win = win,
    ns = vim.api.nvim_create_namespace("nvim_typer"),
    target_lines = target_lines,
    target_flat = table.concat(target_lines, "\n"),
    typed = {},
    cursor_pos = 0,
    start_time = nil,
    end_time = nil,
    total_keystrokes = 0,
    correct_keystrokes = 0,
    finished = false,
    autocmd_ids = {},
    original_tab = original_tab,
  }

  return state
end

---@param state NvimTyperState
function M.close(state)
  if vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end

  if vim.api.nvim_tabpage_is_valid(state.original_tab) then
    vim.api.nvim_set_current_tabpage(state.original_tab)
  end
end

---@return integer buf
---@return integer win
function M._open_tab()
  vim.cmd("tabnew")
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  return buf, win
end

---@param opts NvimTyperOpts
---@return integer buf
---@return integer win
function M._open_float(opts)
  local buf = vim.api.nvim_create_buf(false, true)

  local editor_w = vim.o.columns
  local editor_h = vim.o.lines

  local win_w = math.floor(editor_w * opts.window.width)
  local win_h = math.floor(editor_h * opts.window.height)
  local row = math.floor((editor_h - win_h) / 2)
  local col = math.floor((editor_w - win_w) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = win_w,
    height = win_h,
    row = row,
    col = col,
    border = opts.window.border,
    title = " nvim-typer ",
    title_pos = "center",
    style = "minimal",
  })

  return buf, win
end

---@param buf integer
---@param target_lines string[]
function M._setup_buffer(buf, target_lines)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "nvim-typer"

  local empty_lines = {}
  for i, line in ipairs(target_lines) do
    empty_lines[i] = string.rep(" ", #line)
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, empty_lines)
end

return M
