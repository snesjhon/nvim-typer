local renderer = require("nvim-typer.renderer")

local M = {}

---Attach all input handlers to the typing test buffer.
---@param state NvimTyperState
function M.attach(state)
  -- Character input via InsertCharPre
  local char_id = vim.api.nvim_create_autocmd("InsertCharPre", {
    buffer = state.buf,
    callback = function()
      if state.finished then
        return
      end

      -- Start timer on first keypress
      if not state.start_time then
        state.start_time = vim.loop.hrtime()
      end

      local char = vim.v.char
      local expected = state.target_flat:sub(state.cursor_pos + 1, state.cursor_pos + 1)

      -- Suppress the actual character from entering the buffer
      vim.v.char = ""

      -- Skip if we're at a newline boundary (Enter handles that)
      if expected == "\n" then
        return
      end

      table.insert(state.typed, char)
      state.cursor_pos = state.cursor_pos + 1
      state.total_keystrokes = state.total_keystrokes + 1

      if char == expected then
        state.correct_keystrokes = state.correct_keystrokes + 1
      end

      vim.schedule(function()
        M._update_and_move(state)
      end)
    end,
  })
  table.insert(state.autocmd_ids, char_id)

  -- Snap cursor back to cursor_pos when re-entering insert mode
  local insert_enter_id = vim.api.nvim_create_autocmd("InsertEnter", {
    buffer = state.buf,
    callback = function()
      if state.finished then
        return
      end
      vim.schedule(function()
        M._move_cursor(state)
      end)
    end,
  })
  table.insert(state.autocmd_ids, insert_enter_id)

  -- Enter key — advance through newlines and skip indentation
  vim.keymap.set("i", "<CR>", function()
    if state.finished then
      return
    end

    if not state.start_time then
      state.start_time = vim.loop.hrtime()
    end

    local expected = state.target_flat:sub(state.cursor_pos + 1, state.cursor_pos + 1)
    if expected ~= "\n" then
      return
    end

    -- Record the newline
    table.insert(state.typed, "\n")
    state.cursor_pos = state.cursor_pos + 1
    state.total_keystrokes = state.total_keystrokes + 1
    state.correct_keystrokes = state.correct_keystrokes + 1

    -- Auto-skip leading whitespace on the next line
    M._skip_indentation(state)

    vim.schedule(function()
      local prev_line = renderer.pos_to_line(state, state.cursor_pos - 1)
      local curr_line = renderer.pos_to_line(state, state.cursor_pos)
      renderer.update_line(state, prev_line)
      if curr_line ~= prev_line then
        renderer.update_line(state, curr_line)
      end
      M._move_cursor(state)
      M._check_finished(state)
    end)
  end, { buffer = state.buf })

  -- Backspace — undo last character (and undo auto-skipped indentation)
  vim.keymap.set("i", "<BS>", function()
    if state.finished or state.cursor_pos == 0 then
      return
    end

    local start_pos = state.cursor_pos

    -- Remove the last typed character
    state.cursor_pos = state.cursor_pos - 1
    table.remove(state.typed)

    -- If we just backspaced onto a newline, also undo the indentation skip
    -- that was auto-applied when Enter was pressed. Keep removing whitespace
    -- chars until we hit the newline itself.
    while state.cursor_pos > 0 do
      local char_at = state.target_flat:sub(state.cursor_pos, state.cursor_pos)
      if char_at ~= " " and char_at ~= "\t" then
        break
      end
      -- Check if this whitespace is leading indentation (preceded by \n or more whitespace)
      local before = state.target_flat:sub(state.cursor_pos - 1, state.cursor_pos - 1)
      if before ~= "\n" and before ~= " " and before ~= "\t" then
        break
      end
      state.cursor_pos = state.cursor_pos - 1
      table.remove(state.typed)
    end

    vim.schedule(function()
      -- Re-render all affected lines between old and new position
      local old_line = renderer.pos_to_line(state, start_pos)
      local new_line = renderer.pos_to_line(state, state.cursor_pos)
      for l = new_line, old_line do
        renderer.update_line(state, l)
      end
      M._move_cursor(state)
    end)
  end, { buffer = state.buf })

  -- Leader-q — quit the test
  vim.keymap.set("n", "<leader>q", function()
    if state.finished then
      return
    end
    state.end_time = vim.loop.hrtime()
    state.finished = true
    vim.schedule(function()
      require("nvim-typer").stop(state)
    end)
  end, { buffer = state.buf, desc = "Quit typing test" })

  -- Cleanup if buffer is wiped externally
  local wipe_id = vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = state.buf,
    callback = function()
      state.finished = true
      M.detach(state)
    end,
  })
  table.insert(state.autocmd_ids, wipe_id)
end

---Remove all autocmds. Buffer-local keymaps are cleaned up automatically on wipe.
---@param state NvimTyperState
function M.detach(state)
  for _, id in ipairs(state.autocmd_ids) do
    pcall(vim.api.nvim_del_autocmd, id)
  end
  state.autocmd_ids = {}
end

---Auto-advance cursor_pos past leading whitespace on the current line.
---Fills state.typed with the whitespace characters and counts them as correct.
---@param state NvimTyperState
function M._skip_indentation(state)
  while state.cursor_pos < #state.target_flat do
    local char = state.target_flat:sub(state.cursor_pos + 1, state.cursor_pos + 1)
    if char ~= " " and char ~= "\t" then
      break
    end
    table.insert(state.typed, char)
    state.cursor_pos = state.cursor_pos + 1
    state.correct_keystrokes = state.correct_keystrokes + 1
  end
end

---Re-render the current line and move the cursor.
---@param state NvimTyperState
function M._update_and_move(state)
  local line_idx = renderer.pos_to_line(state, state.cursor_pos)
  renderer.update_line(state, line_idx)
  M._move_cursor(state)
  M._check_finished(state)
end

---Move the Neovim cursor to match cursor_pos.
---@param state NvimTyperState
function M._move_cursor(state)
  if not vim.api.nvim_win_is_valid(state.win) then
    return
  end
  local line = renderer.pos_to_line(state, state.cursor_pos)
  local col = renderer.pos_to_col(state, state.cursor_pos)
  vim.api.nvim_win_set_cursor(state.win, { line + 1, col })
end

---Check if the user has typed all characters.
---@param state NvimTyperState
function M._check_finished(state)
  if state.cursor_pos >= #state.target_flat then
    state.end_time = vim.loop.hrtime()
    state.finished = true
    require("nvim-typer").stop(state)
  end
end

return M
