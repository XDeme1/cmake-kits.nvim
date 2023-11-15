local Path = require("plenary.path")

local M = {}

M.query_dir = Path:new(".cmake") / "api" / "v1" / "query" / "client-cmake-kits"
M.reply_dir = Path:new(".cmake") / "api" / "v1" / "reply"

M.query_data = {
    requests = {
        {
            kind = "cache",
            version = 2,
        },
        {
            kind = "codemodel",
            version = 2,
        },
        {
            kind = "toolchains",
            version = 1,
        },
        {
            kind = "cmakeFiles",
            version = 1,
        },
    },
}

function M.create_query(build_dir)
    local path = Path:new(build_dir) / M.query_dir
    path:mkdir({ parents = true })
    local query_path = path / "query.json"
    local file = io.open(tostring(query_path), "w+")
    if file then
        file:write(vim.json.encode(M.query_data))
        file:close()
    end
end

function M.get_build_targets(build_dir)
    local build_targets = {}
    local reply_dir = Path:new(build_dir) / M.reply_dir
    local found = vim.fs.find(function(name, _)
        return name:match("^target")
    end, {
        limit = math.huge,
        path = tostring(reply_dir),
    })

    table.insert(build_targets, {
        name = "all",
        full_path = nil,
        type = nil,
    })
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
                table.insert(build_targets, target)
            end
            file:close()
        end
    end
    return build_targets
end

function M.get_runnable_targets(build_targets)
    return vim.iter(build_targets)
        :filter(function(target)
            return target.name ~= "all" and target.type ~= "STATIC_LIBRARY"
        end)
        :totable()
end

return M
