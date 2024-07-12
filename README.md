# mdrun.nvim

Run code blocks in markdown files.

### Installation

#### Lazy.nvim
```lua
{
	"flexphere/mdrun.nvim",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	filetype = "markdown",
	config = function()
		require('mdrun').setup({})
	end
}
```

### Usage

mdrun provides a single comman `run` to run code blocks in current cursor position.
you can run `:lua require('mdrun').run()` in command mode or map it to a keybinding.
```lua
vim.keymap.set('n', '<leader><enter>', require('mdrun').run, { desc = 'Run CodeBlock' })
```


### Configuration

by default it would only run code blocks with language type of `sh`. 
You can add more commands to run code blocks with different languages.

`{CODE_BLOCK}` string in the command would be replaced with the code block content.
common use case would be to run code blocks for compiled languages.

```lua
require('mdrun').setup({
    cmds = {
	sh = { 'sh', '-c' },
        python = { 'python3', '-c' },
        js = { 'node', '-e' },
        ts = { 'npx', '--yes', 'tsx', '-e' },
        sql = { 'sqlite3', '-header', ':memory:'},
        php = { 'docker', 'run', '--rm', 'php', 'php', '-r' },
	c = { 'sh', '-c', "echo '{CODE_BLOCK}' > /tmp/mdrun.c && gcc /tmp/mdrun.c && /tmp/a.out" },
    },
})
```
