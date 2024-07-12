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

`{CODE_BLOCK}` string in the command would be replaced with the code block content.
if you want to run the code block for compiled languages in a code block, you can use something like the following:

your markdown:
```markdown
```c
#include <stdio.h>

int main(){
    printf("hello from c");
    return 0;
}
```
```

mdrun setup:

```lua
require('mdrun').setup({
    cmds = {
	c = { 'sh', '-c', "echo '{CODE_BLOCK}' > /tmp/mdrun.c && gcc /tmp/mdrun.c -o /tmp/mdrun && /tmp/mdrun" },
    },
})

