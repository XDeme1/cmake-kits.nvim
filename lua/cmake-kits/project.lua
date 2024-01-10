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
    path = path:gsub("${buildType}", M.state.build_type)
    return path
end

M.clear_state = function()
    if M.file_watcher then
        M.file_watcher:close()
        M.file_watcher = nil
    end
    M.root_dir = nil
    M.config = {}
    M.state = {
        build_type = "Debug",
        selected_kit = {
            name = "Unspecified",
        },

        build_targets = {},
        selected_build = {
            name = "all",
        },

        runnable_targets = {},
        selected_runnable = nil,
    }
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

M.load_local_config = function(path)
    local local_config = utils.load_data(path, { skip_comments = true })
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
        return
    end

    M.root_dir = dir
    local local_config_dir = Path:new(dir) / ".vscode"
    local path = local_config_dir / "settings.json"
    local path_str = tostring(path)

    if path:exists() then
        M.load_local_config(path_str)
    end
    M.load_project()

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
    local json =
        utils.load_data(vim.fs.joinpath(vim.fn.stdpath("data"), "cmake-kits-projects.json"))
    if
        not json.projects
        or not json.projects[M.root_dir]
        or vim.tbl_isempty(json.projects[M.root_dir])
    then
        return
    end
    M.state = json.projects[M.root_dir]
    if config.configure_on_open then
        vim.api.nvim_command("CmakeConfigure")
    end
end

M.save_project = function()
    local save_data = {
        projects = {
            [M.root_dir] = M.state,
        },
    }
    utils.save_data(
        vim.fs.joinpath(vim.fn.stdpath("data"), "cmake-kits-projects.json"),
        save_data,
        true
    )
end

M.get_build_type = function()
    return M.state.build_type
end

M.get_build_targets = function()
    return M.state.build_targets
end

M.get_runnable_targets = function()
    return M.state.runnable_targets
end

M.get_selected_build = function()
    return M.state.selected_build
end

M.get_selected_runnable = function()
    return M.state.selected_runnable
end

M.get_selected_kit = function()
    return M.state.selected_kit
end

M.clear_state()

return M
