local kits = require("cmake-kits.kits")
local Path = require("plenary.path")

--- @alias cmake-kits.BuildVariant "Debug" | "Release" | "MinSizeRel" | "RelWithDebInfo"
--- @alias cmake-kits.TargetType "EXECUTABLE" | "STATIC_LIBRARY"

--- @class cmake-kits.Compilers
--- @field C string?
--- @field CXX string?

---@class cmake-kits.Target
---@field name string
---@field full_path string
---@field type cmake-kits.TargetType

--- @class cmake-kits.ProjectState Table holding the state of the cmake project
--- @field root_dir string? Path to the root project
--- @field build_type cmake-kits.BuildVariant
---
--- @field build_targets cmake-kits.Target[]
--- @field selected_build cmake-kits.Target?
---
--- @field runnable_targets cmake-kits.Target[]
--- @field selected_runnable cmake-kits.Target?
local M = {}

M.root_dir = nil
M.build_type = "Debug"

M.build_targets = {}
M.selected_build = nil

M.runnable_targets = {}
M.selected_runnable = nil

--- Used to substitute ${workspaceFolder} and ${buildType} with the correct string
--- @param path string
M.interpolate_string = function(path)
    path = path:gsub("${workspaceFolder}", M.root_dir)
    path = path:gsub("${buildType}", M.build_type)
    return path
end

M.change_root_dir = function(dir)
    local cmake_file = Path:new(dir) / "CMakeLists.txt"
    if not cmake_file:exists() then
        vim.notify(dir .. " is not a valid cmake root dir", vim.log.levels.ERROR, nil)
        return
    end
    M.root_dir = dir
    M.load_project()
end

M.select_build_type = function()
    vim.ui.select({ "Debug", "Release", "MinSizeRel", "RelWithDebInfo" }, {
        prompt = "Select a build type",
    }, function(choice)
        if choice == nil then
            return
        end
        M.build_type = choice
    end)
end

M.load_project = function()
    local save_path = vim.fs.joinpath(vim.fn.stdpath("data"), "cmake-kits-projects.json")

    local file = io.open(save_path, "r")
    local json = nil
    if file then
        json = vim.json.decode(file:read("*a"))
        if json.projects[M.root_dir] then
            for key, value in pairs(json.projects[M.root_dir]) do
                M[key] = value
            end
        end
        file:close()
    end
end

M.save_project = function()
    local save_path = vim.fs.joinpath(vim.fn.stdpath("data"), "cmake-kits-projects.json")
    local save_data = {
        projects = {
            [M.root_dir] = {
                build_type = M.build_type,
                build_targets = M.build_targets,
                runnable_targets = M.runnable_targets,
                selected_build = M.selected_build,
                selected_runnable = M.selected_runnable,
                selected_kit = kits.selected_kit,
            }
        }
    }

    local old_file = io.open(save_path, "r")
    local json = nil
    if old_file then
        json = vim.json.decode(old_file:read("*a"))
        for key, value in pairs(save_data.projects[M.root_dir]) do
            json.projects[M.root_dir][key] = value
        end
        old_file:close()
    end

    local file = io.open(save_path, "w+")
    if file then
        if json then
            file:write(vim.json.encode(json))
        else
            file:write(vim.json.encode(save_data))
        end
        file:close()
    end
end
return M
