local project = require("cmake-kits.project")
local commands = require("cmake-kits.commands")
local picker = require("cmake-kits.pickers")

vim.api.nvim_create_user_command("CmakeSetRootDir", function()
    local cwd = vim.uv.cwd()
    vim.ui.input({
        prompt = "Input your root dir",
        default = cwd,
        completion = "dir",
    }, function(input)
        if input == nil then
            return
        end
        project.set_root_dir(input)
    end)
end, {})

vim.api.nvim_create_user_command("CmakeSelectBuildType", function(opts)
    if not vim.tbl_isempty(opts.fargs) then
        project.build_type = opts.fargs[1]
        return
    end
    picker.select_build_type(function()
        commands.configure({})
    end)
end, {
    nargs = "*",
    complete = function()
        -- TODO: Implement Filter based on current input
        return { "Debug", "Release", "MinSizeRel", "RelWithDebInfo" }
    end,
})

vim.api.nvim_create_user_command("CmakeSelectKit", function()
    local current_kit = project.selected_kit
    picker.select_kit(function(selected)
        commands.configure({
            fresh = current_kit ~= selected,
        })
    end)
end, {})

vim.api.nvim_create_user_command("CmakeConfigure", function()
    commands.configure()
end, {})

vim.api.nvim_create_user_command("CmakeBuild", function()
    commands.build(false, {})
end, {})

vim.api.nvim_create_user_command("CmakeQuickBuild", function()
    commands.build(true, {})
end, {})

vim.api.nvim_create_user_command("CmakeRun", function()
    commands.run(false, {})
end, {})

vim.api.nvim_create_user_command("CmakeQuickRun", function()
    commands.run(true, {})
end, {})

vim.api.nvim_create_user_command("CmakeTest", function()
    commands.test()
end, {})
