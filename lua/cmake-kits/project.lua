local config = require("cmake-kits.config")
local kits = require("cmake-kits.kits")
local Path = require("plenary.path")

--- @alias cmake-kits.BuildVariant "Debug" | "Release" | "MinSizeRel" | "RelWithDebInfo"
--- @alias cmake-kits.TargetType "EXECUTABLE" | "STATIC_LIBRARY"

--- @class cmake-kits.Compilers
--- @field C string?
--- @field CXX string?

---@class cmake-kits.Target
---@field name string
---@field full_path string?
---@field type cmake-kits.TargetType?

--- @class cmake-kits.ProjectState Table holding the state of the cmake project
--- @field root_dir string? Path to the root project
--- @field build_type cmake-kits.BuildVariant
--- @field selected_kit cmake-kits.Kit
---
--- @field build_targets cmake-kits.Target[]
--- @field selected_build cmake-kits.Target
---
--- @field runnable_targets cmake-kits.Target[]
--- @field selected_runnable cmake-kits.Target?
local M = {}

--- Used to substitute ${workspaceFolder} and ${buildType} with the correct string
--- @param path string
M.interpolate_string = function(path)
    path = path:gsub("${workspaceFolder}", M.root_dir)
    path = path:gsub("${buildType}", M.build_type)
    return path
end

M.clear_state = function()
    M.root_dir = nil
    M.build_type = "Debug"
    M.selected_kit = {
        name = "Unspecified",
    }

    M.build_targets = {}
    M.selected_build = {
        name = "all",
    }

    M.runnable_targets = {}
    M.selected_runnable = nil
end

--- @return boolean
M.has_ctest = function()
    if not M.root_dir then
        return false
    end
    local ctest_path = Path:new(M.interpolate_string(config.build_directory))
        / "CTestTestfile.cmake"
    if ctest_path:exists() then
        return true
    end
    return false
end

M.change_root_dir = function(dir)
    if dir == nil then
        M.root_dir = dir
        return
    end
    local cmake_file = Path:new(dir) / "CMakeLists.txt"
    if not cmake_file:exists() then
        vim.notify(dir .. " is not a valid cmake root dir", vim.log.levels.ERROR, nil)
        return
    end
    M.root_dir = dir
end

--- @param on_select fun(selected: cmake-kits.BuildVariant)?
M.select_build_type = function(on_select)
    vim.ui.select({ "Debug", "Release", "MinSizeRel", "RelWithDebInfo" }, {
        prompt = "Select a build type",
    }, function(choice)
        if choice == nil then
            return
        end
        M.build_type = choice
        if type(on_select) == "function" then
            on_select(choice)
        end
    end)
end

--- @param on_select fun(selected: cmake-kits.Target)?
M.select_build_target = function(on_select)
    vim.ui.select(M.build_targets, {
        prompt = "Select build target",
        format_item = function(target)
            return target.name
        end,
    }, function(choice)
        if choice == nil then
            return
        end
        M.selected_build = choice
        if type(on_select) == "function" then
            on_select(choice)
        end
    end)
end

--- @param on_select fun(selected: cmake-kits.Target)?
M.select_runnable_target = function(on_select)
    vim.ui.select(M.runnable_targets, {
        prompt = "Select a target to run",
        format_item = function(target)
            return target.name
        end,
    }, function(choice)
        if choice == nil then
            return
        end
        M.selected_runnable = choice
        if type(on_select) == "function" then
            on_select(choice)
        end
    end)
end

--- @param on_select fun(selected: cmake-kits.Kit)?
M.select_kit = function(on_select)
    local items = {
        { id = -1, name = "Scan for kits" },
        { id = 0, name = "Unspecified (Let CMake decide)" },
    }
    for i, kit in ipairs(kits.kits) do
        table.insert(items, { id = i, name = kit.name })
    end
    vim.ui.select(items, {
        prompt = "Select a kit",
        format_item = function(item)
            return item.name
        end,
    }, function(choice)
        if choice == nil then
            return
        elseif choice.id == -1 then
            kits.scan_for_kits()
            return
        elseif choice.id == 0 then
            M.selected_kit = {
                name = "Unspecified",
            }
            return
        end
        M.selected_kit = kits.kits[choice.id]
        if type(on_select) == "function" then
            on_select(choice)
        end
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
                selected_kit = M.selected_kit,
            },
        },
    }

    local old_file = io.open(save_path, "r")
    local json = nil
    if old_file then
        json = vim.json.decode(old_file:read("*a"))
        json.projects[M.root_dir] = save_data.projects[M.root_dir]
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

M.clear_state()

return M
