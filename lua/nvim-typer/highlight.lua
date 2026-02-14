local M = {}

---@param opts NvimTyperOpts
function M.setup(opts)
	vim.api.nvim_set_hl(0, "NvimTyperDimmed", opts.highlights.dimmed)
	vim.api.nvim_set_hl(0, "NvimTyperCorrect", opts.highlights.correct)
	vim.api.nvim_set_hl(0, "NvimTyperIncorrect", opts.highlights.incorrect)
end

return M
