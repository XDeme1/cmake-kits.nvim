---@class cmake-kits.WindowConfig
---@field enter boolean jump to window on open
---@field col number
---@field row number
---@field width integer|string|
---@field height integer|string
---@field border string[]

local M = {}

--- @param config cmake-kits.WindowConfig
function M.create(buf, config)
    config = config or {}
    if type(config.width) == "string" then
        if config.width:sub(config.width:len()) == "%" then
            local percentage = tonumber(config.width:sub(1, config.width:len() - 1)) / 100
            config.width = math.floor(vim.o.columns * percentage)
        end
    end
    if type(config.height) == "string" then
        if config.height:sub(config.height:len()) == "%" then
            local percentage = tonumber(config.height:sub(1, config.height:len())) / 100
            config.height = math.floor(vim.o.lines * percentage)
        end
    end
    local win_id = vim.api.nvim_open_win(buf, config.enter, {
        relative = "editor",
        col = config.col or 0,
        row = config.row or 0,
        width = config.width,
        height = config.height,
        border = config.border,
        style = "minimal",
    })
    return win_id
end

M.is_valid = function(handle)
    return handle ~= nil and vim.api.nvim_win_is_valid(handle)
end

return M
