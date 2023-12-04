local job = require("plenary.job")
local utils = require("cmake-kits.utils")

--- @class cmake-kits.Kit
--- @field name string
--- @field compilers cmake-kits.Compilers
--- @field isTrusted boolean

--- @class cmake-kits.UnspecifiedKit
--- @field name "Unspecified"
--- @field compilers nil
--- @field isTrusted nil

--- @class cmake-kits.KitsState
--- @field kits cmake-kits.Kit[]
local M = {}

M.kits = {}

local save_path =
    vim.fs.joinpath(vim.fs.normalize("$HOME"), ".local/share/CMakeTools/cmake-tools-kits.json")

M.load_kits = function()
    M.kits = utils.load_data(save_path)
end

M.save_kits = function()
    utils.save_data(save_path, M.kits, true)
end

M.scan_for_kits = function()
    local path_array = vim.split(vim.fs.normalize("$PATH"), ":", { plain = true, trimempty = true })
    local compilers = {
        ---@type cmake-kits.Kit[]
        clang = {},
        ---@type cmake-kits.Kit[]
        clang_cl = {},
        ---@type cmake-kits.Kit[]
        gcc = {},
    }

    --- @type cmake-kits.Kit[]
    local new_kits = {}
    for _, path in ipairs(path_array) do
        local clang = vim.fs.find({ "clang" }, {
            type = "link",
            path = path,
        })

        if not vim.tbl_isempty(clang) then
            table.insert(compilers.clang, M.create_kit.clang(clang[1]))
        end
    end

    for _, path in ipairs(path_array) do
        local clang_cl = vim.fs.find({ "clang-cl" }, {
            type = "link",
            path = path,
        })
        if not vim.tbl_isempty(clang_cl) then
            table.insert(compilers.clang_cl, M.create_kit.clang_cl(clang_cl[1]))
        end
    end

    for _, path in ipairs(path_array) do
        local gcc = vim.fs.find(function(name, _)
            local match1 = name:match("^gcc$")
            local match2 = name:match("^gcc%-[%d]+$")
            return match1 or match2
        end, {
            limit = math.huge,
            type = "file",
            path = path,
        })
        if not vim.tbl_isempty(gcc) then
            for _, value in ipairs(gcc) do
                table.insert(compilers.gcc, M.create_kit.gcc(value))
            end
        end
    end

    local timer = vim.uv.new_timer()

    if timer ~= nil then
        timer:start(0, 50, function()
            if M.create_kit.job_count == 0 then
                for compiler, _ in pairs(compilers) do
                    table.sort(compilers[compiler], function(a, b)
                        return a.name < b.name
                    end)
                end
                for _, value in ipairs(compilers.clang) do
                    table.insert(new_kits, value)
                end
                for _, value in ipairs(compilers.clang_cl) do
                    table.insert(new_kits, value)
                end
                for _, value in ipairs(compilers.gcc) do
                    table.insert(new_kits, value)
                end

                new_kits = vim.iter(new_kits)
                    :filter(function(kit)
                        for _, value in ipairs(M.kits) do
                            return vim.deep_equal(kit, value)
                        end
                        return true
                    end)
                    :totable()

                vim.list_extend(M.kits, new_kits)
                timer:close()
            end
        end)
    end
end

M.create_kit = {
    job_count = 0,
    clang = function(path)
        local cpp_path, _ = path:gsub("clang", "clang++")
        local cpp = vim.fs.find(vim.fs.basename(cpp_path), {
            path = vim.fs.dirname(path),
        })[1]

        --- @type cmake-kits.Kit
        local result = {
            name = "clang ",
            isTrusted = true,
            compilers = { C = path, CXX = cpp },
        }
        local metadata = {
            version = nil,
            target = nil,
        }
        M.create_kit.job_count = M.create_kit.job_count + 1
        job:new({
            command = path,
            args = { "--version" },
            env = { "LC_ALL=UTF-8.en_US" },
            on_stdout = function(_, data)
                if vim.startswith(data, "clang") then
                    metadata.version = data:match("[%d]+.[%d].[%d]")
                elseif vim.startswith(data, "Target") then
                    metadata.target = data:sub(8)
                end
            end,
            on_exit = function()
                result.name = result.name .. metadata.version .. metadata.target
                M.create_kit.job_count = M.create_kit.job_count - 1
            end,
        }):start()
        return result
    end,
    clang_cl = function(path)
        local result = {
            name = "clang-cl ",
            isTrusted = true,
            compilers = { C = path, CXX = path },
        }
        local metadata = {
            version = nil,
            target = nil,
        }

        M.create_kit.job_count = M.create_kit.job_count + 1
        job:new({
            command = path,
            args = { "--version" },
            env = { "LC_ALL=en_US.UTF-8" },
            on_stdout = function(_, data)
                if vim.startswith(data, "clang") then
                    metadata.version = data:match("[%d]+.[%d].[%d]")
                elseif vim.startswith(data, "Target") then
                    metadata.target = data:sub(8)
                end
            end,
            on_exit = function()
                result.name = result.name .. metadata.version .. metadata.target
                M.create_kit.job_count = M.create_kit.job_count - 1
            end,
        }):start()
        return result
    end,
    gcc = function(path)
        local cpp_path, _ = path:gsub("gcc", "g++")
        local cpp = vim.fs.find(vim.fs.basename(cpp_path), {
            path = vim.fs.dirname(path),
        })[1]

        --- @type cmake-kits.Kit
        local result = {
            name = "GCC ",
            isTrusted = true,
            compilers = { C = path, CXX = cpp },
        }
        local metadata = {
            version = "",
            target = "",
        }

        M.create_kit.job_count = M.create_kit.job_count + 1
        job:new({
            command = path,
            args = { "-v" },
            env = { "LC_ALL=UTF-8.en_US" },
            on_stderr = function(_, data)
                if vim.startswith(data, "gcc") then
                    metadata.version = data:match("[%d]+.[%d].[%d]")
                elseif vim.startswith(data, "Target") then
                    metadata.target = data:sub(8)
                end
            end,
            on_exit = function()
                result.name = result.name .. metadata.version .. metadata.target
                M.create_kit.job_count = M.create_kit.job_count - 1
            end,
        }):start()
        return result
    end,
}
return M
