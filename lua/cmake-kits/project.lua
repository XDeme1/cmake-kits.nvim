local config = require("cmake-kits.config")
local Path = require("plenary.path")
local utils = require("cmake-kits.utils")
local watcher = require("cmake-kits.file_watcher")

--- @class cmake-kits.ProjectState
local M = {
    --- @type uv.uv_fs_event_t|nil
    file_watcher = nil,
    --- @type cmake-kits.CmakeConfigLocal|{}
    config = {},
}

--- Used to substitute ${workspaceFolder} and ${buildType} with the correct string
--- @param path string
M.interpolate_string = function(path)
    path = path:gsub("${workspaceFolder}", M.root_dir)
    path = path:gsub("${buildType}", M.build_type)
    return path
end

M.clear_state = function()
    if M.file_watcher then
        M.file_watcher:close()
        M.file_watcher = nil
    end
    M.root_dir = nil
    M.config = {}
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

M.load_local_config = function(path)
    local local_config = utils.load_data(path)
    if local_config["cmake.sourceDirectory"] then
        M.config.source_directory = M.interpolate_string(local_config["cmake.sourceDirectory"])
    else
        M.config.source_directory = nil
    end
    M.config.configure_args = local_config["cmake.configureArgs"]
    M.config.build_args = local_config["cmake.buildArgs"]
end

M.set_root_dir = function(dir)
    if dir == M.root_dir then
        return
    end
    if M.root_dir then
        M.save_project()
        M.clear_state()
    end
    if dir == nil then
        M.root_dir = nil
        return
    end

    M.root_dir = dir
    M.load_project()
    local local_config_dir = Path:new(dir) / ".vscode"
    local path = local_config_dir / "settings.json"
    local path_str = tostring(path)

    if path:exists() then
        M.load_local_config(path_str)
    end

    local defer = nil
    M.file_watcher = watcher.watch(tostring(local_config_dir), {
        callback = function(filename, _)
            if filename ~= "settings.json" then
                return
            end
            if not defer then
                defer = vim.defer_fn(function()
                    defer = nil
                    M.load_local_config(path_str)
                end, 200)
            end
        end,
    })
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
