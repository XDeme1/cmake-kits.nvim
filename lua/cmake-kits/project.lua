local config = require("cmake-kits.config")
local job = require("plenary.job")

--- @alias cmake-kits.BuildVariant "Debug" | "Release" | "MinSizeRel" | "RelWithDebInfo"

--- @class cmake-kits.Compilers
--- @field C string?
--- @field CXX string?

--- @class cmake-kits.Kit
--- @field name string
--- @field compilers cmake-kits.Compilers
--- @field isTrusted boolean

--- @class cmake-kits.ProjectState Table holding the state of the cmake project
--- @field root_dir string? Path to the root project
--- @field build_type cmake-kits.BuildVariant
--- @field kits cmake-kits.Kit[]
--- @field selected_kit cmake-kits.Kit?
--- @field private create_kit table
local M = {}

M.root_dir = nil
M.build_type = "Debug"

M.kits = {}
M.selected_kit = nil

M.build_targets = {}
M.selected_build = nil

M.runnable_targets = {}
M.selected_runnable = nil

--- Used to substitute ${workspaceFolder} and ${buildType} with the correct string
--- @param path string
M.interpolate_string = function(path)
    path = path:gsub("${workspaceFolder}", M.root_dir or vim.uv.cwd())
    path = path:gsub("${buildType}", M.build_type)
    return path
end

M.load_kits = function()
    local vscode_path = vim.fs.normalize("$HOME") .. "/.local/share/CMakeTools/cmake-tools-kits.json"

    local file = io.open(vscode_path, "r")
    if file then
        M.kits = vim.json.decode(file:read("*a"))
        file:close()
        return
    end
end

M.save_kits = function()
    local vscode_path = vim.fs.normalize("$HOME") .. "/.local/share/CMakeTools/cmake-tools-kits.json"

    local old_file = io.open(vscode_path, "r")
    local json = nil
    if old_file then
        json = vim.json.decode(old_file:read("*a"))
        old_file:close()
    end
    vim.tbl_deep_extend("force", json, M.kits)
    local file = io.open(vscode_path, "w+")
    if file then
        file:write(vim.json.encode(json))
        file:close()
    end
    vim.print(json)
end

M.scan_for_kits = function()
    local path_array = vim.split(vim.fs.normalize("$PATH"), ":", { plain = true, trimempty = true })
    local compilers = {
        clang = {},
        clang_cl = {},
        gcc = {},
    }

    for _, path in ipairs(path_array) do
        local clang = vim.fs.find({ "clang" }, {
            type = "link",
            path = path,
        })
        local clang_cl = vim.fs.find({ "clang-cl" }, {
            type = "link",
            path = path,
        })
        local gcc = vim.fs.find(function(name, _)
            local match1 = name:match("^gcc$")
            local match2 = name:match("^gcc%-[%d]+$")
            return match1 or match2
        end, {
            limit = math.huge,
            type = "file",
            path = path,
        })

        if not vim.tbl_isempty(clang) then
            table.insert(compilers.clang, clang[1])
        end
        if not vim.tbl_isempty(clang_cl) then
            table.insert(compilers.clang_cl, clang_cl[1])
        end
        if not vim.tbl_isempty(gcc) then
            for _, value in ipairs(gcc) do
                table.insert(compilers.gcc, value)
            end
        end
    end

    for _, path in ipairs(compilers.clang) do
        table.insert(M.kits, M.create_kit.clang(path))
    end
    for _, path in ipairs(compilers.clang_cl) do
        table.insert(M.kits, M.create_kit.clang_cl(path))
    end
    for _, path in ipairs(compilers.gcc) do
        table.insert(M.kits, M.create_kit.gcc(path))
    end
end

M.create_kit = {
    --- @param path string C executable path
    clang = function(path)
        local clang_cpp_path, _ = path:gsub("clang", "clang++")
        local clang_cpp = vim.fs.find(vim.fs.basename(clang_cpp_path), {
            type = "link",
            path = vim.fs.dirname(path),
        })[1]

        --- @type cmake-kits.Kit
        local result = {
            name = "clang ",
            isTrusted = true,
            compilers = { C = path, CXX = clang_cpp }
        }

        job:new({
            command = path,
            args = { "--version" },
            --- @param data string
            on_stdout = function(err, data)
                if vim.startswith(data, "clang") then
                    result.name = result.name .. data:match("[%d]+.[%d]+.[%d]+")
                elseif vim.startswith(data, "Target") then
                    result.name = result.name .. data:sub(8)
                end
            end
        }):start()

        return result
    end,
    --- @param path string
    clang_cl = function(path)
        local result = {
            name = "clang-cl ",
            isTrusted = true,
            compilers = { C = path, CXX = path },
        }

        job:new({
            command = path,
            args = { "--version" },
            --- @param data string
            on_stdout = function(err, data)
                if vim.startswith(data, "clang") then
                    result.name = result.name .. data:match("[%d]+.[%d]+.[%d]+")
                elseif vim.startswith(data, "Target") then
                    result.name = result.name .. data:sub(8)
                end
            end
        }):start()

        return result
    end,
    --- @param path string C executable path
    gcc = function(path)
        local gxx_path, _ = path:gsub("gcc", "g++")
        local gcc_cpp = vim.fs.find(vim.fs.basename(gxx_path), {
            path = vim.fs.dirname(path),
        })[1]

        --- @type cmake-kits.Kit
        local result = {
            name = "GCC ",
            isTrusted = true,
            compilers = { C = path, CXX = gcc_cpp }
        }

        job:new({
            command = path,
            args = { "--version" },
            --- @param data string
            on_stdout = function(err, data)
                if vim.startswith(data, "gcc") then
                    result.name = result.name .. data:match("[%d]+.[%d]+.[%d]+") .. " "
                end
            end,
            on_exit = function()
                job:new({
                    command = path,
                    args = { "-dumpmachine" },
                    --- @param data string
                    on_stdout = function(err, data)
                        result.name = result.name .. data
                    end
                }):start()
            end
        }):start()

        return result
    end

}

return M
