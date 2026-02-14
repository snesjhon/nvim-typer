vim.api.nvim_create_user_command("TypeTest", function(opts)
	---@cast opts NvimTyperCmdOpts
	require("nvim-typer").start(opts)
end, { range = true, desc = "Start a typing test from buffer content or visual selection" })
