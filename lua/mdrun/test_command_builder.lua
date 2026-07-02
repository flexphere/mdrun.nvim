-- Test file for command building from code blocks
-- Run with: nvim --headless -c "luafile lua/mdrun/test_command_builder.lua" -c "qa!"

local CodeBlock = require("mdrun/codeblock")

-- Function to build command from codeblock (matching init.lua logic exactly)
local function build_command(codeblock, config)
	if config.cmds[codeblock.lang] == nil then
		error(codeblock.lang .. ": Not supported")
	end
	
	-- Debug attributes
	if codeblock.attrs and next(codeblock.attrs) then
		print("   Attributes found: " .. vim.inspect(codeblock.attrs))
	else
		print("   No attributes")
	end
	
	local cmd = {}
	for _, v in ipairs(config.cmds[codeblock.lang]) do
		-- Replace {CODE_BLOCK} with content
		local replaced = v:gsub("{CODE_BLOCK}", codeblock.content)
		-- Escape backslashes
		replaced = replaced:gsub("\\", "\\\\")
		-- Escape single quotes
		replaced = replaced:gsub("'", "'")
		
		-- Replace attribute placeholders
		if codeblock.attrs ~= nil then
			for k, attr in pairs(codeblock.attrs) do
				if k == "lang" then
					-- Special handling: lang attribute replaces {CODE_BLOCK}
					-- This seems wrong but matches the original code
					k = "CODE_BLOCK"
				end
				replaced = replaced:gsub("{" .. k .. "}", attr)
			end
		end
		
		table.insert(cmd, replaced)
	end
	
	return cmd
end

