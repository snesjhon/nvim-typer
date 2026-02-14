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
