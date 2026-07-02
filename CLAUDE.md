# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

mdrun.nvim is a Neovim plugin that executes fenced code blocks in markdown files. `run()` executes the block under the cursor; `runAll()` executes every block in the document sequentially, piping each block's stdout into the next block's stdin.

There is no plugin/ directory or autoload — the plugin is pure Lua under `lua/mdrun/`, loaded via `require('mdrun').setup(opts)` and invoked with `:lua require('mdrun').run()` (users map this to a keybinding).

## Development Commands

There is no build or lint step. Tests are standalone Lua scripts run through headless Neovim (they need `vim.*` APIs):

```bash
# Command builder tests
nvim --headless -c "luafile lua/mdrun/test_command_builder.lua" -c "qa!"

# Code block parser tests
nvim --headless -c "luafile lua/mdrun/test_codeblock_parser.lua" -c "qa!"
```

Tests print ✅/❌ per case; there is no test framework or exit-code reporting, so read the output. Note the test files duplicate logic from `init.lua` (e.g. `get_codeblock_info`, `build_command`) rather than importing it — if you change parsing or command-building logic in `init.lua`, update the copies in the test files to match.

Manual verification: open any markdown file with fenced code blocks in nvim with the plugin loaded, place the cursor inside a block, and call `run()`.

## Architecture

### Components

- **lua/mdrun/init.lua** — everything: config, parsing, execution, output buffer management. `setup()`, `M.run()`, `M.runAll()`.
- **lua/mdrun/codeblock.lua** — `CodeBlock` class: `index`, `range {from, to}` (1-based buffer line numbers of the fence lines), `lang`, `attrs`, `content`.
- **lua/mdrun/strutil.lua** — string helpers: `starts_with`, `split_lines`, `urldecode`, `parse_url`.

### Parsing (line-based, not treesitter)

Despite README listing nvim-treesitter as a dependency, parsing does not use treesitter. `get_codeblocks()` scans buffer lines for ` ``` ` fences. Cursor-to-block matching in `get_current_codeblock()` is exclusive: the cursor must be strictly between the fence lines, not on them.

### Code Block Attributes

Attributes follow the language after a single space, in **URL query format** (`&`-separated, values URL-decoded):

    ```sql lang=spanner&instance=prod&db=mydb

- Parsed by `strutil.parse_url` into `attrs`
- The special `lang` attribute overrides the block's language (used to route e.g. a `sql` block to a `spanner` runner while keeping sql syntax highlighting)
- Each attribute is available as a `{attribute_name}` placeholder in command templates

### Command Building & Execution (the `run` function in init.lua)

For each element of the configured command array:

1. `{CODE_BLOCK}` is replaced with the block content
2. Backslashes are escaped; there is also a no-op quote gsub (`gsub("'", "'")`) left from debugging
3. Each attribute replaces its `{name}` placeholder — with the quirk that the `lang` attribute is remapped to the `CODE_BLOCK` key inside this loop

Execution is **synchronous**: `vim.system(cmd, opts):wait()`. Environment variables passed to the process: `INPUT` (previous block's output, runAll only) and `CODE` (the block content). When input exists it is also passed as stdin.

On non-zero exit, stderr is shown in the output buffer; `runAll()` stops the chain at the first failing block.

### Output Buffer

A single scratch buffer/window pair (module-level `buffer_id`/`window_id`) is reused across runs, opened via `vsplit`/`split` per `config.layout` ("vertical" default, or "horizontal"). Output is appended with `print_output()`; `reset_output()` clears it at the start of each run.

## Configuration

```lua
require('mdrun').setup({
  layout = "vertical",  -- or "horizontal"
  cmds = {
    sh = { "sh", "-c", "{CODE_BLOCK}" },       -- the built-in default
    python = { "python3", "-c", "{CODE_BLOCK}" },
    spanner = { "gcloud", "spanner", "databases", "execute-sql",
                "{db}", "--instance={instance}", "--project={project}",
                "--sql={CODE_BLOCK}" },
  },
})
```

Important: command arrays without a `{CODE_BLOCK}` placeholder do **not** get the code appended automatically — the code only reaches the process via the placeholder or the `CODE`/stdin environment. `setup()` merges with `vim.tbl_extend("force", ...)`, so a user-supplied `cmds` table replaces the default one entirely.
