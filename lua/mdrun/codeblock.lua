-- CodeBlock Utils

---@class CodeBlock
---@field index number
---@field range {from: number, to: number}
---@field attrs table?
---@field lang string
---@field content string
local CodeBlock = {}

---@param param {
---	index: number,
---	range: { from: number, to: number },
---	lang: string,
---	attrs: table?,
---}
---@return CodeBlock
function CodeBlock.new(param)
	local o = {
		index = param.index,
		range = param.range,
		attrs = param.attrs,
		lang = param.lang,
		content = "",
	}
	setmetatable(o, { __index = CodeBlock })
	return o
end

return CodeBlock
