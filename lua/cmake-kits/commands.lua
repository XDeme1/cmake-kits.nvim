local project = require("cmake-kits.project")
local config = require("cmake-kits.config")
local plenay_job = require("plenary.job")
local utils = require("cmake-kits.utils")
local cmake_file_api = require("cmake-kits.cmake_file_api")
local Path = require("plenary.path")
local terminal = require("cmake-kits.terminal")

local M = {}

M.active_job = nil

M.interupt_job = function()
    if M.active_job then
        M.active_job:shutdown()
    end
end

--- @class cmake-kits.Configure
--- @field fresh boolean?
--- @field on_exit fun()
--- @param opts cmake-kits.Configure
M.configure = function(opts)
    if M.active_job then
        utils.notify(
            "Configuration error",
            "You must wait for another command to finish to use this command"
        )
        return
    end
    opts = opts or {}

    terminal.clear()

    local build_dir = project.interpolate_string(config.build_directory)
    cmake_file_api.create_query(build_dir)

    local args = {}
    if opts.fresh then
        table.insert(args, "--fresh")
    end

    table.insert(args, "-S" .. project.root_dir)
    table.insert(args, "-B" .. build_dir)
    table.insert(args, "-G" .. config.generator)
    table.insert(args, "-DCMAKE_BUILD_TYPE=" .. project.build_type)
    if project.selected_kit ~= "Unspecified" then
        table.insert(args, "-DCMAKE_C_COMPILER=" .. project.selected_kit.compilers.C)
        if project.selected_kit.compilers.CXX then
            table.insert(args, "-DCMAKE_CXX_COMPILER=" .. project.selected_kit.compilers.CXX)
        end
    end
    vim.list_extend(args, config.configure_args)
    M.active_job = plenay_job:new({
        command = config.command,
        args = args,
        on_stdout = function(_, data)
            vim.schedule(function()
                terminal.send_data("[configure] " .. data)
            end)
        end,
        on_stderr = function(_, data)
            vim.schedule(function()
                terminal.send_data("[configure] " .. data)
            end)
        end,
        on_exit = function(_, code)
            M.active_job = nil
            if code ~= 0 then
                utils.notify("Configuration", "Failure")
                return
            end

            utils.notify("Configuration", "Sucessful", vim.log.levels.INFO)

            project.build_targets = cmake_file_api.get_build_targets(build_dir)
            project.runnable_targets = cmake_file_api.get_runnable_targets(project.build_targets)

            if config.compile_commands_path then
                local source = Path:new(build_dir) / "compile_commands.json"
                local destination =
                    Path:new(project.interpolate_string(config.compile_commands_path))
                if destination:is_dir() then
                    destination = destination / "compile_commands.json"
                end
                source:copy({
                    destination = destination,
                })
            end

            if type(opts.on_exit) == "function" then
                vim.schedule(function()
                    opts.on_exit()
                end)
            end
        end,
    })
    M.active_job:start()
end

M.build = function(callback)
    if M.active_job then
        utils.notify(
            "Build error",
            "You must wait for another command to finish to use this command"
        )
        return
    end

    local build_dir = project.interpolate_string(config.build_directory)
    if vim.loop.fs_stat(build_dir).type ~= "directory" then
        return M.configure(function()
            M.build(callback)
        end)
    end

    project.select_build_target(function(selected)
        M.create_build_job(build_dir, callback, selected)
    end)
end

function M.quick_build(callback)
    if M.active_job then
        utils.notify(
            "Build error",
            "You must wait for another command to finish to use this command"
        )
        return
    end
    if project.selected_build == nil then
        utils.notify("Build error", "You must select a build target before running CmakeQuickBuild")
        return
    end

    local build_dir = project.interpolate_string(config.build_directory)
    if vim.loop.fs_stat(build_dir).type ~= "directory" then
        return M.configure(function()
            M.quick_build(callback)
        end)
    end
    M.create_build_job(build_dir, callback, project.selected_build)
end

