local parsers = require("nvim-treesitter.parsers")

local config = {
	cmds = {
		sh = { "sh", "-c" },
	},
	layout = "vertical",
}

local buffer_id = nil
local window_id = nil

local function open_or_reuse_buffer()
	if window_id == nil or vim.api.nvim_win_is_valid(window_id) == false then
		if config.layout == "vertical" then
			vim.cmd("vsplit")
		elseif config.layout == "horizontal" then
			vim.cmd("split")
		else
			error("Invalid layout")
		end
		window_id = vim.api.nvim_get_current_win()
	end

	if buffer_id == nil or vim.api.nvim_buf_is_valid(buffer_id) == false then
		buffer_id = vim.api.nvim_create_buf(false, true)
	end

	vim.api.nvim_win_set_buf(window_id, buffer_id)
end

local function get_ancestor(node, type)
	if node:type() == type then
		return node
	end

	local parent = node:parent()
	while parent ~= nil and parent:type() ~= type do
		parent = parent:parent()
	end

	return parent
end

local function get_code_block_lang(code_block, bufnr)
	local lang = ""
	if code_block:child(1) ~= nil then
		local lang_node = code_block:child(1)
		if lang_node:type() == "info_string" then
			lang = vim.treesitter.get_node_text(lang_node, bufnr)
		end
	end

	return lang
end

local output_handler = function(_, data, _)
	if data and (#data == 1 and data[1] == "") == false then
		open_or_reuse_buffer()
		if buffer_id == nil then
			return
		end

		vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, data)
	end
end

local M = {}

M.setup = function(opts)
	if opts then
		config = vim.tbl_extend("force", config, opts)
	end
end

M.run = function()
	local winnr = vim.api.nvim_get_current_win()
	local bufnr = vim.api.nvim_win_get_buf(winnr)
	local parser = parsers.get_parser(bufnr)
	if not parser then
		error("unable to find treesitter parser.")
		return
	end

	local cursor = vim.api.nvim_win_get_cursor(winnr)
	local curr_node = parser:parse()[1]:root():descendant_for_range(cursor[1] - 1, cursor[2], cursor[1] - 1, cursor[2])

	local code_content = get_ancestor(curr_node, "code_fence_content")
	if code_content == nil then
		error("cursor must be inside a code block.")
	end

	local code_block = get_ancestor(curr_node, "fenced_code_block")
	if code_block == nil then
		error("cursor must be inside a code block.")
	end

	local lang = get_code_block_lang(code_block, bufnr)
	if config.cmds[lang] == nil then
		error(lang .. ": Not supported")
	end

	local cmd = {}
	local content = vim.treesitter.get_node_text(code_content, bufnr)
	for _, v in ipairs(config.cmds[lang]) do
		local replaced = v:gsub("{CODE_BLOCK}", content)
		replaced = replaced:gsub("\\", "\\\\")
		replaced = replaced:gsub("'", "'")
		table.insert(cmd, replaced)
	end
	table.insert(cmd, content)

	vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = output_handler,
		on_stderr = output_handler,
	})
end

return M
