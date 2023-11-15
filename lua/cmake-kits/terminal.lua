local terminal_state = {
    buf_id = nil,
    win_id = nil,
    window = {
        id = nil,
        hightlight_ns = vim.api.nvim_create_namespace("CmakekitsTerminal"),
        background = nil,
        foreground = nil,
        title = {
            text = nil,
            pos = nil,
            background = nil,
            foreground = nil,
        },
        border = {
            background = nil,
            foreground = nil,
        },
    },
}

local M = {}

function M.toggle()
    if not terminal_state.window.id then
        M.create_window()
    else
        vim.api.nvim_win_close(terminal_state.window.id, true)
        terminal_state.window.id = nil
    end
end

--- @param line string
function M.send_data(line)
    vim.bo[terminal_state.buf_id].modifiable = true
    vim.api.nvim_buf_set_lines(terminal_state.buf_id, -1, -1, true, { line })
    vim.fn.win_execute(terminal_state.window.id, "norm G")
    vim.bo[terminal_state.buf_id].modified = false
    vim.bo[terminal_state.buf_id].modifiable = false
end

function M.clear()
    local is_closed = terminal_state.window.id == nil
    if not is_closed then
        vim.api.nvim_win_close(terminal_state.window.id, true)
        terminal_state.window.id = nil
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
    terminal_state.window.id = vim.api.nvim_open_win(terminal_state.buf_id, false, {
        relative = "editor",
        row = 1000,
        col = 0,
        width = 2000,
        height = 10,
        title = terminal_state.window.title.text,
        title_pos = terminal_state.window.title.pos,
        style = "minimal",
        border = { "═", "═", "═", "", "", "", "", "" },
    })
    vim.api.nvim_win_set_hl_ns(terminal_state.window.id, terminal_state.window.hightlight_ns)

    M.set_title_colors(
        terminal_state.window.title.background,
        terminal_state.window.title.foreground
    )
    M.set_border_colors(
        terminal_state.window.border.background,
        terminal_state.window.border.foreground
    )
    M.set_window_colors(terminal_state.window.background, terminal_state.window.foreground)

    vim.api.nvim_create_autocmd("WinClosed", {
        buffer = terminal_state.buf_id,
        callback = function()
            terminal_state.window.id = nil
        end,
    })
end

function M.set_window_colors(bg, fg)
    if bg then
        terminal_state.window.background = bg
    end
    if fg then
        terminal_state.window.foreground = fg
    end
    vim.api.nvim_set_hl(
        terminal_state.window.hightlight_ns,
        "NormalFloat",
        { bg = terminal_state.window.background, fg = terminal_state.window.foreground }
    )
    vim.api.nvim_set_hl(
        terminal_state.window.hightlight_ns,
        "EndOfBuffer",
        { bg = terminal_state.window.background, fg = terminal_state.window.foreground }
    )
end

function M.set_title_colors(bg, fg)
    if bg then
        terminal_state.window.title.background = bg
    end
    if fg then
        terminal_state.window.title.foreground = fg
    end
    vim.api.nvim_set_hl(
        terminal_state.window.hightlight_ns,
        "FloatTitle",
        { bg = terminal_state.window.title.background, fg = terminal_state.window.title.foreground }
    )
end

function M.set_border_colors(bg, fg)
    if bg then
        terminal_state.window.border.background = bg
    end
    if fg then
        terminal_state.window.border.foreground = fg
    end
    vim.api.nvim_set_hl(
        terminal_state.window.hightlight_ns,
        "FloatBorder",
        {
            bg = terminal_state.window.border.background,
            fg = terminal_state.window.border.foreground,
        }
    )
end

function M.set_title(text, pos)
    if text then
        terminal_state.window.title.text = text
    end
    if pos and terminal_state.window.title.text then
        terminal_state.window.title.pos = pos
    else
        terminal_state.window.title.pos = nil
    end
    if terminal_state.window.id then
        vim.api.nvim_win_set_config(terminal_state.window.id, {
            title = terminal_state.window.title.text,
            title_pos = terminal_state.window.title.pos,
        })
    end
end

M.create_buffer()

return M
