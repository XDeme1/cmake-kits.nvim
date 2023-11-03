local M = {}

function M.active_job(title)
    vim.notify("You must wait for a command to finish before you use this command", vim.log.levels.ERROR, {
        title = title,
        on_open = function(win)
            vim.api.nvim_win_set_config(win, { focusable = false })
        end
    })
end

function M.configuration_error(message)
    vim.notify(message, vim.log.levels.ERROR, {
        title = "Configuration error",
        on_open = function(win)
            vim.api.nvim_win_set_config(win, { focusable = false })
        end
    })
end

function M.build_error(message)
    vim.notify(message, vim.log.levels.ERROR, {
        title = "Build error",
        on_open = function(win)
            vim.api.nvim_win_set_config(win, { focusable = false })
        end
    })
end

function M.run_error(message)
    vim.notify(message, vim.log.levels.ERROR, {
        title = "Run error",
        on_open = function(win)
            vim.api.nvim_win_set_config(win, { focusable = false })
        end
    })
end

return M
