local project = require("cmake-kits.project")
local config = require("cmake-kits.config")
local plenay_job = require("plenary.job")
local kits = require("cmake-kits.kits")
local utils = require("cmake-kits.utils")
local cmake_file_api = require("cmake-kits.cmake_file_api")
local Path = require("plenary.path")
local notify = require("cmake-kits.notify")
local terminal = require("cmake-kits.terminal")

local M = {}

M.active_job = nil

M.configure = function(callback)
    if project.root_dir == nil then
        notify.configuration("You must be in a cmake project", vim.log.levels.ERROR)
        return
    end
    if M.active_job then
        notify.active_job("Configuration error")
        return
    end

    local build_dir = project.interpolate_string(config.build_directory)
    cmake_file_api.create_query(build_dir)

    local args = {
        "-S",
        project.root_dir,
        "-B",
        build_dir,
        "-G",
        config.generator,
        "-DCMAKE_BUILD_TYPE=" .. project.build_type,
    }
    if kits.selected_kit ~= "Unspecified" then
        table.insert(args, "-DCMAKE_C_COMPILER=" .. kits.selected_kit.compilers.C) -- C compiler is guaranteed to exist
        if kits.selected_kit.compilers.CXX then
            table.insert(args, "-DCMAKE_CXX_COMPILER=" .. kits.selected_kit.compilers.CXX)
        end
    end

    for _, arg in ipairs(config.configure_args) do
        table.insert(args, arg)
    end

    terminal.clear()
    M.active_job = true
    plenay_job:new({
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
            M.active_job = false
            if code ~= 0 then
                notify.configuration("Configuration failure", vim.log.levels.ERROR)
                return
            end

            notify.configuration("Configuration done", vim.log.levels.INFO)
            if config.compile_commands_path then
                local build_file = io.open(vim.fs.joinpath(build_dir, "compile_commands.json"), "r")
                if build_file then
                    local out_dir = project.interpolate_string(config.compile_commands_path)
                    local out_file = io.open(vim.fs.joinpath(out_dir, "compile_commands.json"), "w+")
                    if out_file then
                        out_file:write(build_file:read("*a"))
                        out_file:close()
                    end
                    build_file:close()
                end
            end
            M.update_build_targets()
            M.update_runnable_targets()
            if type(callback) == "function" then
                callback()
            end
        end
    }):start()
end

M.build = function(callback)
    if M.active_job then
        notify.active_job("Build error")
        return
    end

    local build_dir = project.interpolate_string(config.build_directory)
    if vim.fn.isdirectory(build_dir) == 0 then
        return M.configure(M.build)
    end

    vim.ui.select(project.build_targets, {
        prompt = "Select build target",
        format_item = function(target)
            return target.name
        end,
    }, function(choice)
        if choice == nil then
            return
        end
        project.selected_build = choice
        M.create_build_job(build_dir, callback, choice)
    end)
end

function M.quick_build(callback)
    if M.active_job then
        notify.active_job("Build error")
        return
    end
    if project.selected_build == nil then
        notify.build("You must select a build target before running CmakeQuickBuild", vim.log.levels.ERROR)
        return
    end

    local build_dir = project.interpolate_string(config.build_directory)
    if vim.fn.isdirectory(build_dir) == 0 or vim.tbl_isempty(project.build_targets) then
        return M.configure(function() M.quick_build(callback) end)
    end
    M.create_build_job(build_dir, callback, project.selected_build)
end

M.run = function(callback)
    if M.active_job then
        notify.active_job("Run error")
        return
    end

    local build_dir = project.interpolate_string(config.build_directory)
    if vim.fn.isdirectory(build_dir) == 0 then
        return M.configure(M.run)
    end

    vim.ui.select(project.runnable_targets, {
        prompt = "Select a target to run",
        format_item = function(target)
            return target.name
        end
    }, function(choice)
        if choice == nil then
            return
        end
        project.selected_runnable = choice
        M.create_run_job(callback)
    end)
end

function M.quick_run(callback)
    if M.active_job then
        notify.active_job("Run error")
        return
    end
    if project.selected_runnable == nil then
        notify.run("You must select a runnable target before running CmakeQuickRun", vim.log.levels.ERROR)
        return
    end

    local build_dir = project.interpolate_string(config.build_directory)
    if vim.fn.isdirectory(build_dir) == 0 or vim.tbl_isempty(project.runnable_targets) then
        return M.configure(function() M.quick_run(callback) end)
    end

    M.create_run_job(callback)
end

--- @param target cmake-kits.Target
function M.create_build_job(build_dir, callback, target)
    if target == nil then
        target = {
            name = "all",
        }
    end
    M.active_job = true
    plenay_job:new({
        command = config.command,
        args = { "--build", build_dir, "--config", project.build_type, "--target", target.name },
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
            M.active_job = false
            if code ~= 0 then
                notify.build("Build failure", vim.log.levels.ERROR)
                return
            end

            notify.build("Build done", vim.log.levels.INFO)
            if type(callback) == "function" then
                callback()
            end
        end
    }):start()
end

function M.create_run_job(callback)
    if not Path:new(project.selected_runnable.full_path):exists() then
        local build_dir = project.interpolate_string(config.build_directory)
        return M.create_build_job(build_dir, function()
            M.create_run_job(callback)
        end, project.selected_runnable)
    end

    M.active_job = true
    local ext_terminal, args = utils.get_external_terminal()
    plenay_job:new({
        command = ext_terminal,
        args = { unpack(args), "bash", "-c", project.selected_runnable.full_path ..
        " && " .. "read -n 1 -r -p \"\nPress any key to continue...\"" },
        on_exit = function(_, code)
            M.active_job = false
            if code ~= 0 then
                notify.run("Run failure", vim.log.levels.ERROR)
                return
            end

            notify.run("Run done", vim.log.levels.INFO)
            if type(callback) == "function" then
                callback()
            end
        end
    }):start()
end

function M.update_build_targets()
    project.build_targets = {}
    local build_dir = project.interpolate_string(config.build_directory)
    local reply_dir = Path:new(build_dir) / ".cmake" / "api" / "v1" / "reply"
    local found = vim.fs.find(function(name, _)
        return name:match("^target")
    end, {
        limit = math.huge,
        path = tostring(reply_dir)
    })

    local target_all = {
        name = "all",
        full_path = nil,
        type = nil,
    }
    table.insert(project.build_targets, target_all)
    for _, path in ipairs(found) do
        local file = io.open(path, "r")
        if file then
            local data = vim.json.decode(file:read("*a"))
            --- @type cmake-kits.Target
            if data.artifacts then
                local target = {
                    name = data.name,
                    full_path = vim.fs.joinpath(build_dir, data.artifacts[1].path),
                    type = data.type,
                }
                table.insert(project.build_targets, target)
            end
            file:close()
        end
    end
end

M.update_runnable_targets = function()
    --- @param target cmake-kits.Target
    project.runnable_targets = vim.iter(project.build_targets):filter(function(target)
        return target.name ~= "all" and target.type ~= "STATIC_LIBRARY"
    end):totable()
end

return M
