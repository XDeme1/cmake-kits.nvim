local config = require("cmake-kits.config")
local project = require("cmake-kits.project")
local kits = require("cmake-kits.kits")
local commands = require("cmake-kits.commands")
local terminal = require("cmake-kits.terminal")

--- @class cmake-kits.WindowStyle
--- @field row fun(): integer
--- @field col fun(): integer
--- @field width fun(): integer
--- @field height fun(): integer
--- @field border string[]

--- @class cmake-kits.WindowSettings
--- @field toggle string?
--- @field pos "bottom"|"center"
--- @field styles cmake-kits.WindowStyle
--- @field background string?
--- @field foreground string?

--- @class cmake-kits.SetupConfig : cmake-kits.CmakeConfig
--- @field configure_on_open boolean Automatic configuration of project. auto_root is required for this to work properly.
--- @field configure_on_save boolean Automatic configuration of project on CMakeLists.txt file save
--- @field terminal cmake-kits.WindowSettings?

local M = {}

--- @type cmake-kits.SetupConfig
local default = {
    configure_on_open = true,
    configure_on_save = true,
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
