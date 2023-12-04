local M = {}

M.watch = function(path, opts)
    opts = opts or {}
    local handle = vim.uv.new_fs_event()
    handle:start(path, opts.flags or {}, function(err, filename, events)
        if err then
            handle:stop()
        else
            if type(opts.callback) == "function" then
                opts.callback(filename, events)
            end
        end
    end)
    return handle
end

--- @param handle uv.uv_fs_event_t
M.stop_watch = function(handle)
    handle:stop()
end
return M
