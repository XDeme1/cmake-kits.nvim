local win = require("cmake-kits.window")

local terminal_state = {
    buf_id = nil,
    win = {
        id = nil,
        pos = "bottom",
        styles = {
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
                border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
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
                border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
            },
        },
        background = nil,
        foreground = nil,
    },
    hl_ns = vim.api.nvim_create_namespace("CmakekitsTerminal"),
}

local M = {}

function M.setup(opts)
    M.create_buffer()
    opts = opts or {}
    opts.terminal = opts.terminal or {}
    if opts.terminal.styles then
        terminal_state.win.styles =
            vim.tbl_deep_extend("force", terminal_state.win.styles, opts.terminal.styles)
    end

    terminal_state.win.pos = opts.terminal.pos or terminal_state.win.pos
end

function M.open()
    terminal_state.win.id = win.create(terminal_state.buf_id, {
        enter = true,
        col = terminal_state.win.styles[terminal_state.win.pos].col(),
        row = terminal_state.win.styles[terminal_state.win.pos].row(),
        height = terminal_state.win.styles[terminal_state.win.pos].height(),
        width = terminal_state.win.styles[terminal_state.win.pos].width(),
        border = terminal_state.win.styles[terminal_state.win.pos].border,
    })

    vim.api.nvim_create_autocmd("WinClosed", {
        buffer = terminal_state.buf_id,
        callback = function()
            terminal_state.win.id = nil
        end,
    })

    --- TODO: Neovide doesnt auto resize float window
    if vim.g.neovide then
        vim.api.nvim_create_autocmd("WinResized", {
            callback = function()
                if terminal_state.win.id then
                    vim.api.nvim_win_set_config(terminal_state.win.id, {
                        relative = "editor",
                        col = terminal_state.win.styles[terminal_state.win.pos].col(),
                        row = terminal_state.win.styles[terminal_state.win.pos].row(),
                        height = terminal_state.win.styles[terminal_state.win.pos].height(),
                        width = terminal_state.win.styles[terminal_state.win.pos].width(),
                    })
                end
            end,
        })
    end
end

function M.close()
    vim.api.nvim_win_close(terminal_state.win.id, true)
    terminal_state.win.id = nil
end

function M.toggle()
    if win.is_valid(terminal_state.win.id) then
        M.close()
    else
        M.open()
    end
end

function M.scroll_end()
    if win.is_valid(terminal_state.win.id) then
        vim.fn.win_execute(terminal_state.win.id, "norm G")
    end
end

--- @param line string
function M.send_data(line)
    vim.bo[terminal_state.buf_id].modifiable = true
    vim.api.nvim_buf_set_lines(terminal_state.buf_id, -1, -1, true, { line })
    vim.fn.win_execute(terminal_state.win.id, "norm G")
    vim.bo[terminal_state.buf_id].modified = false
    vim.bo[terminal_state.buf_id].modifiable = false
end

function M.clear()
    local is_closed = not win.is_valid(terminal_state.win.id)
    if not is_closed then
        vim.api.nvim_win_close(terminal_state.win.id, true)
        terminal_state.win.id = nil
    end
    vim.api.nvim_buf_delete(terminal_state.buf_id, {
        force = true,
    })
    M.create_buffer()
    if not is_closed then
        M.create_window()
    end
end

function M.create_buffer()
    terminal_state.buf_id = vim.api.nvim_create_buf(false, true)
    vim.bo[terminal_state.buf_id].filetype = "cmake-kits-terminal"
    vim.bo[terminal_state.buf_id].modifiable = false
end

function M.set_position(pos)
    terminal_state.win.pos = pos
    if win.is_valid(terminal_state.win.id) then
        vim.api.nvim_win_close(terminal_state.win.id, true)
        M.create_window()
    end
end

function M.update_size(width, height)
    terminal_state.win.styles.bottom.width = width
    terminal_state.win.styles.bottom.height = height
end

return M
