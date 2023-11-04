local project = require("cmake-kits.project")
local config = require("cmake-kits.config")
local commands = require("cmake-kits.commands")
local utils = require("cmake-kits.utils")
local terminal = require("cmake-kits.terminal")

--- @class cmake-kits.SetupConfig : cmake-kits.CmakeConfig
--- @field auto_root boolean Automatic detection and setting of root_dir.
--- @field on_root_change (fun(dir: string): nil)? Event called when root_dir changes.
--- @field configure_on_open boolean Automatic configuration of project. auto_root is required for this to work properly.
--- @field configure_on_save boolean Automatic configuration of project on CMakeLists.txt file save

local M = {}

--- @type cmake-kits.SetupConfig
local default = {
    auto_root = true,
    on_root_change = nil,
    configure_on_open = true,
    configure_on_save = true,
    terminal = {
        toggle = "<F1>"
    }
}

--- @param opts cmake-kits.SetupConfig
M.setup = function(opts)
    opts = opts or {}
    opts = vim.tbl_deep_extend("keep", opts, default, config)

    if opts.configure_on_save then
        vim.api.nvim_create_autocmd("BufWritePost", {
            group = vim.api.nvim_create_augroup("CmakeConfigOnSave", {}),
            pattern = { "CMakeLists.txt" },
            callback = function()
                if commands.active_job then
                    return
                end
                commands.configure()
            end
        })
    end

    vim.api.nvim_create_autocmd("DirChanged", {
        group = vim.api.nvim_create_augroup("CmakeAuto", {}),
        callback = function(ev)
            local root_dir = utils.get_cmake_root(ev.file)
            if root_dir == project.root_dir then
                return
            end
            if root_dir == nil then
                project.save_project()
            end
            if opts.auto_root then
                project.change_root_dir(root_dir)
                project.load_project()
                if opts.on_root_change then
                    opts.on_root_change(project.root_dir)
                end
            end
        end
    })

    if opts.configure_on_open then
        vim.api.nvim_create_autocmd("DirChanged", {
            group = vim.api.nvim_create_augroup("CmakeConfigOnOpen", {}),
            callback = function()
                if project.root_dir and not commands.active_job then
                    commands.configure()
                end
            end
        })
    end

    vim.keymap.set("n", opts.terminal.toggle, function()
        if project.root_dir then
            terminal.toggle()
        end
    end, {})

    vim.tbl_extend("force", config, opts)
end

return M
