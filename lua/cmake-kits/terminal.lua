local terminal_state = {
    buf_id = nil,
    win = {
        id = nil,
        pos = "bottom",
        styles = {
            ["center"] = {
                row = math.floor(vim.o.lines * (1 / 5)),
                col = math.floor(vim.o.columns * (1 / 5)),
                height = 22,
                width = math.floor(vim.o.columns * (1 / 1.5)),
            },
            ["bottom"] = {
                row = vim.o.lines - 15,
                col = 0,
                height = 13,
                width = vim.o.columns - 2,
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
    terminal_state.win.background = opts.terminal.background
    terminal_state.win.foreground = opts.terminal.foreground
end

function M.toggle()
    if not terminal_state.win.id then
        M.create_window()
    else
        vim.api.nvim_win_close(terminal_state.win.id, true)
        terminal_state.win.id = nil
    end
end

function M.scroll_end()
    if not terminal_state.win.id then
        return
    end
    vim.fn.win_execute(terminal_state.win.id, "norm G")
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
    local is_closed = terminal_state.win.id == nil
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

function M.create_window()
    terminal_state.win.id = vim.api.nvim_open_win(terminal_state.buf_id, true, {
        relative = "editor",
        row = terminal_state.win.styles[terminal_state.win.pos].row,
        col = terminal_state.win.styles[terminal_state.win.pos].col,
        width = terminal_state.win.styles[terminal_state.win.pos].width,
        height = terminal_state.win.styles[terminal_state.win.pos].height,
        style = "minimal",
        border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
    })

    vim.api.nvim_win_set_hl_ns(terminal_state.win.id, terminal_state.hl_ns)
    vim.api.nvim_set_hl(terminal_state.hl_ns, "NormalFloat", {
        bg = terminal_state.win.background,
        fg = terminal_state.win.foreground,
    })
    vim.api.nvim_set_hl(
        terminal_state.hl_ns,
        "EndOfBuffer",
        { bg = terminal_state.win.background, fg = terminal_state.win.foreground }
    )

    vim.api.nvim_create_autocmd("WinClosed", {
        buffer = terminal_state.buf_id,
        callback = function()
            terminal_state.win.id = nil
        end,
    })
end

function M.set_position(pos)
    terminal_state.win.pos = pos
    if terminal_state.win.id then
        vim.api.nvim_win_close(terminal_state.win.id, true)
        M.create_window()
    end
end

return M
