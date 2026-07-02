-- String Utils
local strutil = {}

--- @param str string
--- @param start string
--- @return boolean
function strutil.starts_with(str, start)
	return str:sub(1, #start) == start
end

--- @param str string
--- @return string[]
function strutil.split_lines(str)
	local lines = {}
	for s in str:gmatch("[^\r\n]+") do
		table.insert(lines, s)
	end
	return lines
end

--- @param str string
--- @return string
function strutil.urldecode(str)
	str = str:gsub("+", " "):gsub("%%(%x%x)", function(h)
		return string.char(tonumber(h, 16))
	end)
	return str
end

--- @param str string
--- @return string[]
function strutil.parse_url(str)
	local ans = {}
	for k, v in str:gmatch("([^&=?]-)=([^&=?]+)") do
		ans[k] = strutil.urldecode(v)
	end
	return ans
end

return strutil
