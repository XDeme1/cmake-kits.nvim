local kits = require("cmake-kits.kits")
local project = require("cmake-kits.project")

local M = {}

--- @param on_select fun(selected: cmake-kits.Kit)?
M.select_kit = function(on_select)
    local items = {
        { id = -1, name = "Scan for kits" },
        { id = 0, name = "Unspecified (Let CMake decide)" },
    }
    for i, kit in ipairs(kits.kits) do
        table.insert(items, { id = i, name = kit.name })
    end
    vim.ui.select(items, {
        prompt = "Select a kit",
        format_item = function(item)
            return item.name
        end,
    }, function(choice)
        if choice == nil then
            return
        elseif choice.id == -1 then
            kits.scan_for_kits()
            return
        elseif choice.id == 0 then
            project.state.selected_kit = {
                name = "Unspecified",
            }
            return
        end
        project.state.selected_kit = kits.kits[choice.id]
        if type(on_select) == "function" then
            on_select(choice)
        end
    end)
end

--- @param on_select fun(selected: cmake-kits.BuildVariant)?
M.select_build_type = function(on_select)
    vim.ui.select({ "Debug", "Release", "MinSizeRel", "RelWithDebInfo" }, {
        prompt = "Select a build type",
    }, function(choice)
        if choice == nil then
            return
        end
        project.state.build_type = choice
        if type(on_select) == "function" then
            on_select(choice)
        end
    end)
end

--- @param on_select fun(selected: cmake-kits.Target)?
M.select_build_target = function(on_select)
    vim.ui.select(project.state.build_targets, {
        prompt = "Select build target",
        format_item = function(target)
            return target.name
        end,
    }, function(choice)
        if choice == nil then
            return
        end
        project.state.selected_build = choice
        if type(on_select) == "function" then
            on_select(choice)
        end
    end)
end

--- @param on_select fun(selected: cmake-kits.Target)?
M.select_runnable_target = function(on_select)
    vim.ui.select(project.state.runnable_targets, {
        prompt = "Select a target to run",
        format_item = function(target)
            return target.name
        end,
    }, function(choice)
        if choice == nil then
            return
        end
        project.state.selected_runnable = choice
        if type(on_select) == "function" then
            on_select(choice)
        end
    end)
end

return M
