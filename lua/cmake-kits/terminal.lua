local terminal_state = {
    buf_id = nil,
    win_id = nil,
}

local M = {}

function M.toggle()
    if not terminal_state.win_id then
        M.create_window()
    else
        vim.api.nvim_win_close(terminal_state.win_id, true)
        terminal_state.win_id = nil
    end
end

--- @param line string
function M.send_data(line)
    vim.bo[terminal_state.buf_id].modifiable = true
    vim.api.nvim_buf_set_lines(terminal_state.buf_id, -1, -1, true, { line })
    vim.fn.win_execute(terminal_state.win_id, "norm G")
    vim.bo[terminal_state.buf_id].modified = false
    vim.bo[terminal_state.buf_id].modifiable = false
end

function M.clear()
    local is_closed = terminal_state.win_id == nil
    if not is_closed then
        vim.api.nvim_win_close(terminal_state.win_id, true)
        terminal_state.win_id = nil
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
    terminal_state.win_id = vim.api.nvim_open_win(terminal_state.buf_id, false, {
        relative = "editor",
        row = 1000,
        col = 0,
        width = 2000,
        height = 10,
        title = "CMake Output",
        title_pos = "left",
        style = "minimal",
        border = { "═", "═", "═", "", "", "", "", "" },
    })
    vim.api.nvim_create_autocmd("WinClosed", {
        buffer = terminal_state.buf_id,
        callback = function()
            terminal_state.win_id = nil
        end
    })
end

M.create_buffer()

return M
