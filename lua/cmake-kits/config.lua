---@alias Generator "Ninja" | "Ninja Multi-Config" | "Unix Makefiles"

--- @class cmake-kits.CmakeConfig
--- @field command string Path of the cmake executable.
--- @field generator Generator Generator to use to build the project.
--- @field build_directory string Path where cmake will build the project.
--- @field compile_commands_path string? Path where compile_commands.json will be copied to.
--- @field configure_args string[] Arguments that will be passed when configuring the project.
--- @field build_args string[] Arguments that will be passed when building the specified target.
--- @field configure_on_open boolean
local M = {}

M.command = "cmake"
M.generator = "Ninja"

M.build_directory = "build/${buildType}"

M.compile_commands_path = "${workspaceFolder}"

M.configure_args = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON" }
M.build_args = {}

M.configure_on_open = true

return M
