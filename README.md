# cmake-kits.nvim
This plugin was inspired by [cmake-tools.nvim](https://github.com/Civitasv/cmake-tools.nvim)

## Requirements
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [notify-nvim (Optional)](https://github.com/rcarriga/nvim-notify)

## Usage
```lua
require("cmake-kits").setup({
    command = "cmake",
    generator = "Ninja",
    build_directory = "${workspaceFolder}/build/${buildType}",
    compile_commands_path = "${worskpaceFolder}/compile_commands.json",
    configure_commands = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON" }, 
    build_args = {},
    configure_on_open = true,
    configure_on_save = true,
    terminal = {
        toggle = "<C-c>",
        pos = "bottom", --- bottom|center
    },
})
```

## Features
### Variable Substitution
* `${workspaceFolder}` Expands to the project root directory
* `${buildType}` Expands to the current CMake Build Type. Ex: `Debug`, `Release`, `MinSizeRel`, `RelWithDebInfo`

### Local project configuration
cmake-kits uses the same path and syntax as vscode-cmake-tools, `.vscode/settings.json`.

Supported:
* `cmake.configureArgs` Extra arguments to use when configuring
* `cmake.buildArgs` Extra arguments to use when building
* `cmake.sourceDirectory` Directory where cmake will be sourced, root directory will not change

## TODO
- Support more local project configurations settings
    - [x] `cmake.sourceDirectory`
- Add support as a telescope extension
