local project = require("cmake-kits.project")
local config = require("cmake-kits.config")
local plenay_job = require("plenary.job")
local kits = require("cmake-kits.kits")
local utils = require("cmake-kits.utils")

local M = {}

M.active_job = nil

M.configure = function(callback)
    if project.root_dir == nil then
        vim.notify("You must be in a cmake project", vim.log.levels.ERROR, nil)
        return
    end
    if M.active_job then
        vim.notify("You must wait for a command to finish before you use this command", vim.log.levels.ERROR, nil)
        return
    end

    local build_dir = vim.fs.joinpath(project.root_dir, project.interpolate_string(config.build_directory))
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

    M.active_job = true
    plenay_job:new({
        command = config.command,
        args = args,
        on_exit = function()
            M.active_job = false
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
            M.update_build_targets(function()
                M.update_runnable_targets(callback)
            end)
        end
    }):start()
end

M.build = function(callback)
    if M.active_job then
        vim.notify("You must wait for a command to finish before you use this command", vim.log.levels.ERROR, nil)
        return
    end

    local build_dir = project.interpolate_string(config.build_directory)
    if vim.fn.isdirectory(build_dir) == 0 or vim.tbl_isempty(project.build_targets) then
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
        M.active_job = true
        project.selected_build = choice
        plenay_job:new({
            command = config.command,
            args = { "--build", build_dir, "--config", project.build_type, "--target", choice.name },
            on_exit = function()
                M.active_job = false
                if type(callback) == "function" then
                    callback()
                end
            end
        }):start()
    end)
end

M.run = function(callback)
    if M.active_job then
        vim.notify("You must wait for a command to finish before you use this command", vim.log.levels.ERROR, nil)
        return
    end

    local build_dir = project.interpolate_string(config.build_directory)
    if vim.fn.isdirectory(build_dir) == 0 or vim.tbl_isempty(project.runnable_targets) then
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

        local terminal, args = utils.get_external_terminal()
        project.selected_runnable = choice
        plenay_job:new({
            command = terminal,
            args = { unpack(args), "bash", "-c", project.selected_runnable.full_path ..
            " && " .. "read -n 1 -r -p \"\nPress any key to continue...\"" },
            on_exit = function()
                if type(callback) == "function" then
                    callback()
                end
            end
        }):start()
    end)
end

M.update_build_targets = function(callback)
    if M.active_job then
        vim.notify("You must wait for a command to finish before you use this command", vim.log.levels.ERROR, nil)
        return
    end

    local build_dir = project.interpolate_string(config.build_directory)
    local libs = {}
    project.build_targets = {}
    M.active_job = true
    plenay_job:new({
        command = config.command,
        args = { "--build", build_dir, "--config", project.build_type, "--target", "help" },
        on_stdout = function(_, data)
            local name = data:sub(0, #data - 7)
            if vim.endswith(name, ".a") then
                table.insert(libs, name:sub(4, #name - 2))
            end
        end,
        on_exit = function()
            local file = io.open(vim.fs.joinpath(project.root_dir, build_dir, "CMakeFiles", "TargetDirectories.txt"), "r")
            if file then
                local full_path = file:read("*l")
                while full_path do
                    full_path = full_path:sub(1, #full_path - 4)

                    local basename = vim.fs.basename(full_path)
                    if vim.startswith(basename, "Experimental") or
                        vim.startswith(basename, "Nightly") or
                        vim.startswith(basename, "Continuous") or
                        vim.startswith(basename, "edit_cache") or
                        vim.startswith(basename, "rebuild_cache") or
                        vim.endswith(basename, "test") then
                    else
                        local target_dir = vim.fs.dirname(vim.fs.dirname(full_path))
                        local target = {
                            name = basename,
                            full_path = vim.fs.joinpath(target_dir, basename),
                        }
                        if vim.list_contains(libs, basename) then
                            target = vim.tbl_extend("force", target, { type = "Static Library" })
                        else
                            target = vim.tbl_extend("force", target, { type = "Executable" })
                        end
                        table.insert(project.build_targets, target)
                    end
                    full_path = file:read("*l")
                end
                file:close()
            end
            table.insert(project.build_targets, {
                name = "all",
                full_path = nil,
                type = nil
            })
            M.active_job = false
            if type(callback) == "function" then
                callback()
            end
        end
    }):start()
end

M.update_runnable_targets = function(callback)
    if M.active_job then
        error("You must wait for a command to finish before you use this command")
        return
    end

    --- @param target cmake-kits.Target
    project.runnable_targets = vim.iter(project.build_targets):filter(function(target)
        return target.name ~= "all" and target.type ~= "Static Library"
    end):totable()

    if type(callback) == "function" then
        callback()
    end
end

return M
