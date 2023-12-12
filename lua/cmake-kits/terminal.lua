local win = require("cmake-kits.window")
local border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
local default_styles = {
    center = {
        row = function()
            return math.floor(vim.o.lines * (1 / 5))
        end,
        col = function()
            return math.floor(vim.o.columns * (1 / 5))
        end,
        height = function()
            return 22
        end,
        width = function()
            return math.floor(vim.o.columns * (1 / 1.5))
        end,
        border = border,
    },
    bottom = {
        row = function()
            return vim.o.lines - vim.o.cmdheight - 15
        end,
        col = function()
            return 0
        end,
        height = function()
            return 13
        end,
        width = function()
            return vim.o.columns - 2
        end,
        border = border,
    },
}

local terminal_state = {
    buf_id = nil,
    window = nil,
    pos = "bottom",
    styles = default_styles,
}

local M = {}

function M.setup(opts)
    opts.terminal = opts.terminal or {}
    M.create_buffer()
    if opts.terminal.styles then
        terminal_state.styles =
            vim.tbl_deep_extend("force", terminal_state.styles, opts.terminal.styles)
    end

    terminal_state.pos = opts.terminal.pos or "bottom"
    terminal_state.window = win:create(terminal_state.buf_id, {
        enter = true,
        col = terminal_state.styles[terminal_state.pos].col(),
        row = terminal_state.styles[terminal_state.pos].row(),
        height = terminal_state.styles[terminal_state.pos].height(),
        width = terminal_state.styles[terminal_state.pos].width(),
        border = terminal_state.styles[terminal_state.pos].border,
    })
end

function M.toggle()
    if terminal_state.window:is_valid() then
        terminal_state.window:close()
    else
        terminal_state.window:open()
    end
end

--- @param line string
function M.send_data(line)
    vim.bo[terminal_state.buf_id].modifiable = true
    vim.api.nvim_buf_set_lines(terminal_state.buf_id, -1, -1, true, { line })
    vim.bo[terminal_state.buf_id].modified = false
    vim.bo[terminal_state.buf_id].modifiable = false
end

function M.clear()
    local is_closed = not terminal_state.window:is_valid()
    if not is_closed then
        terminal_state.window:close()
    end
    vim.api.nvim_buf_delete(terminal_state.buf_id, {
        force = true,
    })
    M.create_buffer()
    terminal_state.window:set_buf(terminal_state.buf_id)
    if not is_closed then
        terminal_state.window:open()
    end
end

function M.create_buffer()
    terminal_state.buf_id = vim.api.nvim_create_buf(false, true)
    vim.bo[terminal_state.buf_id].filetype = "cmake-kits-terminal"
    vim.bo[terminal_state.buf_id].modifiable = false
end

function M.set_position(pos)
    terminal_state.pos = pos
    if terminal_state.window:is_valid() then
        terminal_state.window:close()
        terminal_state.window:open()
    end
end

return M
