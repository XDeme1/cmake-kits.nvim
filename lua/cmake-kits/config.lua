--- @type cmake-kits.CmakeConfig
local M = {
    command = "cmake",
    generator = "Ninja",

    build_directory = "${workspaceFolder}/build/${buildType}",
    compile_commands_path = "${workspaceFolder}/compile_commands.json",

    configure_args = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON" },
    build_args = {},
}

return M

--- Defaults
--- .command = "cmake"
--- M.generator = "Ninja"

--- M.build_directory = "${workspaceFolder}/build/${buildType}"

--- M.compile_commands_path = "${workspaceFolder}/compile_commands.json"

--- M.configure_args = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON" }
--- M.build_args = {}
