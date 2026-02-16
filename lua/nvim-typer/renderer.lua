local M = {}

---Render all target lines as dimmed overlay text (initial state).
---@param state NvimTyperState
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

---Re-render a single line with correct/incorrect/dimmed chunks.
---@param state NvimTyperState
---@param line_idx integer 0-indexed line number
function M.update_line(state, line_idx)
  -- Clear existing extmarks on this line
  local marks = vim.api.nvim_buf_get_extmarks(
    state.buf, state.ns,
    { line_idx, 0 }, { line_idx, -1 },
    {}
  )
  for _, mark in ipairs(marks) do
    vim.api.nvim_buf_del_extmark(state.buf, state.ns, mark[1])
  end

  local target_line = state.target_lines[line_idx + 1]
  if not target_line or #target_line == 0 then
    return
  end

  local typed_offset = M._line_start_offset(state, line_idx)
  local typed_count = math.max(0, math.min(
    state.cursor_pos - typed_offset,
    #target_line
  ))

  ---@type {[1]: string, [2]: string}[]
  local chunks = {}

  -- Typed characters: correct or incorrect
  for col = 1, typed_count do
    local target_char = target_line:sub(col, col)
    local typed_char = state.typed[typed_offset + col]
    if typed_char == target_char then
      table.insert(chunks, { typed_char, "NvimTyperCorrect" })
    else
      table.insert(chunks, { typed_char or "?", "NvimTyperIncorrect" })
    end
  end

  -- Remaining untyped characters: dimmed
  if typed_count < #target_line then
    local remaining = target_line:sub(typed_count + 1)
    table.insert(chunks, { remaining, "NvimTyperDimmed" })
  end

  vim.api.nvim_buf_set_extmark(state.buf, state.ns, line_idx, 0, {
    virt_text = chunks,
    virt_text_pos = "overlay",
    hl_mode = "combine",
  })
end

---Get the 0-indexed line number for a position in target_flat.
---@param state NvimTyperState
---@param pos integer 0-indexed position in target_flat
---@return integer line_idx 0-indexed line number
function M.pos_to_line(state, pos)
  local offset = 0
  for i, line in ipairs(state.target_lines) do
    local line_end = offset + #line
    if pos <= line_end then
      return i - 1
    end
    offset = line_end + 1 -- +1 for the \n
  end
  return #state.target_lines - 1
end

---Get the 0-indexed column within a line for a position in target_flat.
---@param state NvimTyperState
---@param pos integer 0-indexed position in target_flat
---@return integer col 0-indexed column
function M.pos_to_col(state, pos)
  local offset = M._line_start_offset(state, M.pos_to_line(state, pos))
  return pos - offset
end

---Get the starting offset of a line in target_flat.
---@param state NvimTyperState
---@param line_idx integer 0-indexed line number
---@return integer offset 0-indexed position where this line starts in target_flat
function M._line_start_offset(state, line_idx)
  local offset = 0
  for i = 1, line_idx do
    offset = offset + #state.target_lines[i] + 1 -- +1 for \n
  end
  return offset
end

return M
