--- @type cmake-kits.CmakeConfig
local M = {
    command = "cmake",
    generator = "Ninja",

    configure_on_open = true,
    configure_on_save = true,

    build_directory = "${workspaceFolder}/build/${buildType}",
    compile_commands_path = "${workspaceFolder}/compile_commands.json",

    configure_args = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON" },
    build_args = {},
}

return M

--- Defaults
--- M.command = "cmake"
--- M.generator = "Ninja"

--- M.configure_on_open = true
--- M.configure_on_save = true

--- M.build_directory = "${workspaceFolder}/build/${buildType}"

--- M.compile_commands_path = "${workspaceFolder}/compile_commands.json"

--- M.configure_args = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON" }
--- M.build_args = {}
