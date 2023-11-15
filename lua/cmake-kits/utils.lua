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

--- @param path string
M.get_cmake_root = function(path)
    local found = vim.fs.find("CMakeLists.txt", {
        limit = math.huge,
        upward = true,
        path = path,
    })
    return vim.fs.dirname(found[#found])
end

return M