-- Test helper function
local function test_command(name, codeblock, config, expected_cmd)
	local success, result = pcall(build_command, codeblock, config)
	
	if not success then
		if expected_cmd == nil then
			print("✅ " .. name .. " (expected error)")
			return true
		else
			print("❌ " .. name .. " - Unexpected error: " .. result)
			return false
		end
	end
	
	local cmd = result
	local pass = true
	
	-- Check command length
	if #cmd ~= #expected_cmd then
		pass = false
		print("❌ " .. name .. " - Command length mismatch")
		print("   Expected: " .. #expected_cmd .. " parts")
		print("   Got:      " .. #cmd .. " parts")
	else
		-- Check each command part
		for i, expected in ipairs(expected_cmd) do
			if cmd[i] ~= expected then
				pass = false
				print("❌ " .. name .. " - Command part " .. i .. " mismatch")
				print("   Expected: " .. expected)
				print("   Got:      " .. cmd[i])
			end
		end
	end
	
	if pass then
		print("✅ " .. name)
		-- Print the generated command for verification
		print("   Command: " .. table.concat(cmd, " "))
	end
	
	return pass
end

print("=== Command Builder Tests ===")
print("")

-- Test configurations
local test_config = {
	cmds = {
		sh = { "sh", "-c", "{CODE_BLOCK}" },
		bash = { "bash", "-c" },
		python = { "python3", "-c", "{CODE_BLOCK}" },
		sql = { "sqlite3", "-header", ":memory:", "{CODE_BLOCK}" },
		spanner = { 
			"gcloud", "spanner", "databases", "execute-sql", 
			"{db}", "--instance={instance}", "--project={project}", 
			"--sql={CODE_BLOCK}" 
		},
		bq = { 
			"bq", "query", "--location={location}", 
			"--use_legacy_sql=false", "{CODE_BLOCK}" 
		},
		duckdb = { "duckdb", "-c", "{CODE_BLOCK}" },
		php = { "docker", "run", "--rm", "php", "php", "-r", "{CODE_BLOCK}" },
	}
}

print("-- Basic Command Generation --")

-- Test 1: Simple shell command
local block1 = CodeBlock.new({
	index = 1,
	range = { from = 1, to = 3 },
	lang = "sh",
	attrs = {},
})
block1.content = "echo 'Hello World'"
test_command("Simple shell command", block1, test_config, 
	{"sh", "-c", "echo 'Hello World'"})

-- Test 2: Python command
local block2 = CodeBlock.new({
	index = 2,
	range = { from = 4, to = 6 },
	lang = "python",
	attrs = {},
})
block2.content = "print('Hello Python')"
test_command("Python command", block2, test_config,
	{"python3", "-c", "print('Hello Python')"})

-- Test 3: SQL command
local block3 = CodeBlock.new({
	index = 3,
	range = { from = 7, to = 9 },
	lang = "sql",
	attrs = {},
})
block3.content = "SELECT * FROM users;"
test_command("SQL command", block3, test_config,
	{"sqlite3", "-header", ":memory:", "SELECT * FROM users;"})

print("")
print("-- Parameter Substitution --")

-- Test 4: Spanner with all parameters
local block4 = CodeBlock.new({
	index = 4,
	range = { from = 10, to = 12 },
	lang = "spanner",
	attrs = {  -- Changed from attr to attrs
		db = "mydb",
		instance = "myinstance",
		project = "myproject"
	},
})
block4.content = "SELECT * FROM Organization LIMIT 1"
test_command("Spanner with parameters", block4, test_config,
	{"gcloud", "spanner", "databases", "execute-sql", 
	 "mydb", "--instance=myinstance", "--project=myproject",
	 "--sql=SELECT * FROM Organization LIMIT 1"})

-- Test 5: BigQuery with location
local block5 = CodeBlock.new({
	index = 5,
	range = { from = 13, to = 15 },
	lang = "bq",
	attrs = {
		location = "asia-northeast1"
	},
})
block5.content = "SELECT COUNT(*) FROM dataset.table"
test_command("BigQuery with location", block5, test_config,
	{"bq", "query", "--location=asia-northeast1",
	 "--use_legacy_sql=false", "SELECT COUNT(*) FROM dataset.table"})

print("")
print("-- Language Override --")

-- Test 6: SQL overridden to Spanner
local block6 = CodeBlock.new({
	index = 6,
	range = { from = 16, to = 18 },
	lang = "spanner",  -- Already overridden by parser
	attrs = {
		lang = "spanner",
		db = "testdb",
		instance = "testinstance",
		project = "testproject"
	},
})
block6.content = "SELECT 1"
test_command("SQL as Spanner", block6, test_config,
	{"gcloud", "spanner", "databases", "execute-sql",
	 "testdb", "--instance=testinstance", "--project=testproject",
	 "--sql=SELECT 1"})

print("")
print("-- Special Characters and Escaping --")

-- Test 7: Content with quotes
local block7 = CodeBlock.new({
	index = 7,
	range = { from = 19, to = 21 },
	lang = "sh",
	attrs = {},
})
block7.content = "echo 'It's a test'"
test_command("Content with single quote", block7, test_config,
	{"sh", "-c", "echo 'It's a test'"})

-- Test 8: Content with backslashes
local block8 = CodeBlock.new({
	index = 8,
	range = { from = 22, to = 24 },
	lang = "python",
	attrs = {},
})
block8.content = "print('path\\to\\file')"
test_command("Content with backslashes", block8, test_config,
	{"python3", "-c", "print('path\\\\to\\\\file')"})

print("")
print("-- Complex Real-World Examples --")

-- Test 9: Spanner with complex query
local block9 = CodeBlock.new({
	index = 9,
	range = { from = 25, to = 30 },
	lang = "spanner",
	attrs = {
		db = "production-db",
		instance = "prod-instance",
		project = "gcp-project-123"
	},
})
block9.content = [[SELECT 
  u.id,
  u.name,
  COUNT(o.id) as order_count
FROM Users u
LEFT JOIN Orders o ON u.id = o.user_id
GROUP BY u.id, u.name
HAVING COUNT(o.id) > 5]]

test_command("Complex Spanner query", block9, test_config,
	{"gcloud", "spanner", "databases", "execute-sql",
	 "production-db", "--instance=prod-instance", "--project=gcp-project-123",
	 "--sql=SELECT \n  u.id,\n  u.name,\n  COUNT(o.id) as order_count\nFROM Users u\nLEFT JOIN Orders o ON u.id = o.user_id\nGROUP BY u.id, u.name\nHAVING COUNT(o.id) > 5"})

-- Test 10: PHP with Docker
local block10 = CodeBlock.new({
	index = 10,
	range = { from = 31, to = 33 },
	lang = "php",
	attrs = {},
})
block10.content = "<?php echo 'Hello PHP'; ?>"
test_command("PHP with Docker", block10, test_config,
	{"docker", "run", "--rm", "php", "php", "-r", "<?php echo 'Hello PHP'; ?>"})

print("")
print("-- Error Cases --")

-- Test 11: Unsupported language
local block11 = CodeBlock.new({
	index = 11,
	range = { from = 34, to = 36 },
	lang = "rust",
	attrs = {},
})
block11.content = "fn main() { println!(\"Hello\"); }"
test_command("Unsupported language", block11, test_config, nil)

print("")
print("-- Edge Cases --")

-- Test 12: Empty content
local block12 = CodeBlock.new({
	index = 12,
	range = { from = 37, to = 39 },
	lang = "sh",
	attrs = {},
})
block12.content = ""
test_command("Empty content", block12, test_config,
	{"sh", "-c", ""})

-- Test 13: bash without {CODE_BLOCK} placeholder
local block13 = CodeBlock.new({
	index = 13,
	range = { from = 40, to = 42 },
	lang = "bash",
	attrs = {},
})
block13.content = "echo test"
test_command("Bash without CODE_BLOCK placeholder", block13, test_config,
	{"bash", "-c"})

print("")
print("=== Test Complete ===")