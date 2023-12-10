local config = require("cmake-kits.config")
local project = require("cmake-kits.project")
local kits = require("cmake-kits.kits")
local commands = require("cmake-kits.commands")
local terminal = require("cmake-kits.terminal")
local utils = require("cmake-kits.utils")

local M = {}

--- @param opts cmake-kits.SetupConfig
M.setup = function(opts)
    opts = opts or {}
    M._setup_autocmds(opts)
    terminal.setup(opts)

    for k, _ in pairs(config) do
        if opts[k] then
            config[k] = opts[k]
        end
    end

    kits.kits = utils.load_data(kits.save_path)

    if opts.terminal.toggle then
        vim.keymap.set("n", opts.terminal.toggle, function()
            if project.root_dir then
                terminal.toggle()
                terminal.scroll_end()
            end
        end, {})
    end
end

function M._setup_autocmds(opts)
    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = vim.api.nvim_create_augroup("CmakeSaveKits", {}),
        callback = function()
            utils.save_data(M.save_path, M.kits, true)
            if project.root_dir then
                project.save_project()
            end
        end,
    })

    vim.api.nvim_create_autocmd("DirChanged", {
        callback = function(ev)
            if ev.file ~= project.root_dir then
                project.set_root_dir(nil)
            end
        end,
    })

    if opts.configure_on_save then
        vim.api.nvim_create_autocmd("BufWritePost", {
            group = vim.api.nvim_create_augroup("CmakeConfigOnSave", {}),
            pattern = { "CMakeLists.txt" },
            callback = function()
                if commands.active_job then
                    return
                end
                commands.configure()
            end,
        })
    end
end

return M
