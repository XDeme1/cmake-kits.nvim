local job = require("plenary.job")

--- @class cmake-kits.Kit
--- @field name string
--- @field compilers cmake-kits.Compilers
--- @field isTrusted boolean

--- @class cmake-kits.KitsState
--- @field kits cmake-kits.Kit[]
--- @field selected_kit cmake-kits.Kit|string
local M = {}

M.kits = {}
M.selected_kit = "Unspecified"

M.select_kit = function()
	local items = {
		{ id = -1, name = "Scan for kits" },
		{ id = 0, name = "Unspecified (Let CMake decide)" },
	}
	for i, kit in ipairs(M.kits) do
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
			M.scan_for_kits()
			return
		elseif choice.id == 0 then
			M.selected_kit = "Unspecified"
			return
		end
		M.selected_kit = M.kits[choice.id]
	end)
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
	local json = {}
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
				for compiler, kits in pairs(compilers) do
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