M.run = function(callback)
    if M.active_job then
        utils.notify("Run error", "You must wait for another command to finish to use this command")
        return
    end

    local build_dir = project.interpolate_string(config.build_directory)

    if vim.loop.fs_stat(build_dir).type ~= "directory" then
        return M.configure(function()
            M.run(callback)
        end)
    end

    project.select_runnable_target(function(selected)
        M.create_build_job(build_dir, function()
            M.create_run_job(callback)
        end, selected)
    end)
end

function M.quick_run(callback)
    if M.active_job then
        utils.notify("Run error", "You must wait for another command to finish to use this command")
        return
    end
    if project.selected_runnable == nil then
        utils.notify(
            "Run error",
            "You must select a runnable target before running CmakeQuickRun",
            vim.log.levels.ERROR
        )
        return
    end

    local build_dir = project.interpolate_string(config.build_directory)
    if vim.loop.fs_stat(build_dir).type ~= "directory" then
        return M.configure(function()
            M.quick_run(callback)
        end)
    end

    M.create_build_job(build_dir, function()
        M.create_run_job(callback)
    end, project.selected_runnable)
end

function M.test(callback)
    if M.active_job then
        utils.notify(
            "Test error",
            "You must wait for another command to finish to use this command"
        )
        return
    end

    local build_dir = project.interpolate_string(config.build_directory)
    if vim.loop.fs_stat(build_dir).type ~= "directory" then
        return M.configure(function()
            M.test(callback)
        end)
    end

    M.create_build_job(build_dir, function()
        M.create_test_job(build_dir, callback)
    end)
end

--- @param target cmake-kits.Target | nil
function M.create_build_job(build_dir, callback, target)
    local target_name = nil
    if target then
        target_name = target.name
    else
        target_name = "all"
    end

    M.active_job = plenay_job:new({
        command = config.command,
        args = { "--build", build_dir, "--config", project.build_type, "--target", target_name },
        on_stdout = function(_, data)
            vim.schedule(function()
                terminal.send_data("[build] " .. data)
            end)
        end,
        on_stderr = function(_, data)
            vim.schedule(function()
                terminal.send_data("[build] " .. data)
            end)
        end,
        on_exit = function(_, code)
            M.active_job = nil
            if code ~= 0 then
                utils.notify("Build", "Build error")
                return
            end

            utils.notify("Build", "Sucessful", vim.log.levels.INFO)
            if type(callback) == "function" then
                callback()
            end
        end,
    })
    M.active_job:start()
end

function M.create_run_job(callback)
    local ext_terminal, args = utils.get_external_terminal()
    M.active_job = plenay_job:new({
        command = ext_terminal,
        args = {
            unpack(args),
            "bash",
            "-c",
            project.selected_runnable.full_path
                .. ";"
                .. 'read -n 1 -r -p "\nPress any key to continue..."',
        },
        on_start = function()
            --- The on_exit is only called when the console exits.
            --- This enables the user to run more than one target.
            M.active_job = nil
        end,
        on_exit = function(_, code)
            if code ~= 0 then
                utils.notify("Run", "Exited with code " .. tostring(code))
                return
            end

            if type(callback) == "function" then
                callback()
            end
        end,
    })
    M.active_job:start()
end

function M.create_test_job(build_dir, callback)
    M.active_job = plenay_job:new({
        command = config.command,
        args = {
            "--build",
            build_dir,
            "--config",
            project.build_type,
            "--target",
            "test",
        },
        on_stdout = function(_, data)
            vim.schedule(function()
                terminal.send_data(data)
            end)
        end,
        on_stderr = function(_, data)
            vim.schedule(function()
                terminal.send_data(data)
            end)
        end,
        on_exit = function(_, code)
            M.active_job = nil
            if code ~= 0 then
                utils.notify("Test", "Some tests failed")
                return
            end

            utils.notify("Test", "All tests passed", vim.log.levels.INFO)
            if type(callback) == "function" then
                callback()
            end
        end,
    })
    M.active_job:start()
end

return M
