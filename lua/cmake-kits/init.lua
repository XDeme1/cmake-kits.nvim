local project = require("cmake-kits.project")
local config = require("cmake-kits.config")
local commands = require("cmake-kits.commands")
local utils = require("cmake-kits.utils")

--- @class cmake-kits.SetupConfig : cmake-kits.CmakeConfig
--- @field configure_on_open boolean
--- @field configure_on_save boolean

local M = {}

--- @type cmake-kits.SetupConfig
local default = {
    configure_on_open = true,
    configure_on_save = true,
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
    if opts.configure_on_open then
        vim.api.nvim_create_autocmd("LspAttach", {
            group = vim.api.nvim_create_augroup("CmakeConfigOnOpen", {}),
            pattern = { "CMakeLists.txt" },
            callback = function(ev)
                local root_dir = utils.get_cmake_root(vim.fs.dirname(ev.file))
                if root_dir ~= project.root_dir then
                    project.root_dir = root_dir
                    if opts.configure_on_open then
                        commands.configure()
                    end
                end
            end
        })
    end

    for key, value in pairs(default) do
        opts[key] = nil
    end
    vim.tbl_extend("force", config, opts)
end

return M
