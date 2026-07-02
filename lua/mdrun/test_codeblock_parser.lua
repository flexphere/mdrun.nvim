-- Test file for codeblock parser
-- Run with: nvim -c "luafile lua/mdrun/test_codeblock_parser.lua"

local strutil = require("mdrun/strutil")

-- Copy of get_codeblock_info from init.lua for testing
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

-- Test helper function
local function test(name, input, expected_lang, expected_attrs)
	local lang, attrs = get_codeblock_info(input)
	local pass = true
	
	-- Check language
	if lang ~= expected_lang then
		pass = false
		print("❌ " .. name .. " - Language mismatch")
		print("   Expected: " .. (expected_lang or "nil"))
		print("   Got:      " .. (lang or "nil"))
	end
	
	-- Check attributes
	expected_attrs = expected_attrs or {}
	for k, v in pairs(expected_attrs) do
		if attrs[k] ~= v then
			pass = false
			print("❌ " .. name .. " - Attribute '" .. k .. "' mismatch")
			print("   Expected: " .. (v or "nil"))
			print("   Got:      " .. (attrs[k] or "nil"))
		end
	end
	
	-- Check for unexpected attributes
	for k, v in pairs(attrs) do
		if expected_attrs[k] == nil then
			pass = false
			print("❌ " .. name .. " - Unexpected attribute '" .. k .. "'")
			print("   Value: " .. (v or "nil"))
		end
	end
	
	if pass then
		print("✅ " .. name)
	end
	
	return pass
end

print("=== Codeblock Parser Tests ===")
print("")

print("-- Basic Language Parsing --")
test("Python block", "```python", "python", {})
test("JavaScript block", "```js", "js", {})
test("Shell block", "```sh", "sh", {})
test("SQL block", "```sql", "sql", {})

print("")
print("-- URL Parameters Parsing (space + key=value&key=value format) --")
test("SQL with db and instance", 
     "```sql db=test&instance=prod", 
     "sql", 
     {db="test", instance="prod"})

test("Python with env and timeout", 
     "```python env=dev&timeout=30", 
     "python", 
     {env="dev", timeout="30"})

test("Shell with single param", 
     "```sh debug=true", 
     "sh", 
     {debug="true"})

print("")
print("-- Language Override with lang attribute --")
test("SQL overridden to spanner", 
     "```sql lang=spanner&db=test", 
     "spanner", 
     {lang="spanner", db="test"})

test("JS overridden to typescript", 
     "```js lang=typescript", 
     "typescript", 
     {lang="typescript"})

print("")
print("-- Complex Cases --")
test("Multiple parameters", 
     "```sql lang=spanner&instance=prod&db=mydb&project=test", 
     "spanner", 
     {lang="spanner", instance="prod", db="mydb", project="test"})

test("URL encoded values", 
     "```sh path=%2Fusr%2Fbin&name=test%20file", 
     "sh", 
     {path="/usr/bin", name="test file"})

test("Parameters with special chars", 
     "```python env=production&version=3.11", 
     "python", 
     {env="production", version="3.11"})

print("")
print("-- Edge Cases --")
test("No parameters", "```python", "python", {})
test("Empty language with params", "``` db=test", "", {db="test"})
test("Just backticks", "```", "", {})
test("Language only with trailing space", "```python ", "python", {})

print("")
print("-- Real World Examples --")
test("Spanner query", 
     "```sql lang=spanner&instance=bluage-shared&db=canary-cloud-prod", 
     "spanner", 
     {lang="spanner", instance="bluage-shared", db="canary-cloud-prod"})

test("Spanner with project", 
     "```sql lang=spanner&db=canary-cloud-prod&instance=bluage-shared&project=my-project", 
     "spanner", 
     {lang="spanner", db="canary-cloud-prod", instance="bluage-shared", project="my-project"})

test("BigQuery with location", 
     "```sql lang=bq&location=asia-northeast1&dataset=analytics", 
     "bq", 
     {lang="bq", location="asia-northeast1", dataset="analytics"})

test("DuckDB with file", 
     "```sql lang=duckdb&file=data.parquet", 
     "duckdb", 
     {lang="duckdb", file="data.parquet"})

test("Simple shell command", 
     "```sh", 
     "sh", 
     {})

test("Python with virtual env", 
     "```python venv=/Users/flexphere/.venv&timeout=60", 
     "python", 
     {venv="/Users/flexphere/.venv", timeout="60"})

print("")
print("=== Test Complete ===")