local strutil = require("mdrun/strutil")
local CodeBlock = require("mdrun/codeblock")

-- Main

local config = {
	cmds = {
		sh = { "sh", "-c", "{CODE_BLOCK}" },
	},
	layout = "vertical",
}

local buffer_id = nil
local window_id = nil

local get_codeblock_info = function(line)
	local attrs = {}
	local lang = line:gsub("```", "")
	local pos = string.find(lang, " ", 1)
	if pos ~= nil then
		local params = string.sub(lang, pos + 1)
		lang = string.sub(lang, 1, pos - 1)
		attrs = strutil.parse_url(params)
		if attrs["lang"] ~= nil then
			lang = attrs["lang"]
		end
	end
	return lang, attrs
end

local get_codeblocks = function(content)
	local inCodeBlock = false
	local currentBlock = {}
	local codeBlocks = {}

	for line_number, line_content in pairs(content) do
		if not inCodeBlock and strutil.starts_with(line_content, "```") then
			inCodeBlock = true
			local lang, attrs = get_codeblock_info(line_content)
			local index = #codeBlocks + 1
			currentBlock = CodeBlock.new({
				index = index,
				range = { from = line_number, to = line_number },
				attrs = attrs,
				lang = lang,
			})
		elseif inCodeBlock then
			if strutil.starts_with(line_content, "```") then
				inCodeBlock = false
				currentBlock.range.to = line_number
				table.insert(codeBlocks, currentBlock)
			else
				currentBlock.content = currentBlock.content .. "\n" .. line_content
			end
		end
	end

	return codeBlocks
end

local get_current_codeblock = function(cursor, codeBlocks)
	for _, block in pairs(codeBlocks) do
		if cursor[1] > block.range.from and cursor[1] < block.range.to then
			return block
		end
	end
end

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
		vim.cmd("set nowrap")
	end

	if buffer_id == nil or vim.api.nvim_buf_is_valid(buffer_id) == false then
		buffer_id = vim.api.nvim_create_buf(false, true)
	end

	vim.api.nvim_win_set_buf(window_id, buffer_id)
end

--- @param data string
local print_output = function(data)
	open_or_reuse_buffer()
	if buffer_id == nil then
		return
	end

	local lines = vim.api.nvim_buf_line_count(buffer_id)
	vim.api.nvim_buf_set_lines(buffer_id, lines, -1, false, strutil.split_lines(data))
end

local reset_output = function()
	if buffer_id ~= nil then
		vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, {})
	end
end

--- @param codeblock CodeBlock
--- @param input string?
--- @return { code: number, output: string }
local run = function(codeblock, input)
	if config.cmds[codeblock.lang] == nil then
		error(codeblock.lang .. ": Not supported")
	end

	local cmd = {}
	for _, v in ipairs(config.cmds[codeblock.lang]) do
		local replaced = v:gsub("{CODE_BLOCK}", codeblock.content)
		replaced = replaced:gsub("\\", "\\\\")
		replaced = replaced:gsub("'", "'")

		if codeblock.attrs ~= nil then
			for k, attr in pairs(codeblock.attrs) do
				if k == "lang" then
					k = "CODE_BLOCK"
				end
				replaced = replaced:gsub("{" .. k .. "}", attr)
			end
		end

		table.insert(cmd, replaced)
	end

	local opts = {
		text = true,
		env = {
			INPUT = input,
			CODE = codeblock.content,
		},
	}
	if input ~= nil then
		opts.stdin = input
	end

	local res = vim.system(cmd, opts):wait()
	local result = { code = res.code, output = "" }
	if res.code ~= 0 then
		if res.stderr == nil then
			result.output = "Error running code block"
		else
			result.output = res.stderr
		end
	else
		result.output = res.stdout
	end
	return result
end

--- @return CodeBlock[], CodeBlock?
local parseDocument = function()
	local winnr = vim.api.nvim_get_current_win()
	local bufnr = vim.api.nvim_win_get_buf(winnr)
	local cursor = vim.api.nvim_win_get_cursor(winnr)
	local content = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_buf_line_count(bufnr), false)

	local codeblocks = get_codeblocks(content)
	local current_codeblock = get_current_codeblock(cursor, codeblocks)

	return codeblocks, current_codeblock
end

local M = {}

M.setup = function(opts)
	if opts then
		config = vim.tbl_extend("force", config, opts)
	end
end

M.run = function()
	reset_output()

	local _, codeblock = parseDocument()
	if codeblock == nil then
		error("cursor must be inside a code block.")
	end

	local res = run(codeblock)
	print_output(res.output)
end

M.runAll = function()
	reset_output()

	local codeblocks, _ = parseDocument()
	local input = nil

	for i, codeblock in pairs(codeblocks) do
		print_output("⚡Step " .. i .. " ---------------------------")
		local res = run(codeblock, input)
		print_output(res.output)
		input = res.output

		if res.code ~= 0 then
			break
		end
		print_output("\r \r ")
	end
end

return M
