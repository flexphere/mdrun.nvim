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
vim.api.nvim_set_keymap('n', '<leader>r', require("mdrun").run, { noremap = true, silent = true })
```


### Configuration

by default it would only run code blocks with language type of `sh`. 
You can add more commands to run code blocks with different languages.

```lua
require('mdrun').setup({
    cmds = {
        python = { 'python3', '-c' },
        js = { 'node', '-e' },
        ts = { 'tsx', '-e' },
        sql = { 'sqlite3', '-header', ':memory:'},
        php = { 'docker', 'run', '--rm', 'php', 'php', '-r' },
    },
})
```

