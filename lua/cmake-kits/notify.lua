local M = {}

function M.active_job(title)
    vim.notify(
        "You must wait for a command to finish before you use this command",
        vim.log.levels.ERROR,
        {
            title = title,
            on_open = function(win)
                vim.api.nvim_win_set_config(win, { focusable = false })
            end,
        }
    )
end

function M.configuration(message, log_level)
    vim.notify(message, log_level, {
        title = "Configuration",
        on_open = function(win)
            vim.api.nvim_win_set_config(win, { focusable = false })
        end,
    })
end

function M.build(message, log_level)
    vim.notify(message, log_level, {
        title = "Build",
        on_open = function(win)
            vim.api.nvim_win_set_config(win, { focusable = false })
        end,
    })
end

function M.run(message, log_level)
    vim.notify(message, log_level, {
        title = "Run",
        on_open = function(win)
            vim.api.nvim_win_set_config(win, { focusable = false })
        end,
    })
end

return M
