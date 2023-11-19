local config = require("cmake-kits.config")
local project = require("cmake-kits.project")
local kits = require("cmake-kits.kits")
local commands = require("cmake-kits.commands")

kits.load_kits()

vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("CmakeSaveKits", {}),
    callback = function()
        if project.root_dir then
            kits.save_kits()
            project.save_project()
        end
    end,
})

vim.api.nvim_create_user_command("CmakeSetRootDir", function(opts)
    if not vim.tbl_isempty(opts.fargs) then
        project.change_root_dir(opts.fargs[1])
        project.load_project()
        return
    end
    local cwd = vim.uv.cwd()
    vim.ui.input({
        prompt = "Input your root dir",
        default = cwd,
        completion = "dir",
    }, function(input)
        if input == nil then
            return
        end
        project.change_root_dir(cwd)
        project.load_project()
    end)
end, { nargs = "*" })

vim.api.nvim_create_user_command("CmakeSelectBuildType", function(opts)
    if not vim.tbl_isempty(opts.fargs) then
        project.build_type = opts.fargs[1]
        return
    end
    project.select_build_type(commands.configure)
end, {
    nargs = "*",
    complete = function()
        -- TODO: Implement Filter based on current input
        return { "Debug", "Release", "MinSizeRel", "RelWithDebInfo" }
    end,
})

vim.api.nvim_create_user_command("CmakeSelectKit", function()
    kits.select_kit(commands.configure)
end, {})

vim.api.nvim_create_user_command("CmakeConfigure", function()
    commands.configure()
end, {})

vim.api.nvim_create_user_command("CmakeBuild", function()
    commands.build()
end, {})

vim.api.nvim_create_user_command("CmakeQuickBuild", function()
    commands.quick_build()
end, {})

vim.api.nvim_create_user_command("CmakeRun", function()
    commands.run()
end, {})

vim.api.nvim_create_user_command("CmakeQuickRun", function()
    commands.quick_run()
end, {})

vim.api.nvim_create_user_command("CmakeTest", function()
    commands.test()
end, {})
