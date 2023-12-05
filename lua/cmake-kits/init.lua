local config = require("cmake-kits.config")
local project = require("cmake-kits.project")
local kits = require("cmake-kits.kits")
local commands = require("cmake-kits.commands")
local terminal = require("cmake-kits.terminal")

local M = {}

--- @type cmake-kits.SetupConfig
local default = {
    terminal = {
        toggle = "<C-c>",
        pos = "bottom",
    },
}

--- @param opts cmake-kits.SetupConfig
M.setup = function(opts)
    opts = opts or {}
    opts = vim.tbl_deep_extend("keep", opts, default, config)

    kits.load_kits()
    M._setup_autocmds(opts)
    M._setup_terminal(opts)
    vim.tbl_extend("force", config, opts)
end

function M._setup_autocmds(opts)
    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = vim.api.nvim_create_augroup("CmakeSaveKits", {}),
        callback = function()
            kits.save_kits()
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

function M._setup_terminal(opts)
    terminal.setup(opts)

    vim.keymap.set("n", opts.terminal.toggle, function()
        if project.root_dir then
            terminal.toggle()
            terminal.scroll_end()
        end
    end, {})
end

return M
