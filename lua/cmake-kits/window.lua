---@class cmake-kits.WindowConfig
---@field enter boolean jump to window on open
---@field col fun(): number
---@field row fun(): number
---@field width fun(): number
---@field height fun(): number
---@field border string[]

--- @param config cmake-kits.WindowConfig
function ParseWinConfig(config)
    -- if type(config.width) == "string" then
    --     if config.width:sub(config.width:len()) == "%" then
    --         local percentage = tonumber(config.width:sub(1, config.width:len() - 1)) / 100
    --         config.width = function()
    --             return math.floor(vim.o.columns * percentage)
    --         end
    --     end
    -- end
    -- if type(config.height) == "string" then
    --     if config.height:sub(config.height:len()) == "%" then
    --         local percentage = tonumber(config.height:sub(1, config.height:len())) / 100
    --         config.height = math.floor(vim.o.lines * percentage)
    --     end
    -- end
end

local M = {}

--- @param config cmake-kits.WindowConfig
function M:create(buf, config)
    config = config or {}
    local o = {}
    setmetatable(o, self)
    self.__index = self

    ParseWinConfig(config)
    self.buf = buf
    self.config = config
    vim.api.nvim_create_autocmd("WinClosed", {
        buffer = self.buf,
        callback = function()
            self.id = nil
        end,
    })
    return o
end

function M:is_valid()
    return self.id ~= nil and vim.api.nvim_win_is_valid(self.id)
end

function M:open()
    if self.id then
        return
    end
    self.id = vim.api.nvim_open_win(self.buf, self.config.enter, {
        relative = "editor",
        col = self.config.col(),
        row = self.config.row(),
        width = self.config.width(),
        height = self.config.height(),
        border = self.config.border,
        style = "minimal",
    })

    vim.api.nvim_create_autocmd("WinClosed", {
        buffer = self.buf,
        callback = function()
            self.id = nil
        end,
    })
end

function M:close()
    if self.id then
        vim.api.nvim_win_close(self.id, true)
        self.id = nil
    end
end

function M:set_buf(buf)
    self.buf = buf
end

return M
