local scan = require("plenary.scandir")
local Path = require("plenary.path")
local config = require("cmake-kits.config")

local M = {}

--- TODO: Add a config of preferred list of konsoles
--- @return string command, string[] args argument necessary to make the console execute commands
M.get_external_terminal = function()
    if vim.fn.executable("konsole") then
        return "konsole", { "-e" }
    elseif vim.fn.executable("gnome-terminal") then
        return "gnome-terminal", { "--" }
    end
end

--- Checks if a CMakeLists.txt is present
--- @param path string
--- @param depth integer?
--- @return boolean
M.is_cmake_project = function(path, depth)
    depth = depth or 2
    local found =
        scan.scan_dir(path, { hidden = false, depth = depth, search_pattern = "CMakeLists.txt" })
    return not vim.tbl_isempty(found)
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

--- @param path string
--- @return table
M.load_data = function(path)
    local fd = io.open(path, "r")
    local data = {}
    if fd then
        data = vim.json.decode(fd:read("*a"))
        fd:close()
    end
    return data
end

--- @param path string
--- @param data table
--- @param update boolean modifies data already written && save new data.
M.save_data = function(path, data, update)
    local old_data = {}
    if update then
        local fd = io.open(path, "r")
        if fd then
            old_data = vim.json.decode(fd:read("*a"))
            fd:close()
        end
    end
    local fd = io.open(path, "w+")
    if fd then
        local new_data = vim.tbl_deep_extend("force", old_data, data)
        fd:write(vim.json.encode(new_data))
        fd:close()
    end
end

M.notify = function(title, message, log_level)
    log_level = log_level or vim.log.levels.ERROR
    vim.notify(message, log_level, {
        title = title,
        on_open = function(win)
            vim.api.nvim_win_set_config(win, { focusable = false })
        end,
    })
end

return M
